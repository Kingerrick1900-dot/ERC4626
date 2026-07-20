// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssOpsDesk} from "../src/CrownRssOpsDesk.sol";

interface IERC20O {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice STEP B — Arm Kingdom Ops Desk for $500k raise (elite OTC venue).
/// @dev Gates: KING_GO=1
///      FIRE_DESK=0 → deploy only
///      FIRE_DESK=1 → stock OPS_RSS + arm live at PRICE (default $1)
///      Default stock: 500_000e18 RSS → $500k USDC at peg if fully filled
contract FireOpsRaise is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doArm = vm.envOr("FIRE_DESK", uint256(0)) == 1;
        address existing = vm.envOr("DESK", address(0));
        address landing = vm.envOr("LANDING", LANDING);
        // Default $500k ops set at $1 peg
        uint256 opsRss = vm.envOr("OPS_RSS", uint256(500_000 ether));
        uint256 price = vm.envOr("PRICE_USDC_PER_RSS", uint256(1e6)); // $1
        bool live = vm.envOr("LIVE", uint256(1)) == 1;

        uint256 rssBal = IERC20O(RSS).balanceOf(HOT);
        console2.log("=== KINGDOM OPS RAISE DESK ===");
        console2.log("rssHot", rssBal);
        console2.log("opsRss", opsRss);
        console2.log("priceUsdcPerRss", price);
        console2.log("targetUsdc", (opsRss * price) / 1e18);
        console2.log("landing", landing);
        console2.log("doArm", doArm ? uint256(1) : uint256(0));

        if (doArm) {
            require(rssBal >= opsRss, "NEED FREE RSS");
            require(opsRss >= 1 ether, "SIZE");
        }

        vm.startBroadcast(pk);

        CrownRssOpsDesk desk;
        if (existing == address(0)) {
            desk = new CrownRssOpsDesk(RSS, USDC, HOT, HOT);
            console2.log("desk", address(desk));
        } else {
            desk = CrownRssOpsDesk(existing);
            console2.log("deskExisting", existing);
        }

        if (doArm) {
            IERC20O(RSS).approve(address(desk), opsRss);
            desk.stock(opsRss);
            desk.arm(landing, price, live);
        }

        vm.stopBroadcast();

        console2.log("rssForSale", desk.rssForSale());
        console2.log("live", desk.live() ? uint256(1) : uint256(0));
        console2.log("quote500kRss", desk.quoteUsdc(500_000 ether));
        console2.log("READY", doArm ? uint256(1) : uint256(0));
    }
}
