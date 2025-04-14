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


struct Investment {
    uint48 start;
    uint256 investmentA; // Initial inventment amount
    uint256 amountB; // Balance of token B
}


// Contract, which allows to track investments.
// Each investment represented as NFT
contract Investor is ERC721, ERC721Enumerable, ERC721Pausable, AccessControl{

    event Invest(uint256 tokenId,uint256 amount, address manager, address reciever);

    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 constant SCALE = 10000;
    uint256 constant PROFIT_MAX = 8000;
    uint256 constant PROFIT_PER_DAY = 5;

    uint256 private _nextTokenId;
    address public tokenA;
    address public tokenB;
    address public uniswapV2Router02;

    mapping (uint256 => Investment) public investments;

    uint256 totalInvestmentA; //How much it was invested total
    uint256 totalPaidA; // How much it was paid in total
    uint256 totalProfitA; // How much it was made in total
    uint256 totalBalanceB;

    constructor(address defaultAdmin, address _tokenA, address _tokenB, address _V2router)
        ERC721("NftInvest", "NI")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        tokenA = _tokenA;
        tokenB = _tokenB;
        uniswapV2Router02 = _V2router;
        IERC20(_tokenA).approve(_V2router, type(uint256).max);
        IERC20(_tokenB).approve(_V2router, type(uint256).max);
    }

    // Internal functions

    function _mint(address to) internal returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function _initalInvestment(uint256 tokenId, uint256 amountA, uint256 amountB) internal {
        investments[tokenId] = Investment({
            investmentA: amountA,
            amountB: amountB,
            start: clock()
        });
        totalInvestmentA += amountA;
    }

    // returns: amountA, amountB, total payed A 
    function _closeTrade(uint256 tokenId, address to, uint256 amountOutMin, uint deadline) internal returns(uint256,uint256,uint256) {
        Investment storage investment = investments[tokenId];
        uint256 amount = investment.amountB;
        address[] memory path = new address[](2);
        path[0] = tokenB;
        path[1] = tokenA;
        uint256[] memory amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            to,
            deadline
        );

        uint256 total = _profit(amounts[1], investment.investmentA, investment.start);
        console.log("Close trade, total, investmentA:", total , investment.investmentA );
        if (investment.investmentA>total) {
            console.log("Close trade, deficite:", total ,  investment.investmentA-total);
            IERC20(tokenA).safeTransfer(to, investment.investmentA-total);
            total = investment.investmentA;
        } else {
             totalProfitA += amounts[1] - total;
        }
        investment.amountB -= amounts[0];
        return (amounts[1], amounts[0], total);
    }



    function _openTrade(uint256 tokenId, uint256 amount, uint256 amountOutMin, uint deadline) internal returns(uint[] memory amounts) {
                address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );
        investments[tokenId].amountB += amounts[1];
        return amounts;
    }

    function _profit(uint256 amount, uint256 investedAmount, uint48 start) internal view returns(uint256 total) {
        // Investment storage investment = investments[nftId];
        if (amount <= investedAmount) {
            return(investedAmount);
        }
        uint48 d = _days(start);
        uint256 profit = amount - investedAmount;
        // 80%/0.05% = 1600
        if (d <= 1600) {
            return(profit * d * PROFIT_PER_DAY/SCALE);
        }
        return(profit * PROFIT_MAX/SCALE);

    }

    // return full days from some start point
    // start - start time in seconds
    function _days(uint48 start) internal view returns(uint48) {
        require(clock() >= start, "invalid time range");
        return( (clock() - start) / 1 days);
    }

    // service functions
    function clock() public view  returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}