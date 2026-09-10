// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownStayIdlePuller} from "../src/CrownStayIdlePuller.sol";
import {CrownYrssLiberator} from "../src/CrownYrssLiberator.sol";

interface IMorphoSI {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy StayIdlePuller + YrssLiberator. No fire.
/// @dev KING_GO=1 forge script script/FireStayIdleShares.s.sol:FireStayIdleDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireStayIdleDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant MARKET_YRSS_PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoSI(MORPHO).idToMarketParams(MARKET_YRSS_PARK);
        require(loan == USDC && coll == RSS, "MARKET");

        vm.startBroadcast(pk);
        CrownStayIdlePuller puller = new CrownStayIdlePuller(MORPHO, USDC, YRSS, HOT, LANDING, HOT);
        puller.setMarketRss(RSS, oracle, irm, lltv, MARKET_YRSS_PARK);
        puller.setMaxUtilBps(9_000);
        puller.setArmed(true);

        CrownYrssLiberator liberator = new CrownYrssLiberator(MORPHO, USDC, YRSS, HOT, LANDING, HOT);
        liberator.setMarketRss(RSS, oracle, irm, lltv, MARKET_YRSS_PARK);
        liberator.setArmed(true);
        vm.stopBroadcast();

        console2.log("CrownStayIdlePuller", address(puller));
        console2.log("CrownYrssLiberator", address(liberator));
        console2.log("idle_now", puller.idle());
        console2.log("maxPull_now", puller.maxPull());
        console2.log("shareClaim", puller.shareClaim());
        console2.log("kingDebt", liberator.kingBorrowAssets());
        console2.log("maxLiberate", liberator.maxLiberate());
    }
}

/// @notice Supply-only stayIdle then optional share pull. Needs USDC on HOT.
/// @dev KING_GO=1 FIRE_STAY=1 STAY_IDLE=0x… AMT=… forge script …:FireStayIdle --broadcast --slow
contract FireStayIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_STAY", uint256(0)) == 1, "NO_FIRE");
        address pullerAddr = vm.envAddress("STAY_IDLE");
        uint256 amt = vm.envOr("AMT", uint256(2_000_000e6));
        bool pull = vm.envOr("PULL_SHARES", uint256(0)) == 1;
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownStayIdlePuller puller = CrownStayIdlePuller(pullerAddr);

        vm.startBroadcast(pk);
        IERC20A(USDC).approve(pullerAddr, amt);
        uint256 supplied = puller.stayIdle(amt);
        console2.log("supplied", supplied);
        console2.log("idle", puller.idle());
        console2.log("utilBps", puller.utilBps());
        console2.log("maxPull", puller.maxPull());

        if (pull) {
            IERC20A(YRSS).approve(pullerAddr, type(uint256).max);
            uint256 pulled = puller.pullSharesToLanding(0);
            console2.log("pulled", pulled);
        }
        vm.stopBroadcast();
    }
}

/// @notice Use shares NOW: repay wedge (optional) + liberate yRSS → Landing.
/// @dev KING_GO=1 FIRE_LIB=1 LIBERATOR=0x… REPAY=… LIBERATE=0 forge script …:FireLiberateShares --broadcast --slow
contract FireLiberateShares is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_LIB", uint256(0)) == 1, "NO_FIRE");
        address libAddr = vm.envAddress("LIBERATOR");
        uint256 repayAmt = vm.envOr("REPAY", uint256(0));
        uint256 liberateAmt = vm.envOr("LIBERATE", uint256(0));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownYrssLiberator liberator = CrownYrssLiberator(libAddr);

        vm.startBroadcast(pk);
        IERC20A(YRSS).approve(libAddr, type(uint256).max);

        if (repayAmt > 0) {
            IERC20A(USDC).approve(libAddr, repayAmt);
            (uint256 idleAfter, uint256 pulled) = liberator.repayAndLiberate(repayAmt, liberateAmt);
            console2.log("idleAfter", idleAfter);
            console2.log("pulled", pulled);
        } else {
            uint256 pulled = liberator.liberateToLanding(liberateAmt);
            console2.log("pulled", pulled);
        }
        console2.log("landing", IERC20A(USDC).balanceOf(0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357));
        console2.log("maxLiberate", liberator.maxLiberate());
        console2.log("idle", liberator.idle());
        vm.stopBroadcast();
    }
}

/// @notice Robot poke: permissionless liberate the instant Morpho idle unlocks shares.
/// @dev KING_GO=1 FIRE_POKE=1 LIBERATOR=0x… forge script …:FirePokeLiberate --broadcast --slow
contract FirePokeLiberate is Script {
    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_POKE", uint256(0)) == 1, "NO_FIRE");
        address libAddr = vm.envAddress("LIBERATOR");
        uint256 pk = vm.envUint("PRIVATE_KEY");

        CrownYrssLiberator liberator = CrownYrssLiberator(libAddr);
        console2.log("idle_before", liberator.idle());
        console2.log("maxLiberate_before", liberator.maxLiberate());

        vm.startBroadcast(pk);
        uint256 pulled = liberator.pokeLiberate();
        vm.stopBroadcast();

        console2.log("pulled", pulled);
    }
}
