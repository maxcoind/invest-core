// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;


import {AbstractInvestor, Investment} from "./AbstractInvestor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


import "hardhat/console.sol";


event Open(address to, uint256 amountA, uint256 amountB, uint256 inr, bytes32 hash);
event Close(uint256 tokenId, address to, uint256 amountA, uint256 amountB, uint256 total, uint256 inr_rate);
event DevFee(uint256 fee);
event Profit(uint256 max, uint256 per_day);
event WithdrawProfit(address to, uint256 amount);
event Accountant(address accountant);
// ToDo: Profit in INR
// ToDo: [x] INR exchange rate
// ToDo: [x] Add Exchanger group
// ToDo: [x] Allow withdraw only to exchanger
// ToDo: [x] Add manager to autoapproval of account

event InrRateUpdated(uint256 newRate);

contract InrInvestor is AbstractInvestor, ReentrancyGuard {
    using SafeERC20 for IERC20;
 
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ACCOUNTER_ROLE = keccak256("ACCOUNTER_ROLE");
    bytes32 public constant EXCHANGER_ROLE = keccak256("EXCHANGER_ROLE");

    address public accountant;

    uint256 public dev_fee ;
    uint256 public dev_balance;
    uint256 public inr_rate; // rate = SCALE * INR / TokenA
    mapping(uint256 _tokenId => uint256 _inr) investedInr;
    mapping(bytes32 => bool) exists;
    mapping(bytes32 => uint256) hash2tokenId;

    // Counters
    uint256 totalInvestmentA; //How much it was invested total
    uint256 totalPaidA; // How much it was paid in total
    uint256 totalProfitA; // How much it was made in total
    uint256 totalDeficiteA;

    constructor (address _tokenA, address _tokenB, address _V2router, address _accountant) AbstractInvestor( _msgSender(),  _tokenA,  _tokenB,  _V2router) {
        _grantRole(TRADER_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(ACCOUNTER_ROLE, _msgSender());
        dev_fee = 1;
        inr_rate = 20000; // 1 to 1
        accountant = _accountant;
        _updateDefaultProfitRate(8000, 5);
    }

    function setAccountant(address _accountant) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(accountant != address(0), "Invalid accountant address");
        accountant = _accountant;
        emit Accountant(accountant);
    }


    function setInrRate(uint256 rate) public onlyRole(ACCOUNTER_ROLE) {
        require(rate > 0 && rate < 1e18, "Invalid INR rate");
        inr_rate = rate;
        emit InrRateUpdated(rate);
    }

    function updateProfit(uint256 max, uint256 per_day) public onlyRole(MANAGER_ROLE) {
        _updateDefaultProfitRate(max, per_day);
    }

    function updateDevFee( uint256 _fee) public onlyRole(DEFAULT_ADMIN_ROLE){
        dev_fee = _fee;
        emit DevFee(_fee);
    }

    function updateProfitRate(uint256 tokenId, uint256 _max_profit, uint256 _profit_per_day) public onlyRole(ACCOUNTER_ROLE) {
        _update_profit_rate(tokenId, _max_profit, _profit_per_day); 
    }

    function withdrawTokenA(address to, uint256 amount) public onlyRole(ACCOUNTER_ROLE) {
        uint256 balance = IERC20(tokenA).balanceOf(address(this));
        require(amount <= (balance - dev_balance), "Not enough money"); 
        IERC20(tokenA).safeTransfer(to, amount);
        emit WithdrawProfit(to, amount);
    }

    

    function openTrade(address to, uint256 inr, uint256 amountBOutMin, uint deadline, bytes32 _hash) onlyRole(TRADER_ROLE) nonReentrant external payable returns(uint[] memory amounts) {
        require(!exists[_hash], "hash exists");
        uint256 amountA = SCALE * inr / inr_rate;
        exists[_hash] = true;
        dev_balance +=  (dev_fee * amountA) / SCALE;
        uint256 tokenId = _mint(to);
        hash2tokenId[_hash] = tokenId;
        investedInr[tokenId] = inr;
        console.log("Open trade, Amount A:", amountA);
        amounts = _openTrade(tokenId, amountA, amountBOutMin, deadline);
        totalInvestmentA += amounts[0];
        _initalInvestment(tokenId, amounts[0], amounts[1], default_profit_max, default_profit_per_day);
        emit Open(to, amounts[0], amounts[1], inr, _hash);
        return amounts;
    }

    function closeTrade(uint256 tokenId, address to, uint256 amountOutMin, uint deadline) onlyRole(TRADER_ROLE) nonReentrant external returns(uint256) {
        require(hasRole(EXCHANGER_ROLE, to), "Reciever is not exchanger");
        console.log("Before close trade");
        (uint256 amountA, uint256 amountB)  = _closeTrade(tokenId, amountOutMin, deadline);
        dev_balance +=  (dev_fee * amountA) / SCALE;
        (uint256 base, uint256 extra ) = _profit(amountA, tokenId);
        uint256 total = base + extra;

        if (amountA > total) {
            uint256 profit = amountA - total;
            totalProfitA += profit;
            IERC20(tokenA).safeTransfer(accountant, profit);
        } else { 
            if (amountA <  total) {
                totalDeficiteA += total - amountA;
            }
        }
        totalPaidA += total;
        IERC20(tokenA).safeTransfer(to, base);
        if (extra > 0) { IERC20(tokenA).safeTransfer(to, extra); }
         _update(address(0), tokenId, _msgSender()); // Burn, It checks authentication
         emit Close(tokenId, to,  amountA, amountB, total, inr_rate);
        return total;
    }


    // returns AmountA, AmountB, baseA, extraA
    function viewPendingProfit(uint256 tokenId) public view returns(uint[] memory amounts) {
        assert(_ownerOf(tokenId) != address(0));
        address[] memory path = new address[](2);
        path[0] = tokenB;
        path[1] = tokenA;
        Investment storage inv = investments[tokenId];
        uint256[] memory swapAmounts = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(inv.amountB, path);
        (uint256 base, uint256 extra)  = _profit(swapAmounts[1], tokenId);
        amounts = new uint256[](4);
        amounts[0] = swapAmounts[1];
        amounts[1] = swapAmounts[0];
        amounts[2] = base;
        amounts[4] = extra;
        return amounts;
    }

    
    function withdrawDevFee(address to) public onlyRole(DEV_ROLE) {
        IERC20(tokenA).safeTransfer(to, dev_balance);
        dev_balance = 0;
    }


    function isApprovedForAll(address owner, address operator) public view override(ERC721, IERC721) virtual returns (bool) {
        return super.isApprovedForAll(owner,operator) || hasRole(MANAGER_ROLE, operator);
    }


    // internal 
    function _profit(uint256 amount, uint256 tokenId) internal virtual view returns(uint256 base, uint256 extra) {
        Investment storage investment = investments[tokenId];
        base = investedInr[tokenId] * SCALE / inr_rate;
        if (amount > base) {
            uint48 time_range = _daysFrom(investment.start);
            uint256 profit = amount - base;
            if (time_range <= investment.max_profit/investment.profit_per_day ) {
                extra = profit * time_range * investment.profit_per_day/SCALE;
            } else {
                extra = profit * investment.max_profit/SCALE;
            }
        }
        return (base, extra);
    }


    // Add some extra protections
    function withdrawStuckETH(address payable _addressTo, uint256 _amount) onlyRole(DEFAULT_ADMIN_ROLE) public returns(uint256){
        require(_amount <= address(this).balance, "Insufficient ETH balance");
        _addressTo.transfer(_amount);
        return address(this).balance;
    }

    function withdrawStuckErc20Tokens(address _token, address _to) onlyRole(DEFAULT_ADMIN_ROLE) public {
        uint256 tokenAmount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, tokenAmount);
    }

} 