// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPermissionlessWethSeed} from "../src/CrownPermissionlessWethSeed.sol";
import {CrownWethIdleRaid} from "../src/CrownWethIdleRaid.sol";
import {CrownRssWethDesk} from "../src/CrownRssWethDesk.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Engineer 351 WETH then raid WETH/USDC idle → Landing.
/// Env:
///   FIRE=1           broadcast
///   ESCROW_RSS=...   deposit RSS into open WETH seed (default 5M)
///   RAID=1           after WETH on hot, borrow USDC to Landing
///   WETH_IN / USDC_OUT for raid (default 360 ether / 700_000e6)
///   SEED / RAID_MACHINE / DESK reuse addresses
contract FireWethEngineerRaid is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE_RSS = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        bool doRaid = vm.envOr("RAID", false);
        uint256 escrowRss = vm.envOr("ESCROW_RSS", uint256(5_000_000 ether));
        uint256 wethIn = vm.envOr("WETH_IN", uint256(360 ether));
        uint256 usdcOut = vm.envOr("USDC_OUT", uint256(700_000e6));
        uint256 sweet = vm.envOr("SWEETENER_BPS", uint256(2_000)); // +20%

        console2.log("hot WETH", IERC20F(WETH).balanceOf(HOT));
        console2.log("hot RSS", IERC20F(RSS).balanceOf(HOT));
        console2.log("Landing USDC", IERC20F(USDC).balanceOf(LANDING));

        vm.startBroadcast();

        CrownWethIdleRaid raid = CrownWethIdleRaid(payable(vm.envOr("RAID_MACHINE", address(0))));
        if (address(raid) == address(0)) {
            raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID);
            IMorphoAuth(MORPHO).setAuthorization(address(raid), true);
            console2.log("raid", address(raid));
        }

        CrownPermissionlessWethSeed seed = CrownPermissionlessWethSeed(vm.envOr("SEED", address(0)));
        if (address(seed) == address(0)) {
            // WETH sink = HOT so king can raid with transferFrom
            seed = new CrownPermissionlessWethSeed(
                RSS, WETH, ORACLE_RSS, ORACLE_WETH, HOT, HOT, sweet
            );
            console2.log("wethSeed", address(seed));
        }

        CrownRssWethDesk desk = CrownRssWethDesk(vm.envOr("DESK", address(0)));
        if (address(desk) == address(0)) {
            desk = new CrownRssWethDesk(RSS, WETH, ORACLE_RSS, ORACLE_WETH, HOT, 0.75e18);
            console2.log("wethDesk", address(desk));
        }

        if (fire && escrowRss > 0) {
            IERC20F(RSS).approve(address(seed), escrowRss);
            seed.depositRss(escrowRss);
            console2.log("escrowed RSS", escrowRss);
            console2.log("quote 360 WETH -> RSS", seed.quoteRssOut(360 ether));
        }

        if (fire && doRaid) {
            uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
            require(IERC20F(WETH).balanceOf(HOT) >= wethIn, "NO_WETH_EQUITY");
            IERC20F(WETH).approve(address(raid), wethIn);
            raid.raid(wethIn, usdcOut);
            uint256 delta = IERC20F(USDC).balanceOf(LANDING) - landBefore;
            console2.log("Landing delta", delta);
            require(delta >= usdcOut, "LANDING_DID_NOT_HIT");
        }

        vm.stopBroadcast();

        console2.log("--- filler ---");
        console2.log("weth.approve(seed, amt); seed.fill(amt); // WETH to hot, RSS to filler");
        console2.log("--- lender ---");
        console2.log("weth.approve(desk, amt); desk.fund(amt); // then king draw then raid");
    }
}
