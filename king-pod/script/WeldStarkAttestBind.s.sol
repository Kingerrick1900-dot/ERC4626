// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkAttest} from "../src/CrownZkAttest.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";
import {CrownUnbreakableGate} from "../src/CrownUnbreakableGate.sol";
import {CrownLoopScoreboard} from "../src/CrownLoopScoreboard.sol";

/// @notice Weld Stark↔Attest with ATTESTER_ROLE, verify bind, then deploy gates.
/// @dev Doctrine: no armor / no gate fire without quantum bind. No shortcuts.
contract WeldStarkAttestBind is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant SETTLE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    address constant ELEPAN = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant LOOP = 0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant PQ = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant AAVE_SLEEVE = 0x90ae3823d79175daB4095cF1Bf8C6dFB0c34cb47;
    bytes32 constant MARKET =
        0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;

    // Mirror live Attest config (pre-weld 0xe3Be…)
    uint256 constant NAV_THRESHOLD = 220_000_000e6;
    uint256 constant REDEEMABLE_WINDOW = 604_800;
    uint256 constant MAX_STALE = 8_000_000;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        // --- Step 1: Deploy Attest with roles + Stark bridge ---
        CrownZkAttest attest = new CrownZkAttest(YRSS, HOT, NAV_THRESHOLD, REDEEMABLE_WINDOW, SETTLE, ELEPAN);
        attest.setCold(COLD);
        attest.setThresholds(NAV_THRESHOLD, REDEEMABLE_WINDOW, MAX_STALE);

        CrownStarkSnarkBridge stark = new CrownStarkSnarkBridge(address(attest), HOT);

        // Grant ATTESTER_ROLE to StarkSnarkBridge — weld permission
        attest.grantRole(attest.ATTESTER_ROLE(), address(stark));
        require(attest.hasRole(attest.ATTESTER_ROLE(), address(stark)), "ROLE_NOT_GRANTED");

        // --- Step 2: Commit + bind ---
        bytes32 root = keccak256(abi.encode("WELD-UNBREAKABLE", block.timestamp, LOOP, MARKET));
        bytes32 inputs = keccak256(abi.encode("WELD-PI", NAV_THRESHOLD, address(attest), address(stark)));
        stark.commitStark(root, inputs);
        bytes32 payload = stark.bindToAttest(root);

        // --- Step 3: Verify bind (hard require — no scaffold) ---
        uint256 ep = attest.latestEpoch();
        bytes32 proof = attest.latestProof();
        bool bound = stark.isBound();
        require(ep > 0, "EPOCH_NOT_INCREMENTED");
        require(proof != bytes32(0), "PROOF_EMPTY");
        require(bound, "NOT_BOUND");
        require(stark.lastBoundPayload() == payload, "PAYLOAD_MISMATCH");
        require(attest.payrollRoots(payload), "PAYROLL_NOT_OK");
        require(attest.bordersSecure(), "BORDERS_NOT_SECURE");

        // --- Step 4: Deploy gates ONLY after bind passes ---
        CrownUnbreakableGate gate = new CrownUnbreakableGate(
            MORPHO, LOOP, EXIT, YRSS, USDC, EUSD, HOT, MARKET, HOT
        );
        gate.setArmor(PQ, address(stark), AAVE_SLEEVE);
        require(gate.armorBound(), "GATE_ARMOR_NOT_BOUND");

        bool gateA = gate.refreshGateA();

        CrownLoopScoreboard board = new CrownLoopScoreboard(
            MORPHO, LOOP, address(gate), YSYNTH, USDC, EUSD, CBBTC, WETH, HOT, MARKET
        );

        vm.stopBroadcast();

        console2.log("CrownZkAttest", address(attest));
        console2.log("CrownStarkSnarkBridge", address(stark));
        console2.log("latestEpoch", ep);
        console2.log("latestProof", uint256(proof));
        console2.log("isBound", bound);
        console2.log("boundPayload", uint256(payload));
        console2.log("CrownUnbreakableGate", address(gate));
        console2.log("CrownLoopScoreboard", address(board));
        console2.log("gateA", gateA);
        console2.log("depth", gate.vaultDepth());
        console2.log("gateB", gate.gateBPassed());
        console2.log("armorBound", gate.armorBound());
    }
}
