// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAeroFactory {
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
}

interface IAeroPool {
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IAeroRouterI {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

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

/// @notice Aerodrome Ignition shelf — create RSS/USDC pool + RSS-heavy LP when USDC seed exists on hot.
/// @dev KING_OK=1 FIRE_IGNITION=1. Set SEED_USDC (6dp). Uses RSS from hot (asymmetric POL).
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

        uint256 seedUsdc = vm.envOr("SEED_USDC", uint256(0));
        uint256 rssSeed = vm.envOr("RSS_SEED", seedUsdc * 1e12); // ~$1 peg RSS wei
        require(seedUsdc > 0, "NEED SEED_USDC on hot");

        address pool = IAeroFactory(AERO_FACTORY).getPool(RSS, USDC, false);
        console2.log("poolBefore", pool);

        vm.startBroadcast(pk);

        if (pool == address(0)) {
            pool = IAeroFactory(AERO_FACTORY).createPool(RSS, USDC, false);
        }
        console2.log("pool", pool);

        IERC20I(RSS).approve(AERO_ROUTER, rssSeed);
        IERC20I(USDC).approve(AERO_ROUTER, seedUsdc);
        (uint256 a, uint256 b, uint256 liq) = IAeroRouterI(AERO_ROUTER).addLiquidity(
            RSS, USDC, false, rssSeed, seedUsdc, 0, 0, HOT, block.timestamp + 30 minutes
        );

        vm.stopBroadcast();

        console2.log("amountRss", a);
        console2.log("amountUsdc", b);
        console2.log("liquidity", liq);
        console2.log("IGNITION_OK", uint256(1));
    }
}
