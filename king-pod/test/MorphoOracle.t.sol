// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";

contract MorphoOraclePriceTest is Test {
    function test_price_five_cents() public {
        MorphoFixedOracle o = new MorphoFixedOracle(5e22);
        assertEq(o.price(), 5e22);
        // 20M RSS * price / 1e36 = 1e12 raw USDC = $1,000,000
        uint256 coll = 20_000_000 ether;
        uint256 loanUnits = (coll * o.price()) / 1e36;
        assertEq(loanUnits, 1_000_000e6);
    }

    function test_safe_debt_buffer() public pure {
        uint256 collUsd = 1_000_000e6;
        uint256 lltv = 770000000000000000;
        uint256 maxBorrow = (collUsd * lltv) / 1e18;
        uint256 safe = 500_000e6;
        assertTrue(safe < maxBorrow);
        uint256 hf = (maxBorrow * 1e18) / safe;
        assertTrue(hf >= 1.05e18);
    }
}
