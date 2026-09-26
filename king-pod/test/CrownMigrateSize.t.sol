// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";
import {CrownMigrateYrss} from "../src/CrownMigrateYrss.sol";

interface IMorphoT {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}
interface IMetaMorphoT {
    function setSupplyQueue(bytes32[] calldata ids) external;
    function convertToAssets(uint256) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

contract CrownMigrateSizeTest is Test {
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

    function _run(uint256 tranche) internal {
        vm.startPrank(HOT);
        bytes32[] memory q = new bytes32[](1);
        q[0] = PARK;
        IMetaMorphoT(YRSS).setSupplyQueue(q);
        CrownMigrateYrss mig = new CrownMigrateYrss(MORPHO, USDC, YRSS, HOT, PARK, RSS, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(mig), true);
        uint256 before_ = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));
        mig.migrate(tranche);
        uint256 after_ = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));
        console2.log("tranche", tranche);
        console2.log("moved", after_ - before_);
        vm.stopPrank();
        assertApproxEqAbs(after_ - before_, tranche, 5e6);
    }

    function test_50m() public { _run(50_000_000e6); }
    function test_100m() public { _run(100_000_000e6); }
    function test_150m() public { _run(150_000_000e6); }
    function test_200m() public { _run(200_000_000e6); }
}
