// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSpoilFireExec} from "../src/CrownSpoilFireExec.sol";
import {CrownQkdPilotV2} from "../src/CrownQkdPilotV2.sol";

interface IHunt {
    function setHunter(address h, bool ok) external;
    function killSwitch() external view returns (bool);
    function setKillSwitch(bool on) external;
    function hunter(address) external view returns (bool);
}

interface IAttest {
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function attestLive(bytes32 payrollRoot) external returns (uint256);
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
}

interface IPq {
    enum Alg {
        Dilithium3,
        Kyber768
    }

    function register(Alg alg, bytes32 keyHash, string calldata label) external returns (bytes32 id);
    function activate(bytes32 id) external;
    function activeKyber() external view returns (bytes32);
    function activeDilithium() external view returns (bytes32);
}

interface IQkdV1 {
    function markT0(uint64 ts) external;
    function recordLoi(string calldata ref) external;
    function openPilot() external;
    function t0() external view returns (uint64);
    function pilotAt() external view returns (uint64);
}

/// @notice SpoilFireExec fire() + QKD V1 timeline + V2 packet + PqRegistry Kyber bind + attest.
contract FireSpoilAndQkd is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant HUNT = 0xc4c63f8CD4182452f665e338F87b4d31aeF04516;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant QKD_V1 = 0xC19c7fe9aC7D65476BBd91BD275443761FFe430F;
    address constant PQ = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        // --- Part 1: SpoilFire execution trigger ---
        CrownSpoilFireExec spoil = new CrownSpoilFireExec(HUNT, HOT, USDC, WETH, CBBTC, HOT);
        if (IHunt(HUNT).killSwitch()) IHunt(HUNT).setKillSwitch(false);
        IHunt(HUNT).setHunter(address(spoil), true);
        spoil.fire();

        // --- Part 2: QKD physical-layer registry (hashes only) ---
        if (IQkdV1(QKD_V1).t0() == 0) IQkdV1(QKD_V1).markT0(0);
        IQkdV1(QKD_V1).recordLoi("LOI-Conflux-CN-telco-Shenzhen-Shanghai");
        if (IQkdV1(QKD_V1).pilotAt() == 0) IQkdV1(QKD_V1).openPilot();

        CrownQkdPilotV2 qkd2 = new CrownQkdPilotV2(QKD_V1, HOT);
        qkd2.markT0(0);
        qkd2.recordLoi("LOI-Conflux-CN-telco-Shenzhen-Shanghai");
        qkd2.openPilot();
        bytes32 keyMat = keccak256(abi.encodePacked("QKD-SZ-SHA", block.chainid, block.timestamp, HOT));
        bytes32 packet = keccak256(abi.encodePacked("PKT1", keyMat));
        bytes32 root = qkd2.logPacket(packet, keyMat, "pilot-1 Shenzhen-Shanghai fiber corridor");

        IAttest(ATTEST).commitPayrollRoot(root, true);
        uint256 ep = IAttest(ATTEST).attestLive(root);

        bytes32 qkdId = IPq(PQ).register(IPq.Alg.Kyber768, keyMat, "QKD-SZ-SHA-pilot-1");
        IPq(PQ).activate(qkdId);

        vm.stopBroadcast();

        console2.log("SpoilFireExec", address(spoil));
        console2.log("QkdPilotV2", address(qkd2));
        console2.log("spoilHunter", IHunt(HUNT).hunter(address(spoil)) ? uint256(1) : 0);
        console2.log("borders", IAttest(ATTEST).bordersSecure() ? uint256(1) : 0);
        console2.log("epoch", ep);
        console2.log("activeKyber");
        console2.logBytes32(IPq(PQ).activeKyber());
        console2.log("activeDilithium");
        console2.logBytes32(IPq(PQ).activeDilithium());
    }
}
