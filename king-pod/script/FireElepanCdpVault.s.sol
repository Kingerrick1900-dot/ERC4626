// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";

interface IZkGateView {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy King-only Elepan CDP + eUSD wired to live ZK wallet-bind gate.
/// @dev Fixed at launch: LR 150%, safety floor 155%, stability fee 5%/yr.
///      ACCESS CLAUSE: treasury + feeRecipient = Landing (proceeds land immediately).
contract FireElepanCdpVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19; // soft $1
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30; // CrownZkElepanGate

    uint256 constant LR = 1.5e18;
    uint256 constant FLOOR = 1.55e18;
    uint256 constant FEE_BPS = 500;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CDP", uint256(0)) == 1, "NEED FIRE_CDP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateView(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");

        vm.startBroadcast(pk);
        CrownElepanUsd eusd = new CrownElepanUsd(HOT);
        CrownElepanCdpVault vault = new CrownElepanCdpVault(
            ELEPAN, address(eusd), ORACLE, ZK_GATE, HOT, LANDING, LANDING, LR, FLOOR, FEE_BPS
        );
        eusd.setMinter(address(vault), true);
        vm.stopBroadcast();

        console2.log("eUSD", address(eusd));
        console2.log("CDP", address(vault));
        console2.log("zkGate", address(vault.zkGate()));
        console2.log("treasury", vault.treasury());
        console2.log("feeRecipient", vault.feeRecipient());
        console2.log("liquidationRatio", vault.liquidationRatio());
        console2.log("safetyFloor", vault.safetyFloor());
        console2.log("CDP_DEPLOYED", uint256(1));
    }
}
