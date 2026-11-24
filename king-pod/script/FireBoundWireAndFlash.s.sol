// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownBoundReservesGate} from "../src/zk/CrownBoundReservesGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownFlashBoundAttest} from "../src/CrownFlashBoundAttest.sol";
import {CrownZkAutoDraw} from "../src/CrownZkAutoDraw.sol";

/// @notice Finish wiring after partial deploy, then flash-bound attest.
/// @dev KING_OK=1 FIRE_BOUND_WIRE=1 GATE=… CREDIT=… FLASH=… COMPLETER=…
///      Optional SKIP_FLASH=1 to wire only. AMOUNT defaults 700_000e6.
contract FireBoundWireAndFlash is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_BOUND_WIRE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownBoundReservesGate gate = CrownBoundReservesGate(vm.envAddress("GATE"));
        CrownZkCredit credit = CrownZkCredit(vm.envAddress("CREDIT"));
        CrownFlashBoundAttest flash = CrownFlashBoundAttest(vm.envAddress("FLASH"));
        address completer = vm.envAddress("COMPLETER");
        uint256 amount = vm.envOr("AMOUNT", uint256(700_000e6));
        bool skipFlash = vm.envOr("SKIP_FLASH", uint256(0)) == 1;

        vm.startBroadcast(pk);

        address autoDrawAddr = flash.autoDraw();
        if (autoDrawAddr == address(0)) {
            CrownZkAutoDraw ad = new CrownZkAutoDraw(address(credit), USDC);
            autoDrawAddr = address(ad);
            flash.setAutoDraw(autoDrawAddr);
        }

        if (!gate.attestor(address(flash))) {
            gate.setAttestor(address(flash), true);
        }
        if (!credit.operator(address(flash))) {
            credit.setOperator(address(flash), true);
        }
        if (!credit.operator(completer)) {
            credit.setOperator(completer, true);
        }
        if (!credit.operator(autoDrawAddr)) {
            credit.setOperator(autoDrawAddr, true);
        }
        if (address(flash.credit()) == address(0)) {
            flash.setCredit(address(credit));
        }

        bool proven;
        uint256 landingDelta;
        if (!skipFlash) {
            IERC20(USDC).approve(address(flash), amount);
            (proven, landingDelta) = flash.fireLive(amount);
        } else {
            proven = gate.isProven(HOT);
        }

        vm.stopBroadcast();

        console2.log("autoDraw", autoDrawAddr);
        console2.log("attestor", gate.attestor(address(flash)));
        console2.log("opFlash", credit.operator(address(flash)));
        console2.log("opCompleter", credit.operator(completer));
        console2.log("opAutoDraw", credit.operator(autoDrawAddr));
        console2.log("flash.credit", address(flash.credit()));
        console2.log("proven", proven);
        console2.log("gate.isProven", gate.isProven(HOT));
        (uint256 thr, uint256 at, bool valid) = gate.attestations(HOT);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
        console2.log("landingDelta", landingDelta);
        console2.log("landingUsdc", IERC20(USDC).balanceOf(LANDING));
        console2.log("hotUsdc", IERC20(USDC).balanceOf(HOT));
    }
}
