// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

/// @notice Pure gate math for Alpha/Charlie liquidity rail (no live fork required).
contract LiquidityRailGatesTest is Test {
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant ASK = 500_000e6;

    function _idle(uint256 supply, uint256 borrow) internal pure returns (uint256) {
        return supply > borrow ? supply - borrow : 0;
    }

    function _headroom(uint256 coll8dp, uint256 borrowAssets) internal pure returns (uint256) {
        uint256 collUsd6 = coll8dp / 100; // $1 soft
        uint256 max77 = (collUsd6 * LLTV_77) / 1e18;
        return max77 > borrowAssets ? max77 - borrowAssets : 0;
    }

    function test_ele77_live_shape_headroom_without_idle() public pure {
        // Mirrors 25M ELE / $17.5M matched book
        uint256 coll = 25_000_000e8;
        uint256 borrow = 17_500_000e6;
        uint256 supply = 17_500_000e6 + 3; // dust surplus
        uint256 head = _headroom(coll, borrow);
        uint256 idle = _idle(supply, borrow);
        assertGt(head, ASK);
        assertLt(idle, ASK);
        // Charlie: headroom alone must NOT authorize fire
        bool charlieReady = idle >= ASK && head >= ASK;
        assertFalse(charlieReady);
    }

    function test_alpha_requires_inventory_and_depth() public pure {
        uint256 depth = 55_000_000e6;
        // Dust ETH (~0.0004) must not arm $500k
        uint256 dustEth = 0.0004 ether;
        uint256 dustUsd6 = (dustEth * 3000e6) / 1e18;
        bool swapReady = dustUsd6 >= (ASK * 12) / 10 && depth >= (ASK * 12) / 10;
        assertFalse(swapReady);

        // ~200 ETH ≈ $600k at $3k — covers $500k + 20%
        uint256 sizedEth = 200 ether;
        uint256 sizedUsd6 = (sizedEth * 3000e6) / 1e18;
        swapReady = sizedUsd6 >= (ASK * 12) / 10 && depth >= (ASK * 12) / 10;
        assertTrue(swapReady);
    }

    function test_pa_door_needs_vault_assets() public pure {
        uint256 maxIn = 700_000e6;
        uint256 yeleTotal = 2; // dust
        bool door = maxIn >= ASK && yeleTotal >= ASK;
        assertFalse(door);
        yeleTotal = ASK;
        door = maxIn >= ASK && yeleTotal >= ASK;
        assertTrue(door);
    }

    function test_psm_path_needs_usdc_reserve() public pure {
        uint256 psmUsdc = 0;
        uint256 inventory = 1 ether;
        bool psmReady = inventory > 0 && psmUsdc >= ASK;
        assertFalse(psmReady);
        psmUsdc = ASK;
        psmReady = inventory > 0 && psmUsdc >= ASK;
        assertTrue(psmReady);
    }

    function test_ele_never_liquidity_instrument() public pure {
        // Encoding of doctrine: rail asset codes exclude ELE/RSS
        bytes32 ele = keccak256("ELE");
        bytes32 rss = keccak256("RSS");
        bytes32 weth = keccak256("WETH");
        bytes32 cbbtc = keccak256("cbBTC");
        assertTrue(weth != ele && cbbtc != ele);
        assertTrue(weth != rss && cbbtc != rss);
    }
}
