// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {CrownRevenueSweep} from "../src/CrownRevenueSweep.sol";
import {CrownGoldConvert} from "../src/CrownGoldConvert.sol";
import {CrownGold} from "../src/CrownGold.sol";

contract MockUsdc {
    string public name = "USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[to] += a;
        return true;
    }
}

contract RouteABTest is Test {
    MockUsdc usdc;
    CrownColdBuffer cold;
    CrownRevenueSweep sweep;
    CrownGoldConvert convert;
    CrownGold kxau;

    address hot;
    address feeSrc;
    address filler;

    function setUp() public {
        hot = makeAddr("hot");
        feeSrc = makeAddr("fee");
        filler = makeAddr("filler");
        usdc = new MockUsdc();
        cold = new CrownColdBuffer(address(usdc), hot, address(0));
        sweep = new CrownRevenueSweep(address(usdc), address(cold), hot, hot);
        convert = new CrownGoldConvert(address(usdc), hot, address(0), hot);
        kxau = new CrownGold(hot);

        vm.prank(hot);
        sweep.setFeeSource(feeSrc, true);
        vm.prank(hot);
        convert.setSellable(address(kxau), true, 8);
        vm.prank(hot);
        convert.setTargetUsdc(1_500_000_000000);
    }

    function test_routeA_split_30_70() public {
        usdc.mint(feeSrc, 1_000_000e6);
        vm.prank(feeSrc);
        usdc.approve(address(sweep), type(uint256).max);

        vm.prank(hot);
        sweep.sweep(feeSrc, 1_000_000e6);

        assertEq(usdc.balanceOf(address(cold)), 300_000e6);
        assertEq(usdc.balanceOf(hot), 700_000e6);
        (uint256 swept, uint256 c, uint256 h, uint256 bps) = sweep.book();
        assertEq(swept, 1_000_000e6);
        assertEq(c, 300_000e6);
        assertEq(h, 700_000e6);
        assertEq(bps, 3000);
    }

    function test_routeA_cold_floor() public {
        vm.prank(hot);
        vm.expectRevert("COLD_FLOOR");
        sweep.setColdBps(2999);
    }

    function test_routeB_limit_ask_to_hot() public {
        vm.prank(hot);
        kxau.mint(hot, 100e8); // 100 oz
        vm.prank(hot);
        kxau.approve(address(convert), 100e8);

        uint256 minOut = 980e6; // $980 @ $9.80
        vm.prank(hot);
        uint256 id = convert.postAsk(address(kxau), 100e8, minOut, uint64(block.timestamp + 1 days));

        usdc.mint(filler, minOut);
        vm.prank(filler);
        usdc.approve(address(convert), minOut);
        vm.prank(filler);
        convert.fillAsk(id);

        assertEq(usdc.balanceOf(hot), minOut);
        assertEq(kxau.balanceOf(filler), 100e8);
        (, uint256 filled,,,) = convert.book();
        assertEq(filled, minOut);
    }

    function test_routeB_twamm_vests_and_fills() public {
        uint256 oz = 153_062e8; // sealed ceil for ~$1.5M @ $9.80
        vm.prank(hot);
        kxau.mint(hot, oz);
        vm.prank(hot);
        kxau.approve(address(convert), oz);

        uint64 start = uint64(block.timestamp);
        uint64 end = start + 7 days;
        vm.prank(hot);
        uint256 id = convert.postTwamm(address(kxau), oz, 9_800_000, start, end);

        // halfway: ~half vested
        vm.warp(start + 3.5 days);
        uint256 avail = convert.twammAvailable(id);
        assertGt(avail, 0);

        // fill $150k max chunk
        uint256 chunkOz = (uint256(150_000e6) * uint256(1e8)) / uint256(9_800_000);
        usdc.mint(filler, 150_000e6);
        vm.prank(filler);
        usdc.approve(address(convert), type(uint256).max);
        vm.prank(filler);
        convert.fillTwamm(id, chunkOz);

        // integer division may leave ≤1 USDC-wei short of exact $150k
        assertApproxEqAbs(usdc.balanceOf(hot), 150_000e6, 1);
        assertEq(kxau.balanceOf(filler), chunkOz);
    }
}
