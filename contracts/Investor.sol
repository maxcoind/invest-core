// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {AbstractInvestor, Investment} from "./AbstractInvestor.sol";

event Open(address to, uint256 amount1, uint256 amount2);
event Close(uint256 tokenId, address to, uint256 amount1, uint256 amount2, uint256 total);



contract Investor is AbstractInvestor, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 totalInvestmentA; //How much it was invested total
    uint256 totalPaidA; // How much it was paid in total
    uint256 totalProfitA; // How much it was made in total
    uint256 totalDeficitA;


    constructor (address _tokenA, address _tokenB, address _V2router, address _factory) 
        AbstractInvestor( _msgSender(),  _tokenA,  _tokenB,  _V2router) {}

    /// @notice Opens a new trade by minting an NFT and swapping tokenA for tokenB.
    /// @param amount Amount of tokenA to invest.
    /// @param amountBOutMin Minimum tokenB expected from the swap.
    /// @param deadline Uniswap swap deadline.
    /// @return amounts Array containing [amountA, amountB].
    function openTrade(uint256 amount, uint256 amountBOutMin, uint deadline) nonReentrant  external returns(uint[] memory amounts) {
        address to = _msgSender();
        uint256 tokenId = _mint(to);
        amounts = _openTrade(tokenId, amount, amountBOutMin, deadline);
        _initalInvestment(tokenId, amounts[0], amounts[1], default_profit_max, default_profit_per_day);
        totalInvestmentA += amounts[0];
        emit Open(to, amounts[0], amounts[1]);
        return amounts;
    }

    function closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) nonReentrant  external returns(uint256) {
        address to = _ownerOf(tokenId);
        require(to != address(0), "Investor: Token not exists");
        (uint256 amountA,uint256 amountB)  = _closeTrade(tokenId, amountOutMin, deadline);

        uint256 total = _profit(amountA, tokenId);

        if (amountA > total) {
            totalProfitA += amountA - total;
        } else { 
            if (amountA <  total) {
                totalDeficitA += total - amountA;
            }
        }
        totalPaidA += total;
        IERC20(tokenA).safeTransfer(to, total);
         _update(address(0), tokenId, _msgSender()); // Burn, It checks authentication
        emit Close(tokenId, to, amountA, amountB, total);
        return total;
    }

    // returns AmountA, AmountB, totalA
    function viewPendingProfit(uint256 tokenId) public view returns(uint[] memory amounts) {
        assert(_ownerOf(tokenId) != address(0));
        address[] memory path = new address[](2);
        path[0] = tokenB;
        path[1] = tokenA;
        Investment storage inv = investments[tokenId];
        uint256[] memory swapAmounts = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(inv.amountB, path);
        uint256 total = _profit(swapAmounts[1], tokenId);
        amounts = new uint256[](3);
        amounts[0] = swapAmounts[1];
        amounts[1] = swapAmounts[2];
        amounts[2]=total;
        return amounts;
    }

    // internal
    
    function _profit(uint256 amount, uint256 tokenId) internal view virtual returns(uint256 total) {
        Investment storage investment = investments[tokenId];
        total = investment.investmentA;
        if (amount > total) {
            uint48 time_range = _daysFrom(investment.start);
            uint256 profit = amount - investment.investmentA;
            if (time_range <= investment.max_profit/investment.profit_per_day ) {
                total += profit * time_range * investment.profit_per_day/SCALE;
            } else {
                total += profit * investment.max_profit/SCALE;
            }
        }
        return total;
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