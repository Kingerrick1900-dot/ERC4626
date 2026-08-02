// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IZkCredit {
    function borrowTo(address to, uint256 amt) external;
    function borrowMaxToLanding() external returns (uint256);
    function maxBorrow(address user) external view returns (uint256);
    function totalSupplyUsdc() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function landing() external view returns (address);
    function usdc() external view returns (address);
}

interface IGate {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

interface IERC20Z {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Draw USDC from ZK credit rail → Landing. KING_GO=1 FIRE_ZK_CREDIT=1
/// @dev Pool must be funded (supply). Ask default $500k; cap = attested threshold × 70%.
contract FireZkCreditDraw is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    uint256 constant ASK_DEFAULT = 500_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_CREDIT", uint256(0)) == 1, "NEED FIRE_ZK_CREDIT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 ask = vm.envOr("ASK_USDC", ASK_DEFAULT);
        IZkCredit credit = IZkCredit(CREDIT);
        require(IGate(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 thr,, bool valid) = IGate(GATE).attestations(HOT);
        require(valid, "ATT_INVALID");
        uint256 cap = (thr * 70) / 100; // display; on-chain uses 0.7e18
        uint256 maxB = credit.maxBorrow(HOT);
        uint256 pool = IERC20Z(credit.usdc()).balanceOf(CREDIT);

        console2.log("threshold", thr);
        console2.log("cap70", (thr * 7) / 10);
        console2.log("poolUsdc", pool);
        console2.log("maxBorrow", maxB);
        console2.log("ask", ask);
        require(ask <= (thr * 7) / 10, "ASK_GT_CAP");
        require(pool >= ask, "POOL_UNFUNDED");
        require(maxB >= ask, "MAX_BORROW");

        uint256 landBefore = IERC20Z(credit.usdc()).balanceOf(LANDING);
        vm.startBroadcast(pk);
        credit.borrowTo(LANDING, ask);
        vm.stopBroadcast();
        require(IERC20Z(credit.usdc()).balanceOf(LANDING) >= landBefore + ask, "LANDING_MISS");
        console2.log("landingUsdc", IERC20Z(credit.usdc()).balanceOf(LANDING));
        console2.log("ZK_CREDIT_DRAW_OK", uint256(1));
    }
}
