// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBossWedge} from "../src/CrownBossWedge.sol";

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

/// @dev KING_GO=1 forge script script/FireBossWedge.s.sol:FireBossWedge --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireBossWedge is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant BOSS = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address l0, address c0, address o0,, uint256 lltv0) = IMorphoS(MORPHO).idToMarketParams(BOSS);
        (address l1, address c1, address o1,, uint256 lltv1) = IMorphoS(MORPHO).idToMarketParams(PARK);
        require(l0 == USDC && c0 == EUSD, "BOSS");
        require(l1 == USDC && c1 == RSS, "PARK");

        vm.startBroadcast(pk);

        CrownBossWedge w = new CrownBossWedge(MORPHO, USDC, EUSD, YRSS, HOT, LANDING, HOT);
        w.setMarkets(RSS, o0, o1, IRM, lltv0, lltv1, BOSS, PARK);
        w.setArmed(true);

        if (IERC20S(YRSS).allowance(HOT, address(w)) < type(uint256).max / 2) {
            IERC20S(YRSS).approve(address(w), type(uint256).max);
        }

        uint256 idle = w.bossIdle();
        console2.log("CrownBossWedge", address(w));
        console2.log("bossIdle", idle);

        if (idle > 0) {
            // approve eUSD for wedge
            IERC20S(EUSD).approve(address(w), type(uint256).max);
            (uint256 borrowed, uint256 peeled) = w.drainWedge(0);
            console2.log("borrowed", borrowed);
            console2.log("peeled", peeled);
            console2.log("landingUsdc", IERC20S(USDC).balanceOf(LANDING));
        } else {
            console2.log("VACUUM_ARMED", "boss idle 0 - call drainWedge when refill");
        }

        vm.stopBroadcast();
    }
}
