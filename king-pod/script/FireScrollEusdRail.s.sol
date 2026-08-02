// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @notice Scroll eUSD → USDC rail. Convert 100k only; Landing must keep ≥545k eUSD.
/// @dev KING_GO=1 FIRE_EUSD_RAIL=1
///      Pre: Landing wired exactly 100k eUSD to Scroll hot; Uni/PSM has USDC depth.
contract FireScrollEusdRail is Script {
    address constant HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant LAND = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    /// @dev Set via env ROUTER if a live SwapRouter02 is confirmed on Scroll.
    uint24 constant FEE = 3000;

    uint256 constant CONVERT = 100_000e18;
    uint256 constant KEEP_LANDING = 545_000e18;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_EUSD_RAIL", uint256(0)) == 1, "NEED FIRE_EUSD_RAIL=1");

        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 landEusd = IERC20R(EUSD).balanceOf(LAND);
        uint256 hotEusd = IERC20R(EUSD).balanceOf(HOT);
        console2.log("landEusd", landEusd);
        console2.log("hotEusd", hotEusd);
        console2.log("CONVERT", CONVERT);
        console2.log("KEEP_LANDING", KEEP_LANDING);

        // Landing must already be at/above keep after the 100k wire (or still hold ≥ keep if wire pending).
        require(landEusd >= KEEP_LANDING, "LANDING_BELOW_KEEP");
        require(hotEusd >= CONVERT, "NEED_100K_EUSD_ON_HOT");

        address router = vm.envAddress("ROUTER");
        require(router != address(0), "ROUTER");
        address recipient = vm.envOr("TO_LANDING", uint256(0)) == 1 ? LAND : HOT;

        uint256 usdcBefore = IERC20R(USDC).balanceOf(recipient);

        vm.startBroadcast(pk);
        IERC20R(EUSD).approve(router, CONVERT);
        uint256 out = ISwapRouter02(router).exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: EUSD,
                tokenOut: USDC,
                fee: FEE,
                recipient: recipient,
                amountIn: CONVERT,
                amountOutMinimum: vm.envOr("MIN_USDC_OUT", uint256(95_000e6)), // 5% slip vs $1
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopBroadcast();

        uint256 landAfter = IERC20R(EUSD).balanceOf(LAND);
        require(landAfter >= KEEP_LANDING, "KEEP_BROKEN");
        uint256 usdcAfter = IERC20R(USDC).balanceOf(recipient);
        console2.log("amountOut", out);
        console2.log("usdcDelta", usdcAfter - usdcBefore);
        console2.log("landEusdAfter", landAfter);
        console2.log("EUSD_RAIL_100K_OK", uint256(1));
    }
}
