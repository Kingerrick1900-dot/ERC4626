// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownWhaleHarvest} from "../src/CrownWhaleHarvest.sol";
import {MorphoPegOracle} from "../src/MorphoPegOracle.sol";

contract CrownWhaleHarvestTest is Test {
    CrownWhaleHarvest harvest;
    address morpho = address(0xB0B);
    address king = address(0x1111);
    address landing = address(0x2222);

    function setUp() public {
        harvest = new CrownWhaleHarvest(morpho, king, landing, address(this));
    }

    function testArmedDefault() public view {
        assertTrue(harvest.armed());
        assertEq(harvest.king(), king);
        assertEq(harvest.landing(), landing);
        assertEq(harvest.marketCount(), 0);
    }

    function testPegOracleUsdc() public {
        MorphoPegOracle o = new MorphoPegOracle(1e24);
        assertEq(o.price(), 1e24);
    }

    function testPegOracleDai() public {
        MorphoPegOracle o = new MorphoPegOracle(1e36);
        assertEq(o.price(), 1e36);
    }

    function testOnlyOwnerAddMarket() public {
        vm.prank(king);
        vm.expectRevert();
        harvest.addMarket(bytes32(uint256(1)));
    }
}
