// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPsm} from "../src/CrownPsm.sol";

interface IAeroFactory {
    function getPool(address a, address b, bool stable) external view returns (address);
    function createPool(address a, address b, bool stable) external returns (address);
}

interface IAeroRouter {
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

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice FORCE FILL — PSM 1:1 + Aero kUSD/USDC seed. Sword + shield.
/// @dev KING_OK=1 FIRE_FORCE_FILL=1
///      STOCK_KUSD (default 700_000e6 — full mint into PSM for USDC buyers)
///      SEED_USDC (default hot-above-floor into Aero stable pool)
contract FireForceFill is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_FORCE_FILL", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 stockKusd = vm.envOr("STOCK_KUSD", uint256(700_000e6));
        uint256 hotFloor = vm.envOr("HOT_USDC_FLOOR", uint256(1e6)); // keep $1 ops
        uint256 hotUsdc = IERC20X(USDC).balanceOf(HOT);
        uint256 seedUsdc = vm.envOr("SEED_USDC", uint256(0));
        if (seedUsdc == 0 && hotUsdc > hotFloor) seedUsdc = hotUsdc - hotFloor;

        vm.startBroadcast(pk);

        CrownPsm psm = new CrownPsm(USDC, KUSD, HOT, COLD, HOT);
        console2.log("CrownPsm", address(psm));

        // Stock kUSD — counterparties buy with USDC at $1 → USDC enters PSM
        uint256 kBal = IERC20X(KUSD).balanceOf(HOT);
        if (stockKusd > kBal) stockKusd = kBal;
        if (stockKusd > 0) {
            IERC20X(KUSD).approve(address(psm), stockKusd);
            psm.stockKusd(stockKusd);
            console2.log("psmKusdStocked", stockKusd);
        }

        // Aero stable kUSD/USDC — organic depth tip
        address pool = IAeroFactory(AERO_FACTORY).getPool(KUSD, USDC, true);
        if (pool == address(0)) {
            pool = IAeroFactory(AERO_FACTORY).createPool(KUSD, USDC, true);
            console2.log("createdPool", pool);
        } else {
            console2.log("existingPool", pool);
        }

        if (seedUsdc > 0) {
            // 1:1 seed: same raw units (both 6dp)
            uint256 seedKusd = seedUsdc;
            if (seedKusd > IERC20X(KUSD).balanceOf(HOT)) seedKusd = IERC20X(KUSD).balanceOf(HOT);
            if (seedKusd > 0) {
                IERC20X(USDC).approve(AERO_ROUTER, seedUsdc);
                IERC20X(KUSD).approve(AERO_ROUTER, seedKusd);
                (uint256 a, uint256 b, uint256 liq) = IAeroRouter(AERO_ROUTER).addLiquidity(
                    KUSD,
                    USDC,
                    true,
                    seedKusd,
                    seedUsdc,
                    0,
                    0,
                    HOT,
                    block.timestamp + 1 hours
                );
                console2.log("seededKusd", a);
                console2.log("seededUsdc", b);
                console2.log("lp", liq);
            }
        }

        vm.stopBroadcast();

        console2.log("buyPath", "psm.buyKusdWithUsdc USDC in kUSD out");
        console2.log("offRamp", "psm.sellKusdForUsdc needs USDC stock");
        console2.log("sweep", "psm.sweepUsdcToLanding");
        console2.log("FORCE_FILL_ARMED", uint256(1));
    }
}
