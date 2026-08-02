// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownZkLoanComplete} from "../src/CrownZkLoanComplete.sol";
import {CrownSovereignGate} from "../src/scroll/CrownSovereignGate.sol";
import {CrownSpoilsDominion} from "../src/scroll/CrownSpoilsDominion.sol";

/// @notice KING_GO=1 FIRE_SCROLL_DOMINION=1 — deploy Elepan-native credit on Scroll ONLY.
/// @dev Chain must be Scroll (534352). Never broadcasts to Base. Base position stays intact.
contract FireScrollDominion is Script {
    uint256 constant SCROLL_CHAIN = 534352;
    address constant SCROLL_USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant SCROLL_LANDING = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    /// @dev Base ELE inventory notional @ kingdom $10 ≈ $1B — Scroll credit capacity (6dp)
    uint256 constant CAPACITY_USDC6 = 1_000_000_000e6;
    uint256 constant MIN_THRESHOLD = 700_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SCROLL_DOMINION", uint256(0)) == 1, "NEED FIRE_SCROLL_DOMINION=1");
        require(block.chainid == SCROLL_CHAIN, "NOT_SCROLL");

        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        address deployer = vm.addr(pk);
        require(deployer == SCROLL_HOT, "SCROLL_HOT");

        console2.log("domain", "SCROLL_ELEPAN_DOMINION");
        console2.log("chainid", block.chainid);
        console2.log("deployer", deployer);
        console2.log("landing", SCROLL_LANDING);
        console2.log("usdc", SCROLL_USDC);
        console2.log("BASE_UNTOUCHED", uint256(1));

        vm.startBroadcast(pk);

        CrownSovereignGate gate = new CrownSovereignGate(SCROLL_HOT);
        gate.setMinThreshold(MIN_THRESHOLD);
        gate.attest(SCROLL_HOT, CAPACITY_USDC6);
        console2.log("gate", address(gate));

        CrownZkCredit credit =
            new CrownZkCredit(SCROLL_USDC, address(gate), SCROLL_HOT, SCROLL_LANDING, SCROLL_HOT);
        console2.log("credit", address(credit));

        CrownZkLoanComplete completer = new CrownZkLoanComplete(address(credit), SCROLL_USDC);
        credit.setOperator(address(completer), true);
        console2.log("completer", address(completer));

        CrownElepanUsd eusd = new CrownElepanUsd(SCROLL_HOT);
        console2.log("eusd", address(eusd));

        CrownSpoilsDominion spoils = new CrownSpoilsDominion(SCROLL_HOT, SCROLL_LANDING, SCROLL_HOT);
        spoils.wire(address(gate), address(credit), address(completer), address(eusd));
        spoils.setCapacity(CAPACITY_USDC6);
        console2.log("spoils", address(spoils));

        vm.stopBroadcast();

        require(gate.isProven(SCROLL_HOT), "NOT_PROVEN");
        (uint256 th,, bool ok) = gate.attestations(SCROLL_HOT);
        require(ok && th == CAPACITY_USDC6, "ATT");
        console2.log("capacityUsdc6", th);
        console2.log("maxAsk", completer.maxAsk());
        console2.log("lltv", credit.lltv());
        console2.log("SCROLL_DOMINION_OK", uint256(1));
    }
}
