// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IZkCredit {
    function borrow(uint256 amt) external;
    function maxBorrow(address user) external view returns (uint256);
    function isProven(address) external view returns (bool);
}

interface IGate {
    function isProven(address) external view returns (bool);
}

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Phases 5–8: borrow from CrownZkCredit → confirm hot → transfer to cold → confirm cold.
/// @dev KING_OK=1 FIRE_ZK_BORROW=1
///      BORROW_AMT default 700_000e6 — reverts if credit has no USDC liquidity.
contract FireZkBorrowToCold is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357; // Landing
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205;
    address constant CREDIT = 0xeAE626b6e82E51c9805D72B6532A948dcf57D392;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_BORROW", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 want = vm.envOr("BORROW_AMT", uint256(700_000e6));
        bool proven = IGate(GATE).isProven(HOT);
        uint256 maxB = IZkCredit(CREDIT).maxBorrow(HOT);
        uint256 creditBal = IERC20U(USDC).balanceOf(CREDIT);
        uint256 hotBefore = IERC20U(USDC).balanceOf(HOT);
        uint256 coldBefore = IERC20U(USDC).balanceOf(COLD);

        console2.log("PHASE4_isProven", proven);
        console2.log("creditUsdc", creditBal);
        console2.log("maxBorrow", maxB);
        console2.log("hotUsdcBefore", hotBefore);
        console2.log("coldUsdcBefore", coldBefore);
        console2.log("borrowWant", want);

        require(proven, "NOT_PROVEN");
        require(maxB > 0, "NO_CREDIT_LIQUIDITY");
        uint256 amt = want > maxB ? maxB : want;

        vm.startBroadcast(pk);
        // PHASE 5
        IZkCredit(CREDIT).borrow(amt);
        uint256 hotAfterBorrow = IERC20U(USDC).balanceOf(HOT);
        console2.log("PHASE5_borrowed", amt);
        console2.log("PHASE6_hotUsdc", hotAfterBorrow);

        // PHASE 7 — send borrowed USDC to cold (keep nothing from this draw)
        uint256 send = hotAfterBorrow > hotBefore ? (hotAfterBorrow - hotBefore) : 0;
        if (send > 0) {
            IERC20U(USDC).transfer(COLD, send);
        }
        vm.stopBroadcast();

        uint256 coldAfter = IERC20U(USDC).balanceOf(COLD);
        console2.log("PHASE7_sentToCold", send);
        console2.log("PHASE8_coldUsdc", coldAfter);
        console2.log("PHASE8_coldGain", coldAfter - coldBefore);
        console2.log("PHASE9_REPORT_COMPLETE", uint256(1));
    }
}
