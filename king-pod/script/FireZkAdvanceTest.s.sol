// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IZkAdv {
    function advance(uint256 usdcAmt) external;
    function quote() external view returns (bool kingProven, uint256 kusdAvailable, uint256 threshold);
    function raisedUsdc() external view returns (uint256);
}

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice ZK gate advance test — REQUIRES KING_GO=1 and buyer USDC.
/// @dev KING_OK=1 KING_GO=1 FIRE_ZK_TEST=1 ADVANCE_USDC=500000e6
///      Buyer must hold USDC (counterparty or funded hot). Reverts if !isProven(king).
contract FireZkAdvanceTest is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
        require(vm.envOr("FIRE_ZK_TEST", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        // Buyer key: default hot; set BUYER_KEY for counterparty
        if (vm.envOr("BUYER_KEY", uint256(0)) != 0) {
            pk = vm.envUint("BUYER_KEY");
        }
        address buyer = vm.addr(pk);

        uint256 amt = vm.envOr("ADVANCE_USDC", uint256(500_000e6));
        (bool proven, uint256 avail, uint256 thr) = IZkAdv(ADV).quote();
        uint256 buyerUsdc = IERC20A(USDC).balanceOf(buyer);
        uint256 coldBefore = IERC20A(USDC).balanceOf(COLD);

        console2.log("buyer", buyer);
        console2.log("zkProven", proven);
        console2.log("kusdAvail", avail);
        console2.log("threshold", thr);
        console2.log("advanceAmt", amt);
        console2.log("buyerUsdc", buyerUsdc);
        console2.log("coldBefore", coldBefore);

        require(proven, "KING_NOT_PROVEN");
        require(amt >= 500_000e6, "SIZE_BELOW_500K");
        require(amt <= avail, "KUSD_STOCK");
        require(buyerUsdc >= amt, "BUYER_USDC_SHORT");

        vm.startBroadcast(pk);
        IERC20A(USDC).approve(ADV, amt);
        IZkAdv(ADV).advance(amt);
        vm.stopBroadcast();

        uint256 coldAfter = IERC20A(USDC).balanceOf(COLD);
        console2.log("coldAfter", coldAfter);
        console2.log("coldGain", coldAfter - coldBefore);
        console2.log("raisedUsdc", IZkAdv(ADV).raisedUsdc());
        console2.log("ZK_ADVANCE_TEST_OK", uint256(1));
    }
}
