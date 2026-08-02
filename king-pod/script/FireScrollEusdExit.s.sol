// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IUniswapV3PoolX {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(address, bool, int256, uint160, bytes calldata) external returns (int256, int256);
}

/// @dev msg.sender on pool.swap — UniV3 callback pays eUSD.
contract EusdExitSwapper {
    address public constant POOL = 0x5f3f22344FbBF23DD6cF63670B05d4C6689063Fc;
    address public constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address public constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address public immutable king;

    constructor(address king_) {
        king = king_;
    }

    /// @notice Sell eUSD → USDC into `to`. token0=USDC token1=eUSD → zeroForOne=false.
    function swapEusdToUsdc(uint256 eusdIn, address to) external {
        require(msg.sender == king, "KING");
        require(eusdIn > 0, "AMT");
        uint160 limit = 1461446703485210103287273052203988822378723970341;
        IUniswapV3PoolX(POOL).swap(to, false, int256(eusdIn), limit, abi.encode(eusdIn));
        uint256 dustE = IERC20X(EUSD).balanceOf(address(this));
        uint256 dustU = IERC20X(USDC).balanceOf(address(this));
        if (dustE > 0) IERC20X(EUSD).transfer(king, dustE);
        if (dustU > 0) IERC20X(USDC).transfer(to, dustU);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == POOL, "POOL");
        // Selling token1 (eUSD): amount1Delta > 0 means we owe eUSD to pool
        if (amount1Delta > 0) {
            require(IERC20X(EUSD).transferFrom(king, POOL, uint256(amount1Delta)), "PAY_EUSD");
        }
        if (amount0Delta > 0) {
            // Should not happen when selling eUSD for USDC
            require(IERC20X(USDC).transferFrom(king, POOL, uint256(amount0Delta)), "PAY_USDC");
        }
    }
}

/// @notice eUSD exit leg — depth-aware clear to Landing. No completer. No false 100k.
/// @dev KING_GO=1 FIRE_EUSD_EXIT=1
///      Sizes swap to live pool USDC (keeps $0.01 floor). Pays Scroll Landing.
contract FireScrollEusdExit is Script {
    address constant HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant LAND = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant POOL = 0x5f3f22344FbBF23DD6cF63670B05d4C6689063Fc;
    uint256 constant FLOOR_USDC = 10_000; // keep $0.01 in pool

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_EUSD_EXIT", uint256(0)) == 1, "NEED FIRE_EUSD_EXIT=1");

        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 hotEusd = IERC20X(EUSD).balanceOf(HOT);
        uint256 poolUsdc = IERC20X(USDC).balanceOf(POOL);
        console2.log("EXIT_LEG", "eUSD/USDC pool");
        console2.log("hotEusd", hotEusd);
        console2.log("poolUsdc", poolUsdc);
        console2.log("landUsdcBefore", IERC20X(USDC).balanceOf(LAND));

        require(hotEusd > 0, "NO_EUSD");
        require(poolUsdc > FLOOR_USDC, "POOL_DRY");

        // Max eUSD the pool can pay for (6dp USDC → 18dp eUSD at $1)
        uint256 maxEusd = (poolUsdc - FLOOR_USDC) * 1e12;
        uint256 swapEusd = hotEusd < maxEusd ? hotEusd : maxEusd;
        // Optional env override (still capped to depth)
        uint256 ask = vm.envOr("SWAP_EUSD", swapEusd);
        if (ask < swapEusd) swapEusd = ask;
        require(swapEusd > 0, "NOTHING_TO_SWAP");

        console2.log("swapEusd", swapEusd);
        console2.log("expectUsdcOutApprox", swapEusd / 1e12);

        uint256 landBefore = IERC20X(USDC).balanceOf(LAND);

        vm.startBroadcast(pk);
        EusdExitSwapper swapper = new EusdExitSwapper(HOT);
        IERC20X(EUSD).approve(address(swapper), swapEusd);
        swapper.swapEusdToUsdc(swapEusd, LAND);
        vm.stopBroadcast();

        uint256 landAfter = IERC20X(USDC).balanceOf(LAND);
        uint256 hotEusdAfter = IERC20X(EUSD).balanceOf(HOT);
        uint256 poolUsdcAfter = IERC20X(USDC).balanceOf(POOL);
        console2.log("landUsdcAfter", landAfter);
        console2.log("landDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("hotEusdAfter", hotEusdAfter);
        console2.log("poolUsdcAfter", poolUsdcAfter);
        require(landAfter > landBefore, "NO_LANDING_FILL");
        console2.log("EUSD_EXIT_OK", uint256(1));
    }
}
