// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownCuratorTranche} from "../src/CrownCuratorTranche.sol";
import {CrownPendleSleeve} from "../src/CrownPendleSleeve.sol";

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract CuratorTrancheTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_cap_and_split_deposit() public {
        uint256 amt = 1_000_000e6; // $1M prove (not 200M — physics)
        CrownCuratorTranche tranche = new CrownCuratorTranche(USDC, HOT, LANDING, HOT);
        CrownPendleSleeve sleeve = new CrownPendleSleeve(USDC, address(tranche), HOT);

        vm.startPrank(HOT);
        tranche.setCurators(GAUNTLET, STEAK, address(sleeve));
        tranche.setAttest(ATTEST);
        tranche.setRequireBorders(true);
        tranche.setArmed(true);
        vm.stopPrank();

        deal(USDC, HOT, amt);
        uint256 gBefore = IERC20b(GAUNTLET).balanceOf(address(tranche));
        uint256 sBefore = IERC20b(STEAK).balanceOf(address(tranche));

        vm.startPrank(HOT);
        IERC20b(USDC).approve(address(tranche), amt);
        tranche.deploy(amt);
        vm.stopPrank();

        assertEq(tranche.totalDeployed(), amt);
        assertGt(IERC20b(GAUNTLET).balanceOf(address(tranche)), gBefore);
        assertGt(IERC20b(STEAK).balanceOf(address(tranche)), sBefore);
        assertEq(sleeve.balanceOf(address(tranche)), amt / 10); // 10% sleeve
        assertLe(tranche.totalDeployed(), tranche.CAP());
    }

    function test_fork_rejects_over_cap() public {
        CrownCuratorTranche tranche = new CrownCuratorTranche(USDC, HOT, LANDING, HOT);
        CrownPendleSleeve sleeve = new CrownPendleSleeve(USDC, address(tranche), HOT);
        vm.startPrank(HOT);
        tranche.setCurators(GAUNTLET, STEAK, address(sleeve));
        tranche.setAttest(ATTEST);
        tranche.setArmed(true);
        vm.stopPrank();

        uint256 over = 200_000_001e6;
        deal(USDC, HOT, over);
        vm.startPrank(HOT);
        IERC20b(USDC).approve(address(tranche), over);
        vm.expectRevert(CrownCuratorTranche.Cap.selector);
        tranche.deploy(over);
        vm.stopPrank();
    }

    function test_fork_live_usdc_zero_eusd_is_not_deposit_asset() public view {
        // Truth: war chest is eUSD on Landing; Gauntlet asset is USDC.
        assertEq(IERC20b(USDC).balanceOf(HOT), 0);
        assertGt(IERC20b(0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a).balanceOf(LANDING), 1_000_000e18);
    }
}
