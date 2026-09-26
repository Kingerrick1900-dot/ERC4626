// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownMigrateYrss} from "../src/CrownMigrateYrss.sol";

interface IMorphoT {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoT {
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @dev Base fork — peel HOT Morpho supply into yRSS at 100% util.
contract CrownMigrateYrssTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_migrate_tranche_5m() public {
        uint256 tranche = 5_000_000e6;

        vm.startPrank(HOT);
        bytes32[] memory q = new bytes32[](1);
        q[0] = PARK;
        if (IMetaMorphoT(YRSS).supplyQueue(0) != PARK) {
            IMetaMorphoT(YRSS).setSupplyQueue(q);
        }

        CrownMigrateYrss mig = new CrownMigrateYrss(MORPHO, USDC, YRSS, HOT, PARK, RSS, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(mig), true);

        (uint256 hs,,) = IMorphoT(MORPHO).position(PARK, HOT);
        uint256 yrssBefore = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));

        mig.migrate(tranche);
        vm.stopPrank();

        uint256 yrssAfter = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));
        (uint256 hs3,,) = IMorphoT(MORPHO).position(PARK, HOT);

        assertGt(yrssAfter, yrssBefore);
        assertApproxEqAbs(yrssAfter - yrssBefore, tranche, 2e6);
        assertLt(hs3, hs);
    }

    function test_migrate_max_peel() public {
        vm.startPrank(HOT);
        bytes32[] memory q = new bytes32[](1);
        q[0] = PARK;
        IMetaMorphoT(YRSS).setSupplyQueue(q);

        CrownMigrateYrss mig = new CrownMigrateYrss(MORPHO, USDC, YRSS, HOT, PARK, RSS, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(mig), true);

        uint256 yrssBefore = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));
        (uint256 hs,,) = IMorphoT(MORPHO).position(PARK, HOT);

        mig.migrate(0); // max − $1k
        vm.stopPrank();

        uint256 yrssAfter = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));
        (uint256 hs2,,) = IMorphoT(MORPHO).position(PARK, HOT);
        console2.log("yrssBefore", yrssBefore);
        console2.log("yrssAfter", yrssAfter);
        console2.log("moved", yrssAfter - yrssBefore);
        console2.log("hotSharesBefore", hs);
        console2.log("hotSharesAfter", hs2);
        assertGt(yrssAfter, yrssBefore + 100_000_000e6);
        assertLt(hs2, hs / 100);
    }
}
