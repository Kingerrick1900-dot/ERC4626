// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAeroFactory {
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
}

interface IAeroRouterI {
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

interface IERC20I {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice CREATE OPPORTUNITY — Aerodrome RSS/USDC venue. RSS is the budget. No "bring capital" talk.
/// @dev KING_OK=1 FIRE_IGNITION=1
///      CREATE_POOL=1  — create empty volatile pool (gas only)
///      SEED_USDC      — optional thin USDC for asymmetric LP (default 0 = pool only)
///      RSS_SEED       — RSS into LP (default 100k if seeding)
///      HOT_USDC_FLOOR — keep ops float (default $5)
contract FireAeroIgnition is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_IGNITION", uint256(0)) == 1, "FIRE_IGNITION");

        bool createPool = vm.envOr("CREATE_POOL", uint256(1)) == 1;
        uint256 seedUsdc = vm.envOr("SEED_USDC", uint256(0));
        uint256 hotFloor = vm.envOr("HOT_USDC_FLOOR", uint256(5_000_000)); // keep $5
        uint256 rssSeed = vm.envOr("RSS_SEED", seedUsdc > 0 ? uint256(100_000 ether) : uint256(0));

        uint256 hotUsdc = IERC20I(USDC).balanceOf(HOT);
        uint256 rssBal = IERC20I(RSS).balanceOf(HOT);

        console2.log("=== CREATE AERO OPPORTUNITY ===");
        console2.log("hotUsdc", hotUsdc);
        console2.log("rssHot", rssBal);
        console2.log("createPool", createPool ? uint256(1) : uint256(0));
        console2.log("seedUsdc", seedUsdc);
        console2.log("rssSeed", rssSeed);

        if (seedUsdc > 0) {
            require(hotUsdc >= seedUsdc + hotFloor, "KEEP HOT FLOOR");
            require(rssBal >= rssSeed && rssSeed > 0, "NEED RSS_SEED");
        }

        address pool = IAeroFactory(AERO_FACTORY).getPool(RSS, USDC, false);
        console2.log("poolBefore", pool);

        vm.startBroadcast(pk);

        if (createPool && pool == address(0)) {
            pool = IAeroFactory(AERO_FACTORY).createPool(RSS, USDC, false);
            console2.log("poolCreated", pool);
        } else {
            console2.log("pool", pool);
        }

        if (seedUsdc > 0 && rssSeed > 0) {
            require(pool != address(0), "NO POOL");
            IERC20I(RSS).approve(AERO_ROUTER, rssSeed);
            IERC20I(USDC).approve(AERO_ROUTER, seedUsdc);
            (uint256 a, uint256 b, uint256 liq) = IAeroRouterI(AERO_ROUTER).addLiquidity(
                RSS, USDC, false, rssSeed, seedUsdc, 0, 0, HOT, block.timestamp + 30 minutes
            );
            console2.log("amountRss", a);
            console2.log("amountUsdc", b);
            console2.log("liquidity", liq);
        }

        vm.stopBroadcast();

        address poolAfter = IAeroFactory(AERO_FACTORY).getPool(RSS, USDC, false);
        console2.log("poolAfter", poolAfter);
        console2.log("hotUsdcAfter", IERC20I(USDC).balanceOf(HOT));
        console2.log("CREATE_OK", poolAfter != address(0) ? uint256(1) : uint256(0));
    }
}
