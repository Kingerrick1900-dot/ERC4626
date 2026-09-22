// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDeedPeel} from "../src/CrownDeedPeel.sol";

interface IMorphoS {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IYrssS {
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

/// @notice Deploy CrownDeedPeel, wire park, approve yRSS, peel dust; unmatch+peel if HOT has USDC.
/// @dev KING_GO=1 forge script script/FireDeedPeel.s.sol:FireDeedPeel --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireDeedPeel is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle,, uint256 lltv) = IMorphoS(MORPHO).idToMarketParams(PARK);
        require(loan == USDC && coll == RSS, "PARK");

        bool doDust = vm.envOr("PEEL_DUST", uint256(1)) == 1;
        bool doUnmatch = vm.envOr("UNMATCH_PEEL", uint256(0)) == 1;
        uint256 repayAmt = vm.envOr("REPAY_AMT", uint256(0));

        vm.startBroadcast(pk);

        CrownDeedPeel peel = new CrownDeedPeel(MORPHO, USDC, YRSS, HOT, LANDING, HOT);
        peel.setMarket(RSS, oracle, IRM, lltv, PARK);
        peel.setArmed(true);

        if (IYrssS(YRSS).allowance(HOT, address(peel)) < type(uint256).max / 2) {
            IYrssS(YRSS).approve(address(peel), type(uint256).max);
        }

        (
            uint256 deed,
            uint256 peelable,
            uint256 parkIdle,
            uint256 kingDebt,
            uint256 util,
            uint256 allow
        ) = peel.board();

        console2.log("CrownDeedPeel", address(peel));
        console2.log("deed", deed);
        console2.log("peelable", peelable);
        console2.log("parkIdle", parkIdle);
        console2.log("kingDebt", kingDebt);
        console2.log("utilBps", util);
        console2.log("yrssAllow", allow);

        if (doDust && peelable > 0) {
            uint256 got = peel.peelDust();
            console2.log("peeled_dust", got);
        }

        uint256 hotUsdc = IERC20S(USDC).balanceOf(HOT);
        if (doUnmatch && hotUsdc > 0) {
            if (repayAmt == 0 || repayAmt > hotUsdc) repayAmt = hotUsdc;
            if (repayAmt > kingDebt) repayAmt = kingDebt;
            if (repayAmt > 0) {
                IERC20S(USDC).approve(address(peel), repayAmt);
                (uint256 idleAfter, uint256 peeled) = peel.unmatchAndPeel(repayAmt, 0);
                console2.log("idleAfter", idleAfter);
                console2.log("peeled", peeled);
            }
        } else if (doUnmatch) {
            console2.log("UNMATCH_SKIP", "HOT USDC=0 - find wedge then UNMATCH_PEEL=1");
        }

        vm.stopBroadcast();
    }
}
