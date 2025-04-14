// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenB is ERC20, Ownable {
    constructor() ERC20("USDC", "USDC") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) onlyOwner public {
        _mint(to, amount);
    }
    
    function decimals() public view override virtual returns (uint8) {
        return 18;
    }

}