// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "hardhat/console.sol";

event Investment(uint256 tokenId,uint256 amount, address manager, address reciever);
event TokenUnlocked(uint256 id, address manager);

abstract contract NftInvestAbstract is ERC721, ERC721Enumerable, ERC721Pausable, AccessControl {
    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    uint256 private _nextTokenId;
    address public tokenA;
    address public tokenB;
    address public uniswapV2Router02;
    mapping (uint256 => InvestInfo) public investments;
    uint48 apy;
    uint256 constant SCALE = 31_536_000_000; // seconds in year * 1000

    uint256 totalInvestmentA; //How much it was invested total
    uint256 totalPaidA; // How much it was paid in total
    uint256 totalBalanceA; // Balance of token A in smart contract wallet
    uint256 totalDeficiteA; // Deficite of token A in this contract
    uint256 totalProfitA; // How much it was made in total

    // uint48 lastTotalUpdate; // last update to estimate debth

    struct InvestInfo {
        uint256 investmentA; // Initial inventment amount

        uint256 amountA;
        uint256 amountB;
        
        uint48 start;
        bool unlock;
        bool is_apy;
    }

    constructor(address defaultAdmin, address _tokenA, address _tokenB, uint48 _apy, address _V2router)
        ERC721("NftInvest", "NI")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        // _grantRole(MINTER_ROLE, minter);
        tokenA = _tokenA;
        tokenB = _tokenB;
        apy = _apy;
        uniswapV2Router02 = _V2router;
        IERC20(_tokenA).approve(_V2router, type(uint256).max);
        IERC20(_tokenB).approve(_V2router, type(uint256).max);
    }

    

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to, uint256 amount, bool _is_apy ) public onlyRole(MANAGER_ROLE) returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        investments[tokenId] = InvestInfo({
            investmentA: amount,
            amountA: amount,
            amountB: 0,
            start: clock(),
            unlock: false,
            is_apy: _is_apy
        });
        totalBalanceA += amount;
        totalInvestmentA += amount;
        // lastTotalUpdate = clock();
        IERC20(tokenA).safeTransferFrom (_msgSender(),address(this) , amount);
        emit Investment(tokenId, amount, _msgSender(), to);
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function clock() public view  returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function unlock(uint256 tokenId) onlyRole(MANAGER_ROLE) external {
        require(_requireOwned(tokenId)!= address(0), "NFT not exists");
        // fix rewards
        investments[tokenId].unlock = true;
        emit TokenUnlocked(tokenId, _msgSender());
    } 



    function _openTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) internal returns(uint[] memory amounts) {
                address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            investments[tokenId].amountA,
            amountOutMin,
            path,
            address(this),
            deadline
        );
        investments[tokenId].amountA -= amounts[0];
        investments[tokenId].amountB += amounts[1];
        totalBalanceA -= amounts[0];
        return amounts;
    }


    function _closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) internal returns(uint[] memory amounts) {
        InvestInfo storage investment = investments[tokenId];
        uint256 amount =  investment.amountB;
        address[] memory path = new address[](2);
        path[0] = tokenB;
        path[1] = tokenA;
        amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 tax = _fee(investment.investmentA, investment.start);
        (uint256 total, uint256 _deficite) = _profit(amounts[1], investment.investmentA, tax);
        console.log("Close trade, total, deficite:", total , _deficite );
        if (_deficite > 0) {
            totalDeficiteA += _deficite;
        } else {
             totalProfitA += amounts[1] - total;
        }
        investment.amountB -= amounts[0];
        investment.amountA += total;
        totalBalanceA += amounts[1];
    }


    // function _closeTrade1(uint256 tokenId, uint256 amountInMax, uint deadline) internal returns(uint[] memory amounts) {
    //     InvestInfo storage investment = investments[tokenId];
    //     uint256 amount =  investment.amountB;
    //     address[] memory path = new address[](2);
    //     path[0] = tokenB;
    //     path[1] = tokenA;
    //     amounts = IUniswapV2Router02(uniswapV2Router02).swapTokensForExactTokens(
    //         amount,
    //         amountInMax,
    //         path,
    //         address(this),
    //         deadline
    //     );

    //     uint256 tax = _fee(investment.investmentA, investment.start);
    //     (uint256 total, uint256 _deficite) = _profit(amounts[1], investment.investmentA, tax);
    //     console.log("Close trade, total, deficite:", total , _deficite );
    //     if (_deficite > 0) {
    //         totalDeficiteA += _deficite;
    //     } else {
    //          totalProfitA += amounts[1] - total;
    //     }
    //     investment.amountB -= amounts[0];
    //     investment.amountA += total;
    //     totalBalanceA += amounts[1];

    // }



  function burn(
    uint256 tokenId,
    address to
  ) external returns (uint256) {
     _update(address(0), tokenId, _msgSender()); // It checks authentication
    InvestInfo storage investment = investments[tokenId];
    require(investment.unlock, "Investment locked");
    IERC20(tokenA).safeTransfer(to, investment.amountA);
    return investment.amountA;
  }

    function _profit(uint256 amount, uint256 investAmount, uint256 tax) internal pure returns(uint256 total, uint256 deficite) {
        // Investment storage investment = investments[nftId];
        uint256 minimumPayment = investAmount + tax;
        if (amount <= minimumPayment) {
            return(minimumPayment, minimumPayment - amount);
        }
        uint256 to_pay = (investAmount - amount) * 200/1000 + investAmount;
        if (to_pay < minimumPayment) {
            total = minimumPayment;
        } else {
            total = to_pay;
        }
        return (total, 0);
    }

    function _fee(uint256 amount, uint48 start) internal view returns (uint256){
        
        uint256 time_range = clock() - start;
        return (( amount * time_range * apy) / SCALE);
        // return  (clock() - investments[tokenId].start);
    }

    function fee(uint256 tokenId) public view returns (uint256) {
        require(investments[tokenId].start < clock(), "NftInvest: Too early");
        return _fee(investments[tokenId].amountA, investments[tokenId].start);
    }

}

// ToDo:
//  check _profit function
//  optimize variables
//  check overflow 