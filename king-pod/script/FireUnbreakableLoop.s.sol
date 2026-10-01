// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnbreakableGate} from "../src/CrownUnbreakableGate.sol";
import {CrownLoopScoreboard} from "../src/CrownLoopScoreboard.sol";

interface IExitX {
    function inventory(address) external view returns (uint256);
    function exit(uint256 eusdAmt, address tokenOut, uint256 minOut, bytes32 nfc) external returns (uint256);
}

interface IERC20x {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IStarkX {
    function lastBoundPayload() external view returns (bytes32);
    function lastStarkRoot() external view returns (bytes32);
    function commitStark(bytes32 starkRoot, bytes32 publicInputsHash) external;
    function bindToAttest(bytes32 starkRoot) external returns (bytes32);
}

interface IPqX {
    function activeDilithium() external view returns (bytes32);
}

/// @notice Deploy armor + enforce Gate A/B. No dry-run. Exit only if inventory can clear Gate B.
contract FireUnbreakableLoop is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant LOOP = 0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant PQ = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant STARK = 0x0E88d44F0a6dbD9FF1849DB18278388d74562B07;
    address constant AAVE_SLEEVE = 0x90ae3823d79175daB4095cF1Bf8C6dFB0c34cb47;
    bytes32 constant MARKET =
        0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownUnbreakableGate gate = new CrownUnbreakableGate(
            MORPHO, LOOP, EXIT, YRSS, USDC, EUSD, HOT, MARKET, HOT
        );
        gate.setArmor(PQ, STARK, AAVE_SLEEVE);

        CrownLoopScoreboard board = new CrownLoopScoreboard(
            MORPHO, LOOP, address(gate), YSYNTH, USDC, EUSD, CBBTC, WETH, HOT, MARKET
        );

        // Quantum mempool armor: commit STARK digest for this sequence.
        // Attest bind is NotOwner from Stark bridge — commit alone locks the intent root on-chain.
        bytes32 root = keccak256(abi.encode("UNBREAKABLE", block.timestamp, LOOP, gate.vaultDepth()));
        bytes32 inputs = keccak256(abi.encode("DEPTH", gate.vaultDepth(), gate.utilBps()));
        IStarkX(STARK).commitStark(root, inputs);
        console2.log("starkCommit", uint256(root));

        bool gateA = gate.refreshGateA();
        console2.log("gateA", gateA);
        console2.log("depth", gate.vaultDepth());

        // Gate A → attempt Exit path (contract-enforced).
        if (gateA) {
            uint256 inv = IExitX(EXIT).inventory(USDC);
            console2.log("exitInventoryUsdc", inv);
            if (inv > 500_000e6) {
                uint256 baseline = IERC20x(USDC).balanceOf(HOT);
                uint256 eusdNeed = (inv + 1) * 1e12; // $1 eUSD per 1e6 USDC
                IERC20x(EUSD).approve(EXIT, eusdNeed);
                bytes32 nfc = keccak256(abi.encode("UNBREAKABLE-EXIT", block.timestamp, inv));
                uint256 out = IExitX(EXIT).exit(eusdNeed, USDC, 500_000e6 + 1, nfc);
                console2.log("exitedUsdc", out);
                gate.confirmExit(baseline);
            } else {
                // Gate B inventory lock — Exit USDC inventory cannot clear $500k.
                // Do not call assertCanExit() here (would revert the whole fire).
                console2.log("GateB locked - Exit inventory below $500k (honest)");
                console2.log("assertCanExit will revert Inventory until Exit is funded");
            }
        }

        vm.stopBroadcast();

        (
            uint256 depth,
            uint256 hotUsdc,
            uint256 hotEusd,
            uint256 util,
            uint256 peg,
            uint256 fires,
            uint256 flashed,
            bool a,
            bool b,
            bool killOn
        ) = gate.scoreboard();

        console2.log("CrownUnbreakableGate", address(gate));
        console2.log("CrownLoopScoreboard", address(board));
        console2.log("depth", depth);
        console2.log("hotUsdc", hotUsdc);
        console2.log("hotEusd", hotEusd);
        console2.log("utilBps", util);
        console2.log("pegBps", peg);
        console2.log("fires", fires);
        console2.log("flashed", flashed);
        console2.log("gateA", a);
        console2.log("gateB", b);
        console2.log("paused", killOn);
        console2.log("dilithium", uint256(IPqX(PQ).activeDilithium()));
        console2.log("starkRoot", uint256(IStarkX(STARK).lastStarkRoot()));
    }
}
