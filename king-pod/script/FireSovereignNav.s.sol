// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignBoard} from "../src/CrownSovereignBoard.sol";

interface IZkAttest {
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function attestLive(bytes32 payrollRoot) external returns (uint256);
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
}

/// @notice Fire three-rail sovereign NAV board + wire root into live ZkAttest.
contract FireSovereignNav is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant OCEAN = 0x8C009d9654247Bc2B68DE98b3083B27aF8f2eFE7;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        CrownSovereignBoard board = new CrownSovereignBoard(
            YRSS, EUSD, GUSD, LANDING, OCEAN, COLD, ATTEST, HOT
        );
        bytes32 root = board.publish();

        IZkAttest zk = IZkAttest(ATTEST);
        zk.commitPayrollRoot(root, true);
        uint256 epochId = zk.attestLive(root);
        board.recordWire(epochId);

        vm.stopBroadcast();

        console2.log("CrownSovereignBoard", address(board));
        console2.log("epoch", epochId);
        console2.log("borders", zk.bordersSecure());
        console2.logBytes32(root);
    }

    /// @notice Gas-light path: no CREATE — bind off-chain computed root into live ZkAttest only.
    function runWireOnly(bytes32 root) external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);
        IZkAttest zk = IZkAttest(ATTEST);
        zk.commitPayrollRoot(root, true);
        uint256 epochId = zk.attestLive(root);
        vm.stopBroadcast();
        console2.log("epoch", epochId);
        console2.log("borders", zk.bordersSecure());
        console2.logBytes32(root);
    }
}
