// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPowerRail} from "../src/CrownPowerRail.sol";
import {MorphoPegOracle} from "../src/MorphoPegOracle.sol";

contract CrownPowerRailTest is Test {
    CrownPowerRail rail;
    address eusd = address(0xE1);
    address morpho = address(0xB0);
    address king = address(0x1111);
    address landing = address(0x2222);

    function setUp() public {
        rail = new CrownPowerRail(eusd, morpho, king, landing, address(this));
    }

    function testConstruct() public view {
        assertTrue(rail.armed());
        assertEq(rail.king(), king);
        assertEq(rail.landing(), landing);
    }

    function testPegOracle() public {
        MorphoPegOracle o = new MorphoPegOracle(1e24);
        assertEq(o.price(), 1e24);
    }

    function testOnlyOwnerStable() public {
        vm.prank(king);
        vm.expectRevert();
        rail.setStable(address(0x8335), true);
    }
}
