// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IGate {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

interface IComplete {
    function maxAsk() external view returns (uint256);
    function credit() external view returns (address);
    function landing() external view returns (address);
}

interface ICredit {
    function maxBorrow(address) external view returns (uint256);
    function operator(address) external view returns (bool);
    function lltv() external view returns (uint256);
}

interface IVault {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IMorpho {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice KING_GO=1 FIRE_PROOF_STATUS=1 — proof + share force board (no broadcast needed).
contract FireProofForceStatus is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant COMPLETE = 0x12514e1f999131eA78D402a7258b67A65F9342Ff;
    address constant AUTODRAW = 0xE7e7008D71387a79Bf57F1E5Ab75534d4b3DA34A;
    address constant YELEK = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_PROOF_STATUS", uint256(0)) == 1, "NEED FIRE_PROOF_STATUS=1");

        (uint256 att,,) = IGate(GATE).attestations(HOT);
        console2.log("PROVEN", IGate(GATE).isProven(HOT) ? uint256(1) : uint256(0));
        console2.log("ATTEST_USDC", att);
        console2.log("MIN_THRESHOLD", IGate(GATE).minThreshold());
        console2.log("MAX_ASK", IComplete(COMPLETE).maxAsk());
        console2.log("CREDIT_MAX_BORROW", ICredit(CREDIT).maxBorrow(HOT));
        console2.log("OP_COMPLETE", ICredit(CREDIT).operator(COMPLETE) ? uint256(1) : uint256(0));
        console2.log("OP_AUTODRAW", ICredit(CREDIT).operator(AUTODRAW) ? uint256(1) : uint256(0));
        console2.log("HOT_USDC", IERC20(USDC).balanceOf(HOT));
        console2.log("YELEK_ASSETS", IVault(YELEK).convertToAssets(IVault(YELEK).balanceOf(HOT)));
        console2.log("YELEK_MAX_WITHDRAW", IVault(YELEK).maxWithdraw(HOT));

        (uint256 tenSup, uint128 tenBor,) = IMorpho(MORPHO).position(TEN, HOT);
        (uint128 tsa,, uint128 tba,,,) = IMorpho(MORPHO).market(TEN);
        console2.log("TEN_SUP_SHARES", tenSup);
        console2.log("TEN_BOR_SHARES", uint256(tenBor));
        console2.log("TEN_IDLE", uint256(tsa) > uint256(tba) ? uint256(tsa) - uint256(tba) : 0);

        (uint256 eSup, uint128 eBor,) = IMorpho(MORPHO).position(ELE77, HOT);
        (uint128 esa,, uint128 eba,,,) = IMorpho(MORPHO).market(ELE77);
        console2.log("ELE77_SUP_SHARES", eSup);
        console2.log("ELE77_BOR_SHARES", uint256(eBor));
        console2.log("ELE77_IDLE", uint256(esa) > uint256(eba) ? uint256(esa) - uint256(eba) : 0);

        console2.log("PROOF_FORCE_STATUS_OK", uint256(1));
    }
}
