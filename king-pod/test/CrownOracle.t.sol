// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownOracle} from "../src/CrownOracle.sol";

contract CrownOracleTest is Test {
    address constant HOT = address(0x6708);
    address constant STRANGER = address(0xBEEF);

    uint256 constant P1200 = 1200000000000000000000000000;
    uint256 constant P50K = 50000000000000000000000000000;

    function test_deploy_owner_price() public {
        CrownOracle o = new CrownOracle(HOT, P1200);
        assertEq(o.owner(), HOT);
        assertEq(o.price(), P1200);
    }

    function test_setPrice_onlyOwner() public {
        CrownOracle o = new CrownOracle(HOT, P1200);
        vm.prank(STRANGER);
        vm.expectRevert(CrownOracle.NotOwner.selector);
        o.setPrice(P50K);

        vm.prank(HOT);
        o.setPrice(P50K);
        assertEq(o.price(), P50K);
    }

    function test_transferOwnership_onlyOwner() public {
        CrownOracle o = new CrownOracle(HOT, P1200);
        vm.prank(HOT);
        o.transferOwnership(STRANGER);
        assertEq(o.owner(), STRANGER);
        vm.prank(STRANGER);
        o.setPrice(P1200);
    }

    function test_rejectZeroPrice() public {
        vm.expectRevert(CrownOracle.ZeroPrice.selector);
        new CrownOracle(HOT, 0);
        CrownOracle o = new CrownOracle(HOT, P1200);
        vm.prank(HOT);
        vm.expectRevert(CrownOracle.ZeroPrice.selector);
        o.setPrice(0);
    }
}
