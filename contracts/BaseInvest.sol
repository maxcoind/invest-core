// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.29;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// import {console} from "hardhat/console.sol";

struct TradePosition {
    
    uint256 max_profit; // 1%=100, when SCALE=10000
    uint256 profit_per_day; // 0.05% = 5, when SCALE=10000

    uint256 investedA; // Initial investment amount
    uint256 amountB; // Balance of token B
    uint256 inr; // INR invested
    uint48 start; // Start time

    uint48 end; // End time
    uint256 soldB; // How much it was sold in token B
    uint256 paidA; // How much it was paid in token A
    uint256 paidInr; // How much it was paid in inr

}

contract BaseInvest is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event OpenTradePosition(uint256 tokenId,address to, uint256 amountA, uint256 amountB, uint256 inr);
    event CloseTradePosition(uint256 tokenId, address to, uint256 amountA, uint256 amountB, uint256 total, uint256 inrRate);
    event DevFee(uint256 fee);
    event ProfitRate(uint256 maximumProfit, uint256 profitPerDay);
    event PositionProfitRate(uint256 tokenId, uint256 maximumProfit, uint256 profitPerDay);
    event WithdrawProfit(address to, uint256 amount);
    event Accountant(address accountant);
    event InrRate(uint256 newRate);

    address public immutable tokenA;
    address public immutable tokenB;
    address public immutable uniswapV2Router02;

    uint256 constant SCALE = 10000;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ACCOUNTER_ROLE = keccak256("ACCOUNTER_ROLE");
    bytes32 public constant EXCHANGER_ROLE = keccak256("EXCHANGER_ROLE");



    /// @custom:storage-location erc7201:storage.BaseInvest
    struct BaseInvestStorage {
        mapping(uint256 tokenId => TradePosition) investments;
        address accountant;
        uint256 developerFee;
        uint256 developerBalance;
        uint256 defaultMaximumProfit;
        uint256 defaultProfitPerDay;
        uint256 inrRate; // rate = SCALE * INR / TokenA

        // Counters
        uint256 totalInvestmentA; //How much it was invested total
        uint256 totalPaidA; // How much it was paid in total
        uint256 systemProfitA; // How much it was made in total
        uint256 systemDeficiteA;
        uint256 totalBalanceB;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.BaseInvest")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseInvestStorageLocation = 0xb1c8af8b835f7a33bffa8d1e2059dbf8f76fdd94f5606eda9d4109564e530500;

    function _getBaseInvestStorage() private pure returns (BaseInvestStorage storage $) {
        assembly {
            $.slot := BaseInvestStorageLocation
        }
    }


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tokenA, address _tokenB, address _V2router) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        uniswapV2Router02 = _V2router;
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __ERC721_init("Invest", "INV");
        __ERC721Enumerable_init();
        __ERC721Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __BaseInvest_init(defaultAdmin);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
    }

    function __BaseInvest_init(address _accountant) internal onlyInitializing {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        $.accountant = _accountant;
        $.developerFee = 5;

        $.defaultMaximumProfit = 8000; // 0.8% = 8000, when SCALE=10000
        $.defaultProfitPerDay = 5; // 0.5% = 5, when SCALE=10000
        emit ProfitRate($.defaultMaximumProfit, $.defaultProfitPerDay);

        $.inrRate = 850_000;
        emit InrRate($.inrRate);

        IERC20(tokenA).approve(uniswapV2Router02, type(uint256).max);
        IERC20(tokenB).approve(uniswapV2Router02, type(uint256).max);
    }

    function __BaseInvest_init_unchained() internal onlyInitializing {
    }

    // getters
    function getPosition(uint256 tokenId) public view returns (TradePosition memory) {
        _requireOwned(tokenId);
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        return $.investments[tokenId];
    }

    function getSystemStats() public view returns (uint256 totalInvestmentA, uint256 totalPaidA, uint256 systemProfitA, uint256 systemDeficiteA, uint256 totalBalanceB) {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        return ($.totalInvestmentA, $.totalPaidA, $.systemProfitA, $.systemDeficiteA, $.totalBalanceB);
    }

    // setters

    function setAccountant(address _accountant) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        require(_accountant != address(0), "Invalid accountant address");
        $.accountant = _accountant;
        emit Accountant(_accountant);
    }


    function setInrRate(uint256 rate) public onlyRole(ACCOUNTER_ROLE) {
        // require(rate > 0 && rate < 1e18, "Invalid INR rate");
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        $.inrRate = rate;
        emit InrRate(rate);
    }

    function updateDefaultProfitRate(uint256 _maxProfit, uint256 _profitPerDay) public onlyRole(MANAGER_ROLE) {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        $.defaultMaximumProfit = _maxProfit;
        $.defaultProfitPerDay = _profitPerDay;
        emit ProfitRate(_maxProfit, _profitPerDay);

    }

    function updateDevFee( uint256 _developerFee) public onlyRole(DEFAULT_ADMIN_ROLE){
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        $.developerFee = _developerFee;
        emit DevFee(_developerFee);
    }

    function updatePositionProfitRate(uint256 tokenId, uint256 maximumProfit, uint256 profitPerDay) public onlyRole(ACCOUNTER_ROLE) {
        _requireOwned(tokenId);
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        $.investments[tokenId].profit_per_day = profitPerDay;
        $.investments[tokenId].max_profit = maximumProfit;
        emit PositionProfitRate(tokenId, maximumProfit, profitPerDay);
    }


    // business logic
    function withdrawTokenB(address to, uint256 amount) public onlyRole(ACCOUNTER_ROLE) {
        uint256 balance = IERC20(tokenB).balanceOf(address(this));
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        require(amount <= (balance - $.developerBalance), "Not enough balance"); 
        IERC20(tokenB).safeTransfer(to, amount);
        emit WithdrawProfit(to, amount);
    }


    function openTrade(uint256 tokenId, address[] memory path,  address to, uint256 inr, uint256 amountBOutMin, uint deadline) 
            onlyRole(TRADER_ROLE) nonReentrant external returns (uint256 amountA, uint256 amountB) {
        require(_ownerOf(tokenId) == address(0), "token already minted");
        require(path[0] == tokenA, "Invalid path start");
        require(path[path.length - 1] == tokenB, "Invalid path end");
        uint256 amount = inr2tokenA(inr);
        _safeMint(to, tokenId);
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        IERC20(tokenA).safeTransferFrom(_msgSender(),address(this),amount);
        uint256[] memory amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            amount,
            amountBOutMin,
            path,
            address(this),
            deadline
        );
        amountA = amounts[0];
        amountB = amounts[amounts.length - 1];
        $.investments[tokenId] = TradePosition({
            investedA: amountA,
            amountB: amountB,
            inr: inr,
            start: clock(),
            end: 0,
            max_profit: $.defaultMaximumProfit,
            profit_per_day: $.defaultProfitPerDay,
            paidA: 0,
            soldB: 0,
            paidInr: 0
        });
        $.developerBalance +=  ($.developerFee * amountB) / SCALE;
        $.totalBalanceB += amountB; 
        $.totalInvestmentA += amountA;
        emit OpenTradePosition(tokenId, to, amountA, amountB, inr);
        return (amountA, amountB);
    }

    function closeTrade(uint256 tokenId, address[] memory path, address to, uint256 amountAOutMin, uint deadline) onlyRole(TRADER_ROLE) nonReentrant external returns(uint256) {
        _requireOwned(tokenId);
        require(hasRole(EXCHANGER_ROLE, to), "Reciever is not exchanger");
        require(path[0] == tokenB, "Invalid path start");
        require(path[path.length - 1] == tokenA, "Invalid path end");
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        TradePosition storage investment = $.investments[tokenId];
        require(investment.end == 0, "Trade already closed");
        require(investment.amountB > 0, "No balance to sell");
        investment.end = clock();
        uint256[] memory amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            investment.amountB,
            amountAOutMin,
            path,
            address(this),
            deadline
        );
        uint256 amountA = amounts[amounts.length - 1];
        uint256 amountB = amounts[0];
        investment.soldB = amountB;
        $.totalBalanceB -= amountB;
        (uint256 base, uint256 extra ) = _profit(amountA, tokenId);
        uint256 total = base + extra;
        require(total <= IERC20(tokenA).balanceOf(address(this)), "Not enough balance");
        if (amountA > total) {
            uint256 profit = amountA - total;
            $.systemProfitA += profit;
            IERC20(tokenA).safeTransfer($.accountant, profit);
        } else { 
            if (amountA <  total) {
                $.systemDeficiteA += total - amountA;
            }
        }
        investment.paidA += total;
        investment.paidInr += tokenA2inr(total);
        $.totalPaidA += total;
        IERC20(tokenA).safeTransfer(to, base);
        if (extra > 0) { IERC20(tokenA).safeTransfer(to, extra); }
         emit CloseTradePosition(tokenId, to,  amountA, amountB, total, tokenA2inr(total));
        return total;
    }


    function viewPendingProfit(uint256 tokenId, address[] memory path) public view 
        returns(uint256 base, uint256 extra, uint256[] memory amounts) {
        _requireOwned(tokenId);
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        TradePosition storage investment = $.investments[tokenId];
        amounts = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(investment.amountB, path);
        (base, extra)  = _profit(amounts[path.length - 1], tokenId);
        return(base, extra, amounts);
    }

    function withdrawDeveveloperFee(address to) public onlyRole(DEV_ROLE) {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        uint256 balance = IERC20(tokenB).balanceOf(address(this));
        require(balance >= ($.totalBalanceB + $.developerBalance), "Not enought balance for dev fee");
        IERC20(tokenB).safeTransfer(to, $.developerBalance);
        $.developerBalance = 0;
    }

    function burn(uint256 tokenId) public override onlyRole(MANAGER_ROLE) {
        _requireOwned(tokenId);
        _burn(tokenId);
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        delete $.investments[tokenId];
    }

    // function isApprovedForAll(address owner, address operator) public view override(ERC721, IERC721) virtual returns (bool) {
    //     return super.isApprovedForAll(owner,operator) || hasRole(MANAGER_ROLE, operator);
    // }



    // view functions

    function _profit(uint256 amount, uint256 tokenId) internal virtual view returns(uint256 base, uint256 extra) {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        TradePosition storage investment = $.investments[tokenId];
        base = inr2tokenA(investment.inr);
        if (amount > base) {
            uint48 time_range = daysFrom(investment.start);
            uint256 profit = amount - base;
            if (time_range <= investment.max_profit/investment.profit_per_day ) {
                extra = profit * time_range * investment.profit_per_day/SCALE;
            } else {
                extra = profit * investment.max_profit/SCALE;
            }
        }
        return (base, extra);
    }


    function inr2tokenA(uint256 inr) public  view returns(uint256 amountA)  {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        return((SCALE * inr)/ $.inrRate);
    }

    function tokenA2inr(uint256 amountA) public  view returns(uint256 inr)  {
        BaseInvestStorage storage $ = _getBaseInvestStorage();
        return (($.inrRate * amountA) / SCALE);
    }


    // return full days from some start point
    // start - start time in seconds
    function daysFrom(uint48 start) public view returns(uint48) {
        require(clock() >= start, "invalid time range");
        return( (clock() - start) / 1 seconds);
    }

    // service functions
    function clock() public view  returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure returns (string memory) {
        return "mode=timestamp";
    }


    // Add some extra protections functions

    function withdrawStuckETH(address payable _addressTo, uint256 _amount) onlyRole(DEFAULT_ADMIN_ROLE) public returns(uint256){
        require(_amount <= address(this).balance, "Insufficient ETH balance");
        _addressTo.transfer(_amount);
        return address(this).balance;
    }

    function withdrawStuckErc20Tokens(address _token, address _to) onlyRole(DEFAULT_ADMIN_ROLE) public {
        uint256 tokenAmount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, tokenAmount);
    }


// standart functions 

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // function safeMint(address to, uint256 tokenId) public onlyRole(MINTER_ROLE) {
    //     _safeMint(to, tokenId);
    // }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
