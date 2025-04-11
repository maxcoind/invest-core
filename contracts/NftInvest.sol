// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {NftInvestAbstract } from "./NftInvestAbstract.sol";


event Open(uint256 amount1, uint256 amount2);
event Close(uint256 amount1, uint256 amount2);


contract NftInvest is NftInvestAbstract {
        constructor (address defaultAdmin, address _tokenA, address _tokenB, uint48 _apy, address _V2router) NftInvestAbstract( defaultAdmin,  _tokenA,  _tokenB,  _apy,  _V2router) {
    }

    
    function openTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) onlyRole(TRADER_ROLE) external returns(uint[] memory amounts) {
        require(_requireOwned(tokenId)!= address(0), "NFT not exists");
        amounts = _openTrade(tokenId, amountOutMin, deadline);
        emit Open(amounts[0], amounts[1]);
        return amounts;
    }

    function closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) onlyRole(TRADER_ROLE) external returns(uint[] memory amounts) {
        require(_requireOwned(tokenId)!= address(0), "NFT not exists");
        amounts = _closeTrade(tokenId, amountOutMin, deadline);
        emit Close(amounts[0], amounts[1]);
        return amounts;
    }

}