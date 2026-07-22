// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownRssLbp} from "../src/CrownRssLbp.sol";
import {CrownPcvController} from "../src/CrownPcvController.sol";

contract MockErc20P {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address t, uint256 a) external {
        balanceOf[t] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address t, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[t] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 x = allowance[f][msg.sender];
        if (x != type(uint256).max) allowance[f][msg.sender] = x - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract MockGateP {
    function isProven(address) external pure returns (bool) {
        return true;
    }
}

contract MorphoStub {
    uint256 public posted;
    MockErc20P public rss;

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    constructor(address rss_) {
        rss = MockErc20P(rss_);
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address, bytes memory) external {
        rss.transferFrom(msg.sender, address(this), assets);
        posted += assets;
    }
}

contract CrownPcvSeedTest is Test {
    MockErc20P rss;
    MockErc20P usdc;
    CrownRssLbp lbp;
    CrownPcvController pcv;
    MorphoStub morpho;
    address land = address(0x1A11D);

    function setUp() public {
        rss = new MockErc20P();
        usdc = new MockErc20P();
        morpho = new MorphoStub(address(rss));
        lbp = new CrownRssLbp(address(rss), address(usdc), land, address(this));
        pcv = new CrownPcvController(
            address(rss),
            address(usdc),
            address(new MockGateP()),
            address(morpho),
            land,
            address(this),
            address(0xA11),
            address(0xB22),
            address(this)
        );
        lbp.transferOwnership(address(pcv));
        pcv.setRails(address(lbp), address(0), address(0), address(0));

        rss.mint(address(this), 300_000 ether);
        usdc.mint(address(this), 10_000e6);
        rss.approve(address(pcv), type(uint256).max);
        usdc.approve(address(pcv), type(uint256).max);
    }

    function test_pcv_seed_lbp_and_floor() public {
        pcv.depositPcv(200_000 ether);
        pcv.seedLbpFromPcv(50_000 ether, 1e6, 172_800);
        assertEq(lbp.rssReserve(), 50_000 ether);
        assertTrue(lbp.live());
        // remaining PCV accounting 150k; floor 100k — morpho 50k ok
        pcv.postMorphoBook(50_000 ether);
        assertEq(morpho.posted(), 50_000 ether);
    }

    function test_lbp_buy_sends_usdc_to_landing() public {
        pcv.depositPcv(200_000 ether);
        pcv.seedLbpFromPcv(50_000 ether, 1e6, 172_800);
        address buyer = address(0xB0B);
        usdc.mint(buyer, 1_000e6);
        vm.startPrank(buyer);
        usdc.approve(address(lbp), 1_000e6);
        uint256 out = lbp.buyRss(1_000e6, 0);
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(usdc.balanceOf(land), 1_000e6); // 100% to Landing
    }

    function test_below_floor_reverts() public {
        pcv.depositPcv(120_000 ether);
        vm.expectRevert(CrownPcvController.BelowFloor.selector);
        pcv.seedLbpFromPcv(50_000 ether, 0, 172_800); // would leave 70k < 100k floor
    }
}
