// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IZkCreditSA {
    function supply(uint256 amt) external;
    function borrowTo(address to, uint256 amt) external;
    function maxBorrow(address user) external view returns (uint256);
    function usdc() external view returns (address);
    function totalSupplyUsdc() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function supplyOf(address) external view returns (uint256);
    function debtOf(address) external view returns (uint256);
}

interface IGateSA {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

interface IERC20SA {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

/// @notice No external buyer: hot supplies USDC into ZK credit, then draws to Landing.
/// @dev KING_GO=1 FIRE_ZK_SELF=1 ASK_USDC=500000000000
///      Hot must hold ASK USDC before fire (King funds hot — hot is the buyer).
contract FireZkSelfAdvance is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant ASK_DEFAULT = 500_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_SELF", uint256(0)) == 1, "NEED FIRE_ZK_SELF=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 ask = vm.envOr("ASK_USDC", ASK_DEFAULT);
        require(IGateSA(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 thr,,) = IGateSA(GATE).attestations(HOT);
        uint256 cap = (thr * 7) / 10; // 70%
        require(ask <= cap, "ASK_GT_CAP");

        uint256 hotBal = IERC20SA(USDC).balanceOf(HOT);
        console2.log("buyer", HOT);
        console2.log("ask", ask);
        console2.log("hotUsdc", hotBal);
        console2.log("threshold", thr);
        console2.log("cap70", cap);
        require(hotBal >= ask, "FUND_HOT_USDC");

        uint256 landBefore = IERC20SA(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        // Hot = buyer/lender
        IERC20SA(USDC).approve(CREDIT, ask);
        IZkCreditSA(CREDIT).supply(ask);
        // King draws against ZK attestation → cold Landing
        IZkCreditSA(CREDIT).borrowTo(LANDING, ask);
        vm.stopBroadcast();

        require(IERC20SA(USDC).balanceOf(LANDING) >= landBefore + ask, "LANDING_MISS");
        console2.log("creditSupplyOfHot", IZkCreditSA(CREDIT).supplyOf(HOT));
        console2.log("creditDebtOfHot", IZkCreditSA(CREDIT).debtOf(HOT));
        console2.log("landingUsdc", IERC20SA(USDC).balanceOf(LANDING));
        console2.log("ZK_SELF_ADVANCE_OK", uint256(1));
    }
}
