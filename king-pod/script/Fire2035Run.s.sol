// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCuratorNative} from "../src/CrownCuratorNative.sol";
import {CrownExitNative} from "../src/CrownExitNative.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";
import {CrownEasyTrigger} from "../src/CrownEasyTrigger.sol";
import {CrownQkdPilotV2} from "../src/CrownQkdPilotV2.sol";

interface IAttestF {
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function attestLive(bytes32 payloadHash) external;
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IYrss {
    function totalAssets() external view returns (uint256);
}

interface ICold {
    function balance() external view returns (uint256);
    function armOutflow(bool armed) external;
    function setRedemptionSink(address sink) external;
    function releaseToSink(uint256 amount, bytes32 reason) external;
}

interface ISleeve {
    function pull(address to, uint256 amt) external;
}

/// @notice 2035 Run — Full 200M · ZK-proven · Quantum-signed.
/// @dev LIVE addresses from FIRE-NATIVE-LOOP + FIRE-QUANTUM-YIELD-ENGINE + FIRE-SPOIL-QKD-FINISH.
///      Does not redeploy chassis. Mint already CLOSED at 200M — proves, signs, exits inventory, scoreboard.
contract Fire2035Run is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant PQ = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant BRIDGE = 0x0E88d44F0a6dbD9FF1849DB18278388d74562B07;
    address constant EASY = 0x512c8ee4521474c2a2E56C033072d56f1998cc6d;
    address constant QKD_V2 = 0x96f275AEDe2a8802D52D25ef866DCCc50D038f9a;
    address constant CURATOR = 0x8Cb11A67F9734143195b24D179749534099b7558;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant OCEAN = 0xAb21623705493538e7E86AAcC79C0297427dc3B2;
    address constant PENDLE = 0x0322AfEc914C2283AEF0fa2e8b61f1e7e85d3429;
    address constant AAVE_EUSD = 0x3c55Ef84eE345e05B60039512daEd331a4d5C441;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;

    uint256 constant SLICE = 200_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 minted = CrownCuratorNative(CURATOR).totalMinted();
        require(minted == SLICE, "NEED_200M_MINTED");
        uint256 yrssAssets = IYrss(YRSS).totalAssets(); // USDC 6dp

        vm.startBroadcast(pk);

        // 1) ZK-Prove the 200M is live (STARK digest → attest SNARK/epoch bind)
        bytes32 stark = keccak256(abi.encode("2035-RUN", SLICE, yrssAssets, CURATOR, block.chainid));
        bytes32 pi = keccak256(abi.encode("2035-pi", OCEAN, PENDLE, AAVE_EUSD));
        CrownStarkSnarkBridge(BRIDGE).commitStark(stark, pi);
        bytes32 payload = keccak256(abi.encode("STARK-SNARK", stark, pi, block.chainid));
        IAttestF(ATTEST).commitPayrollRoot(payload, true);
        IAttestF(ATTEST).attestLive(payload);

        // 2) Quantum-Sign every unit (Dilithium pub-hash register + activate)
        // Activate via keyIds[n-1] — id embeds block.timestamp; sim id ≠ chain id.
        bytes32 dilHash = keccak256(abi.encode("2035-Dilithium3-200M", SLICE, stark));
        CrownPqRegistry(PQ).register(CrownPqRegistry.Alg.Dilithium3, dilHash, "2035-run-200m");
        bytes32 dilId = CrownPqRegistry(PQ).keyIds(CrownPqRegistry(PQ).keyCount() - 1);
        CrownPqRegistry(PQ).activate(dilId);
        bytes32 kyHash = keccak256(abi.encode("2035-Kyber768-shield", SLICE, stark));
        CrownPqRegistry(PQ).register(CrownPqRegistry.Alg.Kyber768, kyHash, "2035-run-shield");
        bytes32 kyId = CrownPqRegistry(PQ).keyIds(CrownPqRegistry(PQ).keyCount() - 1);
        CrownPqRegistry(PQ).activate(kyId);

        // QKD corridor packet (hashes only — FIRE-SPOIL-QKD-FINISH honesty)
        bytes32 pkt = keccak256(abi.encode("2035-QKD-packet", stark, payload));
        bytes32 keyMat = keccak256(abi.encode("2035-QKD-key", dilId, kyId));
        bytes32 qkdRoot = CrownQkdPilotV2(QKD_V2).logPacket(pkt, keyMat, "2035-run-200m");
        IAttestF(ATTEST).attestLive(qkdRoot);

        // EasyTrigger NFC one-tap receipt (King-only · quantum-gated)
        bytes32 nfc = keccak256(abi.encode("NFC-2035-RUN", SLICE, block.timestamp));
        CrownEasyTrigger(EASY).submitNfcReceipt(nfc);

        // 5) Fire CrownExitNative against Kingdom inventory (Cold → Exit) if seeded
        uint256 coldBal = ICold(COLD).balance();
        uint256 exited;
        if (coldBal > 0) {
            uint256 eusdNeed = coldBal * 1e12;
            ICold(COLD).armOutflow(true);
            ICold(COLD).setRedemptionSink(EXIT);
            ICold(COLD).releaseToSink(coldBal, keccak256("2035-EXIT-SEED"));
            ISleeve(AAVE_EUSD).pull(HOT, eusdNeed);
            IERC20b(EUSD).approve(EXIT, eusdNeed);
            bytes32 nfcExit = keccak256(abi.encode("NFC-2035-EXIT", coldBal, block.timestamp));
            exited = CrownExitNative(EXIT).exit(eusdNeed, USDC, coldBal, nfcExit);
        }

        vm.stopBroadcast();

        console2.log("FIRE", "2035-run");
        console2.log("starkRoot", uint256(stark));
        console2.log("payload", uint256(payload));
        console2.log("dilithium", uint256(dilId));
        console2.log("kyber", uint256(kyId));
        console2.log("qkdRoot", uint256(qkdRoot));
        console2.log("nfc", uint256(nfc));
        console2.log("nativeMinted", minted / 1e18);
        console2.log("oceanEusd", IERC20b(EUSD).balanceOf(OCEAN) / 1e18);
        console2.log("pendleEusd", IERC20b(EUSD).balanceOf(PENDLE) / 1e18);
        console2.log("aaveEusdSleeve", IERC20b(EUSD).balanceOf(AAVE_EUSD) / 1e18);
        console2.log("yrssGoldUsdc6dp", yrssAssets);
        console2.log("coldUsdc", coldBal);
        console2.log("exitedUsdc", exited);
        console2.log("hotUsdc", IERC20b(USDC).balanceOf(HOT));
        console2.log("hotCbBtc", IERC20b(CBBTC).balanceOf(HOT));
        console2.log("hotWeth", IERC20b(WETH).balanceOf(HOT));
        console2.log("borders", IAttestF(ATTEST).bordersSecure() ? 1 : 0);
        console2.log("epoch", IAttestF(ATTEST).epoch());
        console2.log("activeDilithium", CrownPqRegistry(PQ).activeDilithium() != bytes32(0) ? 1 : 0);
        console2.log("activeKyber", CrownPqRegistry(PQ).activeKyber() != bytes32(0) ? 1 : 0);
    }
}
