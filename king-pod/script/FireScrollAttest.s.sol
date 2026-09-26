// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownNavMirror} from "../src/CrownNavMirror.sol";
import {CrownZkAttest} from "../src/CrownZkAttest.sol";
import {CrownRailShield} from "../src/CrownRailShield.sol";

/// @notice Scroll privacy rail — ZK NAV attest mirror of Base yRSS.
/// @dev Requires Scroll L2 ETH spark. FIRE=1 to broadcast.
contract FireScrollAttest is Script {
    bytes32 constant BASE_YRSS =
        bytes32(uint256(uint160(0xF80C0529bD94C773844E459853CD91B9263dD525)));
    uint256 constant NAV_T = 228_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address vault = vm.addr(pk);
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;
        console2.log("vault", vault);
        console2.log("eth", vault.balance);

        vm.startBroadcast(pk);
        CrownNavMirror nav = new CrownNavMirror(vault, 228_900_000e6, BASE_YRSS);
        CrownZkAttest attest = new CrownZkAttest(address(nav), vault, NAV_T, 8e6, address(0), address(0));
        CrownRailShield shield = new CrownRailShield(vault);
        shield.setRail(CrownRailShield.Rail.Attest, address(attest));
        shield.setRail(CrownRailShield.Rail.OpsGas, vault);
        if (doFire) {
            bytes32 root = keccak256(abi.encode("SCROLL-ZK", block.chainid, block.timestamp));
            attest.commitPayrollRoot(root, true);
            attest.attestLive(root);
        }
        vm.stopBroadcast();

        console2.log("navMirror", address(nav));
        console2.log("attest", address(attest));
        console2.log("shield", address(shield));
        console2.log("borders", attest.bordersSecure() ? uint256(1) : uint256(0));
    }
}
