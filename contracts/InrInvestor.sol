// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;


import {Investor} from "./Investor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


event Open(address to, uint256 amount1, uint256 amount2, uint256 amountInr);
event Close(uint256 tokenId, address to, uint256 amount1, uint256 amount2, uint256 total,  uint256 amountInr);
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
    mapping(uint256 _tokenId => uint256 _inr) investedInr;

    constructor (address _tokenA, address _tokenB, address _V2router) Investor( _msgSender(),  _tokenA,  _tokenB,  _V2router) {
        _grantRole(TRADER_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        _grantRole(ACCOUNTER_ROLE, _msgSender());
        dev_fee = 10 ** 7;
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
        IERC20(tokenA).safeTransfer(to,amount );
        emit WithdrawProfit(to, amount);
    }


    function openTrade(address to, uint256 amountA, uint256 amountBOutMin, uint deadline, uint256 _amountInr) onlyRole(TRADER_ROLE) external payable returns(uint[] memory amounts) {
        require(_msgValue() >= dev_fee * amountA, "dev fee"); // add developer fee
        uint256 tokenId = _mint(to);
        amounts = _openTrade(tokenId, amountA, amountBOutMin, deadline);
        _initalInvestment(tokenId, amounts[0], amounts[1], default_profit_max, default_profit_per_day);
        emit Open(to, amounts[0], amounts[1], _amountInr);
        return amounts;
    }


    function closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline, uint256 inr) onlyRole(TRADER_ROLE) external returns(uint256) {
        
        address to = _ownerOf(tokenId);
        // address owner, address spender, uint256 tokenId
        _isAuthorized(to, _msgSender(), tokenId);
        // uint256 tokenId, address to, uint256 amountOutMin, uint deadline
        (uint256 amountA,uint256 amountB, uint256 total)  = _closeTrade(tokenId, to, amountOutMin, deadline);
        require(_msgValue() >= dev_fee * amountA, "dev fee"); // add developer fee
         _update(address(0), tokenId, _msgSender()); // It checks authentication
        emit Close(tokenId, to,  amountA, amountB, total, inr);
        return total;
    }
    
    function withdrawDevFee() public onlyRole(DEV_ROLE) {
            payable(_msgSender()).transfer(address(this).balance);
    }


    // internal 
    function _msgValue() internal view virtual returns (uint256) {
        return msg.value ;
    }
} 