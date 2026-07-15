// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable} from "./lib/Core.sol";

/// @notice Minimal constant-product AMM (UniV2-style) for RSS / sUSDC.
contract KingPair is Ownable {
    using SafeTransfer for IERC20;

    IERC20 public immutable token0; // RSS
    IERC20 public immutable token1; // sUSDC
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    event Mint(address indexed to, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address indexed to, uint256 amount0, uint256 amount1, uint256 liquidity);

    constructor(address rss, address sUsdc, address owner_) Ownable(owner_) {
        token0 = IERC20(rss);
        token1 = IERC20(sUsdc);
    }

    function mint(address to) external returns (uint256 liquidity) {
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));
        uint256 amount0 = bal0 - reserve0;
        uint256 amount1 = bal1 - reserve1;

        if (totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            balanceOf[address(0)] = MINIMUM_LIQUIDITY; // permanently locked
            totalSupply = MINIMUM_LIQUIDITY;
        } else {
            uint256 liq0 = (amount0 * totalSupply) / reserve0;
            uint256 liq1 = (amount1 * totalSupply) / reserve1;
            liquidity = liq0 < liq1 ? liq0 : liq1;
        }
        require(liquidity > 0, "INSUFFICIENT_LIQ");
        balanceOf[to] += liquidity;
        totalSupply += liquidity;
        _update(bal0, bal1);
        emit Mint(to, amount0, amount1, liquidity);
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf[address(this)];
        require(liquidity > 0, "NO_LIQ");
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));
        amount0 = (liquidity * bal0) / totalSupply;
        amount1 = (liquidity * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT");
        balanceOf[address(this)] -= liquidity;
        totalSupply -= liquidity;
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        emit Burn(to, amount0, amount1, liquidity);
    }

    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        _transfer(msg.sender, to, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amt, "ALLOW");
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amt;
        _transfer(from, to, amt);
        return true;
    }

    function _transfer(address from, address to, uint256 amt) private {
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /// @notice Sync reserves to current balances (post-donation).
    function sync() external {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    /// @notice Sell RSS (token0) for sUSDC (token1). `amountOutMin` in sUSDC shares.
    /// @dev Caller must approve this pair for `rssIn`. Pays out token1 (sUSDC), not LP.
    function swapRssForSusdc(uint256 rssIn, uint256 amountOutMin, address to) external returns (uint256 amountOut) {
        require(rssIn > 0 && to != address(0), "ZERO");
        uint256 r0 = reserve0;
        uint256 r1 = reserve1;
        require(r0 > 0 && r1 > 0, "NO_LIQ");
        token0.safeTransferFrom(msg.sender, address(this), rssIn);
        // 0.3% fee-style reserve: amountOut = rssIn*997*r1 / (r0*1000 + rssIn*997)
        amountOut = (rssIn * 997 * r1) / (r0 * 1000 + rssIn * 997);
        require(amountOut >= amountOutMin && amountOut > 0 && amountOut < r1, "SLIP");
        token1.safeTransfer(to, amountOut);
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    function _update(uint256 bal0, uint256 bal1) private {
        reserve0 = bal0;
        reserve1 = bal1;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
