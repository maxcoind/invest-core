// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;


import {Investor} from "./Investor.sol";
import {Developed} from "./Developed.sol";

event Open(address to, uint256 amount1, uint256 amount2, uint256 amountInr);
event Close(uint256 tokenId, address to, uint256 amount1, uint256 amount2, uint256 total,  uint256 amountInr);

contract InrInvestor is Investor {
 
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
    uint256 public constant DEV_FEE = 10 ** 7;
    mapping(uint256 _tokenId => uint256 _inr) investedInr;

    constructor (address defaultAdmin, address _tokenA, address _tokenB, address _V2router) Investor( defaultAdmin,  _tokenA,  _tokenB,  _V2router) {
        _grantRole(TRADER_ROLE, defaultAdmin);
    }

    function openTrade(address to, uint256 amountA, uint256 amountBOutMin, uint deadline, uint256 _amountInr) onlyRole(TRADER_ROLE) external payable returns(uint[] memory amounts) {
        require(_msgValue() >= DEV_FEE * amountA, "dev fee"); // add developer fee
        uint256 tokenId = _mint(to);
        amounts = _openTrade(tokenId, amountA, amountBOutMin, deadline);
        _initalInvestment(tokenId, amounts[0], amounts[1]);
        emit Open(to, amounts[0], amounts[1], _amountInr);
        return amounts;
    }


    function closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline, uint256 inr) onlyRole(TRADER_ROLE) external returns(uint256) {
        
        address to = _ownerOf(tokenId);
        // address owner, address spender, uint256 tokenId
        _isAuthorized(to, _msgSender(), tokenId);
        // uint256 tokenId, address to, uint256 amountOutMin, uint deadline
        (uint256 amountA,uint256 amountB, uint256 total)  = _closeTrade(tokenId, to, amountOutMin, deadline);
        require(_msgValue() >= DEV_FEE * amountA, "dev fee"); // add developer fee
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