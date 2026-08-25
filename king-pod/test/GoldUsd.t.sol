// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract GoldUsdForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BASE_PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant BASE_POR = 0x3640f1CC913B772EA4D9BDF96a67196590058379;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_wrap_unwrap_1to1() public {
        deal(EUSD, HOT, 1_000e18);
        vm.startPrank(HOT);
        CrownGoldUsd gusd = new CrownGoldUsd(EUSD, BASE_POR, HOT);
        IERC20T(EUSD).approve(address(gusd), 1_000e18);
        gusd.wrap(1_000e18, HOT);
        assertEq(gusd.balanceOf(HOT), 1_000e18);
        assertEq(gusd.totalSupply(), 1_000e18);
        assertEq(gusd.eusdFloat(), 1_000e18);
        assertEq(IERC20T(EUSD).balanceOf(HOT), 0);

        gusd.unwrap(400e18, HOT);
        assertEq(gusd.balanceOf(HOT), 600e18);
        assertEq(IERC20T(EUSD).balanceOf(HOT), 400e18);
        vm.stopPrank();
        console2.log("gUSD supply", gusd.totalSupply());
        console2.log("goldBackingUsd", gusd.goldBackingUsd());
    }

    function test_8020_max_tracks_psm_reserve() public {
        CrownGoldUsd gusd = new CrownGoldUsd(EUSD, address(0), HOT);
        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, address(gusd), BASE_PSM, USDC, HOT);
        uint256 maxE = sync.maxRedeemSync(HOT);
        uint256 preview = sync.previewRedeemSync(maxE);
        console2.log("maxRedeem eUSD", maxE);
        console2.log("preview USDC", preview);
        // When PSM empty, max is 0 — honest LiquidityMiss path
        if (maxE == 0) {
            vm.expectRevert(CrownSyncRedeem8020.LiquidityMiss.selector);
            vm.prank(HOT);
            sync.redeemSync(1e18, HOT, HOT);
        }
    }
}
