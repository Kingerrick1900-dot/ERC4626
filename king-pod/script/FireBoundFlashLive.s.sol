// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownFlashBoundAttest} from "../src/CrownFlashBoundAttest.sol";
import {CrownBoundReservesGate} from "../src/zk/CrownBoundReservesGate.sol";

/// @notice Live fire: approve flash pullback → Morpho flash → attestLive → repay.
/// @dev KING_OK=1 FIRE_BOUND_FLASH=1 FLASH=0x… GATE=0x…
///      AMOUNT defaults to 700_000e6. Hot must approve FLASH for AMOUNT before/within broadcast.
contract FireBoundFlashLive is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_BOUND_FLASH", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address flashAddr = vm.envAddress("FLASH");
        address gateAddr = vm.envAddress("GATE");
        uint256 amount = vm.envOr("AMOUNT", uint256(700_000e6));

        CrownFlashBoundAttest flash = CrownFlashBoundAttest(flashAddr);
        CrownBoundReservesGate gate = CrownBoundReservesGate(gateAddr);
        IERC20 usdc = IERC20(USDC);

        uint256 landingBefore = usdc.balanceOf(LANDING);
        uint256 hotBefore = usdc.balanceOf(HOT);

        vm.startBroadcast(pk);
        usdc.approve(flashAddr, amount);
        (bool proven, uint256 landingDelta) = flash.fireLive(amount);
        vm.stopBroadcast();

        console2.log("proven", proven);
        console2.log("gate.isProven", gate.isProven(HOT));
        (uint256 thr, uint256 at, bool valid) = gate.attestations(HOT);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
        console2.log("landingDelta", landingDelta);
        console2.log("landingUsdc", usdc.balanceOf(LANDING));
        console2.log("hotUsdcAfter", usdc.balanceOf(HOT));
        console2.log("hotUsdcBefore", hotBefore);
        console2.log("landingBefore", landingBefore);
        console2.log("PHYSICS: flash leaves net-zero; landingDelta>0 only if credit had USDC");
    }
}
