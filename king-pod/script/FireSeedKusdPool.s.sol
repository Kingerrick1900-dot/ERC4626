// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAeroRouterS {
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Seed Aero stable kUSD/USDC with hot balances. KING_OK=1 FIRE_SEED_KUSD=1
contract FireSeedKusdPool is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_SEED_KUSD", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 seed = vm.envOr("SEED_USDC", uint256(6e6));
        uint256 k = IERC20S(KUSD).balanceOf(HOT);
        uint256 u = IERC20S(USDC).balanceOf(HOT);
        if (seed > k) seed = k;
        if (seed > u - 1e6) seed = u > 1e6 ? u - 1e6 : 0;
        require(seed > 0, "NO_SEED");

        vm.startBroadcast(pk);
        IERC20S(KUSD).approve(ROUTER, seed);
        IERC20S(USDC).approve(ROUTER, seed);
        (uint256 a, uint256 b, uint256 liq) = IAeroRouterS(ROUTER).addLiquidity(
            KUSD, USDC, true, seed, seed, 0, 0, HOT, block.timestamp + 1 hours
        );
        vm.stopBroadcast();
        console2.log("seededKusd", a);
        console2.log("seededUsdc", b);
        console2.log("lp", liq);
    }
}
