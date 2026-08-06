// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssUsdcDesk} from "../src/CrownRssUsdcDesk.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Track 1 fork: lender USDC + free RSS → 700k USDC on Landing.
contract RssUsdcDesk700kFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;

    function test_landing_receives_700k_usdc() public {
        uint256 usdcOut = 700_000e6;
        uint256 rssIn = 1_000e18; // buffer above 778 @ 75% / $1200
        address lender = address(0xBEEF);

        deal(USDC, lender, usdcOut);
        require(IERC20T(RSS).balanceOf(HOT) >= rssIn, "RSS");

        vm.prank(HOT);
        CrownRssUsdcDesk desk = new CrownRssUsdcDesk(RSS, USDC, ORACLE, HOT, LANDING, 0.75e18);

        vm.startPrank(lender);
        IERC20T(USDC).approve(address(desk), usdcOut);
        desk.fund(usdcOut);
        vm.stopPrank();

        uint256 before = IERC20T(USDC).balanceOf(LANDING);
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(desk), rssIn);
        desk.draw(rssIn, usdcOut, LANDING);
        vm.stopPrank();

        uint256 after_ = IERC20T(USDC).balanceOf(LANDING);
        assertEq(after_ - before, usdcOut);
        assertGe(after_, 700_000e6);
        console2.log("PASS Landing USDC", after_);
    }
}
