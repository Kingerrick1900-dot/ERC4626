// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";
import {CrownEasyTrigger} from "../src/CrownEasyTrigger.sol";
import {CrownQkdPilot} from "../src/CrownQkdPilot.sol";
import {CrownAmericaCapacity} from "../src/CrownAmericaCapacity.sol";

interface IAllowlistF {
    function setAllowed(address target, bytes4 selector, bool ok) external;
    function setAllowedBatch(address[] calldata targets, bytes4[] calldata selectors, bool ok) external;
    function owner() external view returns (address);
}

/// @notice Fire Quantum Yield Engine software layer: STARK-SNARK · PQ registry · Easy Trigger · QKD · 100T capacity.
contract FireQuantumYieldEngine is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant TRANCHE = 0x8531F4DB622b982541A6715164d5A9dde58205b0;
    uint256 constant CAP_100T = 100_000_000_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownStarkSnarkBridge bridge = new CrownStarkSnarkBridge(ATTEST, HOT);
        CrownPqRegistry pq = new CrownPqRegistry(HOT);
        CrownAmericaCapacity cap = new CrownAmericaCapacity(EUSD, HOT, CAP_100T);
        cap.setAttest(ATTEST);
        CrownEasyTrigger easy = new CrownEasyTrigger(HOT, HOT);
        easy.wire(ALLOWLIST, ATTEST, address(cap), TRANCHE);
        // Easy Trigger: NFC required, but King can submit receipt then tap deploy
        CrownQkdPilot qkd = new CrownQkdPilot(ATTEST, HOT);

        if (IAllowlistF(ALLOWLIST).owner() == HOT) {
            address[] memory t = new address[](8);
            bytes4[] memory s = new bytes4[](8);
            t[0] = address(bridge);
            s[0] = CrownStarkSnarkBridge.commitStark.selector;
            t[1] = address(bridge);
            s[1] = CrownStarkSnarkBridge.bindToAttest.selector;
            t[2] = address(easy);
            s[2] = CrownEasyTrigger.easyDeploy.selector;
            t[3] = address(easy);
            s[3] = CrownEasyTrigger.submitNfcReceipt.selector;
            t[4] = address(qkd);
            s[4] = CrownQkdPilot.markT0.selector;
            t[5] = address(qkd);
            s[5] = CrownQkdPilot.logPacket.selector;
            t[6] = address(cap);
            s[6] = CrownAmericaCapacity.unlockTranche.selector;
            t[7] = address(pq);
            s[7] = CrownPqRegistry.register.selector;
            IAllowlistF(ALLOWLIST).setAllowedBatch(t, s, true);
        }

        vm.stopBroadcast();

        console2.log("CrownStarkSnarkBridge", address(bridge));
        console2.log("CrownPqRegistry", address(pq));
        console2.log("CrownEasyTrigger", address(easy));
        console2.log("CrownQkdPilot", address(qkd));
        console2.log("CrownAmericaCapacity", address(cap));
        console2.log("mintCapacity", cap.mintCapacity());
        console2.log("unlocked", cap.unlockedCapacity());
        console2.log("trancheWired", TRANCHE);
    }
}
