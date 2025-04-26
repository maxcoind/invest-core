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
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";




struct Investment {
    uint48 start;
    uint256 investmentA; // Initial inventment amount
    uint256 amountB; // Balance of token B
    uint256 max_profit; // 1%=100, when SCALE=1000
    uint256 profit_per_day; // 0.05% = 5, when SCALE=1000
}


// Contract, which allows to track investments.
// Each investment represented as NFT
abstract contract AbstractInvestor is ERC721, ERC721Enumerable, ERC721Pausable, AccessControl{

    event Invest(uint256 tokenId,uint256 amount, address manager, address reciever);
    event ProfitRate(uint256 tokenId, uint256 max_profit, uint256 profit_per_day);
    event Profit(uint256 max, uint256 per_day);

    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 constant SCALE = 10000;
    uint256  default_profit_max;
    uint256  default_profit_per_day;

    uint256 private _nextTokenId;
    address public immutable tokenA;
    address public immutable tokenB;
    address public immutable uniswapV2Router02;

    mapping (uint256 => Investment) public investments;

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
    function _updateDefaultProfitRate(uint256 _max, uint256 _per_day) internal {
        default_profit_max = _max;
        default_profit_per_day = _per_day;
        emit Profit(_max, _per_day);
    }


    function _mint(address to) internal returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function _update_profit_rate(uint256 tokenId, uint256 _max_profit, uint256 _profit_per_day) internal {
        require(_ownerOf(tokenId) != address(0), "Investor: Token not exists");
        Investment storage investment = investments[tokenId];
        investment.max_profit = _max_profit;
        investment.profit_per_day = _profit_per_day;
        emit ProfitRate(tokenId, _max_profit, _profit_per_day);
    }

    function _initalInvestment(uint256 tokenId, uint256 amountA, uint256 amountB, uint256 _max_profit, uint256 _profit_per_day) internal {
        investments[tokenId] = Investment({
            investmentA: amountA,
            amountB: amountB,
            start: clock(),
            max_profit: _max_profit,
            profit_per_day: _profit_per_day
        });
    }

    // returns: amountA, amountB, total payed A 
    function _closeTrade(uint256 tokenId, uint256 amountOutMin, uint deadline) internal returns(uint256 amountA,uint256 amountB) {
        Investment storage investment = investments[tokenId];
        uint256 amount = investment.amountB;
        address[] memory path = new address[](2);
        path[0] = tokenB;
        path[1] = tokenA;
        uint256[] memory amounts = IUniswapV2Router02(uniswapV2Router02).swapExactTokensForTokens(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );
        investment.amountB -= amounts[0];
        return (amounts[1], amounts[0]);
    }


    function _openTrade(uint256 tokenId, uint256 amount, uint256 amountOutMin, uint deadline) internal returns(uint[] memory amounts) {
                address[] memory path = new address[](2);
        IERC20(tokenA).safeTransferFrom(_msgSender(),address(this),amount);
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


    // return full days from some start point
    // start - start time in seconds
    function _daysFrom(uint48 start) internal view returns(uint48) {
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