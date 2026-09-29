// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownDeallocSeed} from "../src/CrownDeallocSeed.sol";
import {CrownPoolEngineer} from "../src/CrownPoolEngineer.sol";

interface IMinter {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
}

interface IMeta {
    function setIsAllocator(address, bool) external;
    function maxWithdraw(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract DeallocSeedForkTest is Test {
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;
    address constant ENG = 0x4D42bBD373CE058959b8b2211DF4cCDa6cb3E3ff;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("BASE_RPC", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_dealloc_then_seed_pool_up() public {
        uint256 amt = 500e6;
        // Use live engineer if minter; else deploy fresh
        address eng = ENG;
        if (!IMinter(EUSD).isMinter(eng)) {
            CrownPoolEngineer e = new CrownPoolEngineer(YRSS, EUSD, USDC, RSS, NPM, HOT, ATTEST, HOT);
            vm.prank(HOT);
            IMinter(EUSD).setMinter(address(e), true);
            eng = address(e);
        }

        CrownDeallocSeed helper = new CrownDeallocSeed(MORPHO, YRSS, eng, USDC, HOT, PARK, HOT);

        uint256 poolBefore = IERC20b(USDC).balanceOf(POOL);
        uint256 rssBefore = IERC20b(RSS).balanceOf(HOT);
        assertEq(IMeta(YRSS).maxWithdraw(HOT), 0);

        vm.startPrank(HOT);
        IMeta(YRSS).setIsAllocator(address(helper), true);
        IMeta(YRSS).approve(address(helper), type(uint256).max);
        CrownPoolEngineer(eng).setOperator(address(helper), true);
        helper.deallocAndSeed(amt);
        vm.stopPrank();

        assertGt(IERC20b(USDC).balanceOf(POOL), poolBefore);
        assertGe(IERC20b(RSS).balanceOf(HOT), rssBefore);
        // gold shares still held (redeem reduced shares but RSS token unsold)
        assertGt(IMeta(YRSS).balanceOf(HOT), 0);
    }
}
