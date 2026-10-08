// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoPar {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IZkPar {
    function isProven(address subject) external view returns (bool);
}

/// @notice Whale Crack Path B: parallel RSS/USDC capacity under CrownOracle.
/// @dev Legacy SOV 0x1293… (77% LLTV) stays seated. Parallel = same tokens/oracle/IRM, LLTV 38.5% (<50%).
///      Gate: FIRE_PARALLEL_CAPACITY=1 · ZK_SHIELD=1 · HOT_KEY
///      King starts HOT → initiateKingTransfer(Safe). Safe accept seals doctrine.
contract FireParallelCapacity is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;

    /// @dev Legacy sovereign book — do not touch.
    bytes32 constant LEGACY_SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    uint256 constant LEGACY_LLTV = 770000000000000000;

    /// @dev Parallel capacity LLTV — under 50%, Morpho-enabled on Base (38.5%).
    uint256 constant PARALLEL_LLTV = 385000000000000000;

    function run() external {
        require(vm.envOr("FIRE_PARALLEL_CAPACITY", uint256(0)) == 1, "FIRE_PARALLEL_CAPACITY");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        require(vm.envOr("TRANSPARENT_OK", uint256(0)) == 0, "TRANSPARENT_FORBIDDEN");

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address zkGate = vm.envOr("ZK_WALLET_GATE", ZK_WALLET_GATE);
        require(IZkPar(zkGate).isProven(HOT), "NOT_PROVEN_HOT");
        require(IZkPar(zkGate).isProven(SAFE), "NOT_PROVEN_SAFE");

        IMorphoPar.MarketParams memory parMp =
            IMorphoPar.MarketParams(USDC, RSS, SOV_ORACLE, IRM, PARALLEL_LLTV);
        bytes32 parId = keccak256(abi.encode(parMp));
        require(parId != LEGACY_SOV, "COLLIDES_LEGACY");
        require(PARALLEL_LLTV != LEGACY_LLTV, "LLTV_NOT_PARALLEL");

        (address loan,,,, uint256 existingLltv) = IMorphoPar(MORPHO).idToMarketParams(parId);
        bool marketExists = loan != address(0);

        vm.startBroadcast(pk);

        if (!marketExists) {
            IMorphoPar(MORPHO).createMarket(parMp);
            console2.log("CREATED_PARALLEL_MARKET", uint256(1));
        } else {
            require(existingLltv == PARALLEL_LLTV, "BAD_EXISTING");
            console2.log("PARALLEL_MARKET_EXISTS", uint256(1));
        }

        (address l, address c, address o, address i, uint256 ll) = IMorphoPar(MORPHO).idToMarketParams(parId);
        require(l == USDC && c == RSS && o == SOV_ORACLE && i == IRM && ll == PARALLEL_LLTV, "PARAMS");

        IMorphoMarket.MarketParams memory gateMp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, PARALLEL_LLTV);
        CrownGateV2 gate = new CrownGateV2(HOT, zkGate, gateMp);
        require(gate.MARKET_ID() == parId, "GATE_ID");

        gate.setOperator(HOT, true);
        gate.initiateKingTransfer(SAFE);

        vm.stopBroadcast();

        (uint128 sup,, uint128 bor,,,) = IMorphoPar(MORPHO).market(parId);
        console2.log("PARALLEL_MARKET_ID");
        console2.logBytes32(parId);
        console2.log("PARALLEL_GATE", address(gate));
        console2.log("PARALLEL_LLTV", PARALLEL_LLTV);
        console2.log("king", gate.king());
        console2.log("pendingKing", gate.pendingKing());
        console2.log("operatorHOT", gate.operator(HOT));
        console2.log("supplyAssets", uint256(sup));
        console2.log("borrowAssets", uint256(bor));
        console2.log("idle", uint256(sup) > uint256(bor) ? uint256(sup) - uint256(bor) : 0);
        console2.log("LEGACY_SOV_UNTOUCHED", uint256(1));
        console2.log("NEXT_SAFE_ACCEPT_KINGSHIP", uint256(1));
    }
}
