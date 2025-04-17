// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;


import {Investor} from "./Investor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";


event Open(address to, uint256 amount1, uint256 amount2, uint256 inr, bytes32 hash);
event Close(uint256 tokenId, address to, uint256 amount1, uint256 amount2, uint256 total,  uint256 inr);
event DevFee(uint256 fee);
event Profit(uint256 max, uint256 per_day);
event WithdrawProfit(address to, uint256 amount);
// ToDo: Add investment hash


contract InrInvestor is Investor {
    using SafeERC20 for IERC20;
 
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ACCOUNTER_ROLE = keccak256("ACCOUNTER_ROLE");
    uint256 public dev_fee ;
    uint256 public dev_balance;
    mapping(uint256 _tokenId => uint256 _inr) investedInr;
    mapping(bytes32 => bool) exists;
    mapping(bytes32 => uint256) hash2tokenId;


    constructor (address _tokenA, address _tokenB, address _V2router) Investor( _msgSender(),  _tokenA,  _tokenB,  _V2router) {
        _grantRole(TRADER_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(ACCOUNTER_ROLE, _msgSender());
        dev_fee = 1;
        _updateProfit(8000, 5);

    }

    function updateProfit(uint256 max, uint256 per_day) public onlyRole(MANAGER_ROLE) {
        updateProfit(max, per_day);
    }

    function updateDevFee( uint256 _fee) public onlyRole(DEFAULT_ADMIN_ROLE){
        dev_fee = _fee;
        emit DevFee(_fee);
    }

    function updateProfitRate(uint256 tokenId, uint256 _max_profit, uint256 _profit_per_day) public onlyRole(ACCOUNTER_ROLE) {
        _update_profit_rate(tokenId, _max_profit, _profit_per_day); 
    }

    function withdrawProfit(address to) public onlyRole(ACCOUNTER_ROLE) {
        uint256 amount = IERC20(tokenA).balanceOf(address(this)); 
        require(amount > dev_balance, "Not enough money");
        amount -= dev_balance; 
        IERC20(tokenA).safeTransfer(to,amount);
        emit WithdrawProfit(to, amount);
    }


    function openTrade(address to, uint256 amountA, uint256 amountBOutMin, uint deadline, uint256 inr, bytes32 _hash) onlyRole(TRADER_ROLE) external payable returns(uint[] memory amounts) {
        require(!exists[_hash], "hash exists");
        exists[_hash] = true;
        dev_balance +=  dev_fee * amountA/SCALE;
        uint256 tokenId = _mint(to);
        hash2tokenId[_hash] = tokenId;
        amounts = _openTrade(tokenId, amountA, amountBOutMin, deadline);
        _initalInvestment(tokenId, amounts[0], amounts[1], default_profit_max, default_profit_per_day);
        emit Open(to, amounts[0], amounts[1], inr, _hash);
        return amounts;
    }


    function closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline, uint256 inr) onlyRole(TRADER_ROLE) external returns(uint256) {
        console.log("Before check owner");
        address to = _ownerOf(tokenId);
        _isAuthorized(to, _msgSender(), tokenId);
        console.log("Before close trade");
        (uint256 amountA,uint256 amountB, uint256 total)  = _closeTrade(tokenId, to, amountOutMin, deadline);
        console.log("After close trade");
        dev_balance +=  dev_fee * amountA/SCALE;
         _update(address(0), tokenId, _msgSender()); // It checks authentication
        emit Close(tokenId, to,  amountA, amountB, total, inr);
        return total;
    }
    
    function withdrawDevFee(address to) public onlyRole(DEV_ROLE) {
        IERC20(tokenA).safeTransfer(to, dev_balance);
        dev_balance = 0;
    }


    // internal 
    function _msgValue() internal view virtual returns (uint256) {
        return msg.value ;
    }


    // Add some extra protections
    function withdrawStuckETH(address payable _addressTo, uint256 _amount) onlyRole(DEFAULT_ADMIN_ROLE) public returns(uint256){
        _addressTo.transfer(_amount);
        return address(this).balance;
    }

    function withdrawStuckErc20Tokens(address _token, address _to) onlyRole(DEFAULT_ADMIN_ROLE) public {
        uint256 tokenAmount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, tokenAmount);
    }

} 