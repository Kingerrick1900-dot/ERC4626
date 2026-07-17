// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20, MockBalancer} from "./Mocks.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingOracle} from "../src/KingOracle.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingPod} from "../src/KingPod.sol";
import {IERC20} from "../src/lib/Core.sol";

contract KingPodBootstrapTest is Test {
    address internal king = address(0x6708);
    address internal deployer = address(this);

    MockERC20 internal rss;
    MockERC20 internal usdc;
    MockBalancer internal balancer;
    KingSusdc internal sUsdc;
    KingPair internal pair;
    KingOracle internal oracle;
    KingMoneyMarket internal market;
    KingPod internal pod;

    uint256 internal constant RSS_STAKE = 20_979_000_000 ether;
    uint256 internal constant RSS_LIQUID = 21_000_000 ether;
    uint256 internal constant FLASH_USDC = 5_000_000e6; // $5M

    function setUp() public {
        rss = new MockERC20("RSS", "RSS", 18);
        usdc = new MockERC20("USDC", "USDC", 6);
        balancer = new MockBalancer();

        rss.mint(king, RSS_STAKE + RSS_LIQUID);
        usdc.mint(address(balancer), FLASH_USDC * 2);

        sUsdc = new KingSusdc(address(usdc), deployer);
        pair = new KingPair(address(rss), address(sUsdc), deployer);
        oracle = new KingOracle(address(rss), address(sUsdc), address(pair), deployer);
        market = new KingMoneyMarket(address(usdc), address(sUsdc), address(pair), address(oracle), deployer);
        pod = new KingPod(
            address(rss),
            address(usdc),
            address(sUsdc),
            address(pair),
            address(market),
            address(balancer),
            king,
            deployer
        );

        sUsdc.transferOwnership(address(market));
        market.setOperator(address(pod));

        vm.prank(king);
        rss.approve(address(pod), RSS_STAKE);
    }

    function test_optionA_bootstrap_closes() public {
        uint256 balBefore = usdc.balanceOf(address(balancer));

        pod.bootstrap(RSS_STAKE, FLASH_USDC);

        // Balancer whole again
        assertEq(usdc.balanceOf(address(balancer)), balBefore, "balancer repay");

        // LP collateral on king
        assertGt(market.collateralLp(king), 0, "collateral");

        // Debt ≈ flash
        assertEq(market.debtUsdc(king), FLASH_USDC, "debt");

        // Free USDC on king still ~0
        assertEq(usdc.balanceOf(king), 0, "no free usdc");

        // Liquid RSS remains
        assertEq(rss.balanceOf(king), RSS_LIQUID, "liquid reserve");

        // Healthy
        assertGe(market.healthFactor(king), 1e18, "hf");

        // Net idle in sUSDC vault ≈ 0 (supply borrowed out)
        assertEq(usdc.balanceOf(address(sUsdc)), 0, "idle usdc");
    }

    function test_teamCut_not_from_bootstrap() public {
        pod.bootstrap(RSS_STAKE, FLASH_USDC);
        // 12% of free borrowed USDC — free is 0 after Option A
        uint256 free = usdc.balanceOf(king);
        uint256 teamCut = (free * 12) / 100;
        assertEq(teamCut, 0, "no cut until external USDC");
    }

    function test_broken_handoff_ltv_cannot_repay_5m_from_35m_on_5m_cash_lp() public pure {
        // Document: $5M cash LP @ 70% LTV => max borrow $3.5M < $5M flash. Impossible.
        uint256 lpUsd = 5_000_000;
        uint256 maxBorrow = (lpUsd * 70) / 100;
        uint256 flash = 5_000_000;
        assertTrue(maxBorrow < flash);
    }
}
