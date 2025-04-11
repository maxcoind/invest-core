

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract TokenOcean is  ERC20, AccessControl {

    address token;
    bytes32 public constant SENDER_ROLE = keccak256("SENDER_ROLE");

    constructor(address defaultAdmin, address _token)
        ERC20("TokenOcean", "TO")
    { 
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        token = _token; 
    }

    /**
     * @dev Returns the value of tokens in balance.
     */
    function totalSupply() public override view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _update(address from, address to, uint256 value) internal override virtual {
        IERC20(token).transfer(to, value);
        emit Transfer(from, to, value);
    }

    // /**
    //  * @dev Returns the value of tokens owned by `account`.
    //  */
    // function balanceOf(address account) external view returns (uint256) {
    //     return 0;
    // }

    // /**
    //  * @dev Moves a `value` amount of tokens from the caller's account to `to`.
    //  *
    //  * Returns a boolean value indicating whether the operation succeeded.
    //  *
    //  * Emits a {Transfer} event.
    //  */
    // function transfer(address to, uint256 value) external returns (bool) {
    //     return false;
    // }

    // /**
    //  * @dev Returns the remaining number of tokens that `spender` will be
    //  * allowed to spend on behalf of `owner` through {transferFrom}. This is
    //  * zero by default.
    //  *
    //  * This value changes when {approve} or {transferFrom} are called.
    //  */
    // function allowance(address owner, address spender) external view returns (uint256) {
    //     return 0;
    // }

    // /**
    //  * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
    //  * caller's tokens.
    //  *
    //  * Returns a boolean value indicating whether the operation succeeded.
    //  *
    //  * IMPORTANT: Beware that changing an allowance with this method brings the risk
    //  * that someone may use both the old and the new allowance by unfortunate
    //  * transaction ordering. One possible solution to mitigate this race
    //  * condition is to first reduce the spender's allowance to 0 and set the
    //  * desired value afterwards:
    //  * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    //  *
    //  * Emits an {Approval} event.
    //  */
    // function approve(address spender, uint256 value) external returns (bool) {
    //     return false;
    // }

    // /**
    //  * @dev Moves a `value` amount of tokens from `from` to `to` using the
    //  * allowance mechanism. `value` is then deducted from the caller's
    //  * allowance.
    //  *
    //  * Returns a boolean value indicating whether the operation succeeded.
    //  *
    //  * Emits a {Transfer} event.
    //  */
    // function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    //     return false;
    // }


    // function pause() public onlyOwner {
    //     _pause();
    // }

    // function unpause() public onlyOwner {
    //     _unpause();
    // }





}
