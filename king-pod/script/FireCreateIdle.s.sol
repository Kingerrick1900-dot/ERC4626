// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCreateIdle} from "../src/CrownCreateIdle.sol";

interface IMorphoCI {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice Deploy CrownCreateIdle for $2M Morpho direct idle fill. No fire.
/// @dev KING_GO=1 forge script script/FireCreateIdle.s.sol:FireCreateIdleDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireCreateIdleDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    /// @dev Market where yRSS parked the ~$1M (helper 62960be8 book).
    bytes32 constant MARKET_YRSS_PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant ASK = 2_000_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoCI(MORPHO).idToMarketParams(MARKET_YRSS_PARK);
        require(loan == USDC && coll == RSS, "MARKET");

        vm.startBroadcast(pk);
        CrownCreateIdle fill = new CrownCreateIdle(MORPHO, USDC, YRSS, HOT, LANDING, HOT);
        fill.setMarketRss(RSS, oracle, irm, lltv, MARKET_YRSS_PARK);
        fill.setArmed(true);
        vm.stopBroadcast();

        console2.log("CrownCreateIdle", address(fill));
        console2.log("ASK_USDC", ASK);
        console2.logBytes32(MARKET_YRSS_PARK);
        console2.log("oracle", oracle);
        console2.log("idle_now", fill.idle());
        console2.log("maxPull_now", fill.maxPull());
    }
}

/// @notice Fire createIdle then optional pull100. Needs USDC on HOT + yRSS approve.
/// @dev KING_GO=1 FIRE_IDLE=1 CREATE_IDLE=0x… AMT=2000000000000 forge script …:FireCreateIdle2M --broadcast --slow
contract FireCreateIdle2M is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_IDLE", uint256(0)) == 1, "NO_FIRE");
        address fillAddr = vm.envAddress("CREATE_IDLE");
        uint256 amt = vm.envOr("AMT", uint256(2_000_000e6));
        bool pull = vm.envOr("PULL100", uint256(0)) == 1;
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownCreateIdle fill = CrownCreateIdle(fillAddr);

        vm.startBroadcast(pk);
        IERC20A(USDC).approve(fillAddr, amt);
        uint256 supplied = fill.createIdle(amt);
        console2.log("supplied", supplied);
        console2.log("idle", fill.idle());
        console2.log("maxPull", fill.maxPull());

        if (pull) {
            IERC20A(YRSS).approve(fillAddr, type(uint256).max);
            uint256 pulled = fill.pull100ToLanding(0);
            console2.log("pulled", pulled);
        }
        vm.stopBroadcast();
    }
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
}
