// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16Verifier} from "../src/zk/Groth16Verifier.sol";
import {CrownBoundReservesGate} from "../src/zk/CrownBoundReservesGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownFlashBoundAttest} from "../src/CrownFlashBoundAttest.sol";
import {CrownBoundLandingCompleter} from "../src/CrownBoundLandingCompleter.sol";
import {CrownZkAutoDraw} from "../src/CrownZkAutoDraw.sol";

/// @notice Deploy balanceOf-bound reserves stack wired to Landing.
/// @dev KING_OK=1 FIRE_BOUND_DEPLOY=1
///      Optional REUSE_VERIFIER=0x… (defaults to live Groth16Verifier).
contract FireBoundReservesDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant LIVE_VERIFIER = 0xCC1223C0fCA9efe6c4ea4b35A8b9F08b3f8aF681;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_BOUND_DEPLOY", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address verifier = vm.envOr("REUSE_VERIFIER", LIVE_VERIFIER);

        vm.startBroadcast(pk);

        if (verifier == address(0)) {
            verifier = address(new Groth16Verifier());
        }

        CrownBoundReservesGate gate = new CrownBoundReservesGate(verifier, USDC, HOT);
        CrownZkCredit credit = new CrownZkCredit(USDC, address(gate), HOT, LANDING, HOT);
        CrownFlashBoundAttest flash = new CrownFlashBoundAttest(MORPHO, USDC, address(gate), HOT, HOT);
        CrownBoundLandingCompleter completer = new CrownBoundLandingCompleter(address(credit), USDC);
        CrownZkAutoDraw autoDraw = new CrownZkAutoDraw(address(credit), USDC);

        gate.setAttestor(address(flash), true);
        credit.setOperator(address(flash), true);
        credit.setOperator(address(completer), true);
        credit.setOperator(address(autoDraw), true);
        flash.setCredit(address(credit));
        flash.setAutoDraw(address(autoDraw));

        vm.stopBroadcast();

        console2.log("Groth16Verifier", verifier);
        console2.log("CrownBoundReservesGate", address(gate));
        console2.log("CrownZkCredit", address(credit));
        console2.log("CrownFlashBoundAttest", address(flash));
        console2.log("CrownBoundLandingCompleter", address(completer));
        console2.log("CrownZkAutoDraw", address(autoDraw));
        console2.log("landing", LANDING);
        console2.log("minThreshold", gate.minThreshold());
        console2.log("NEXT: USDC.approve(flash, amount); FIRE_BOUND_FLASH=1 forge script ...FireBoundFlashLive");
    }
}
