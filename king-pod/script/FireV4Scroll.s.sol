// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";
import {CrownZkMesh} from "../src/zk/CrownZkMesh.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IPsmS {
    function seedUsdc(uint256 amt) external;
    function usdcReserve() external view returns (uint256);
    function goldReserveUsd6() external view returns (uint256);
}

/// @notice Scroll leg: gUSD wrap of Scroll eUSD + 8020 vs Gold PSM + mesh wire.
/// KING_GO=1 FIRE_V4_SCROLL=1 SCROLL_PRIVATE_KEY=…
contract FireV4Scroll is Script {
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant PSM = 0x064489A287448674AA1dC6fb740d2F518CBA75dA;
    address constant GOLD_POR = 0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59;
    address constant BOUND = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ELEPAN_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant SETTLE_GATE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    uint64 constant CHAIN_SCROLL = 534352;
    uint64 constant CHAIN_BASE = 8453;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_V4_SCROLL", uint256(0)) == 1, "NEED FIRE");
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");

        vm.startBroadcast(pk);

        CrownGoldUsd gusd = new CrownGoldUsd(EUSD, GOLD_POR, SCROLL_HOT);
        console2.log("gUSD_scroll", address(gusd));
        console2.log("goldBackingUsd", gusd.goldBackingUsd());

        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, address(gusd), PSM, USDC, SCROLL_HOT);
        console2.log("sync8020_scroll", address(sync));
        console2.log("maxRedeemSync", sync.maxRedeemSync(SCROLL_HOT));
        console2.log("psmUsdc", IPsmS(PSM).usdcReserve());
        console2.log("goldReserveUsd6", IPsmS(PSM).goldReserveUsd6());

        // Wrap brand dust
        uint256 wrapAmt = vm.envOr("WRAP_GUSD", uint256(1_000e18));
        uint256 bal = IERC20S(EUSD).balanceOf(SCROLL_HOT);
        if (wrapAmt > bal) wrapAmt = bal;
        if (wrapAmt > 0) {
            IERC20S(EUSD).approve(address(gusd), wrapAmt);
            gusd.wrap(wrapAmt, SCROLL_HOT);
            console2.log("gusdWrapped", wrapAmt);
        }

        CrownZkMesh mesh = new CrownZkMesh(SCROLL_HOT);
        mesh.wire(CHAIN_SCROLL, BOUND, ELEPAN_GATE, SETTLE_GATE);
        mesh.wire(CHAIN_BASE, BOUND, ELEPAN_GATE, SETTLE_GATE);
        console2.log("mesh_scroll", address(mesh));

        vm.stopBroadcast();
        console2.log("V4_SCROLL_OK", uint256(1));
    }
}
