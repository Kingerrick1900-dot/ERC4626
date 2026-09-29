// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownBorrowSeed} from "../src/CrownBorrowSeed.sol";
import {CrownPoolEngineer} from "../src/CrownPoolEngineer.sol";

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IMinter {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract BorrowSeedForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ENG = 0x4D42bBD373CE058959b8b2211DF4cCDa6cb3E3ff;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("BASE_RPC", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_park_at_full_util_reverts_no_idle() public {
        CrownBorrowSeed helper = new CrownBorrowSeed(MORPHO, ENG, USDC, HOT, PARK, HOT);
        vm.prank(HOT);
        vm.expectRevert(CrownBorrowSeed.NoIdle.selector);
        helper.borrowAndSeed(500_000e6);
    }

    /// @dev External USDC supply + posting idle RSS margin → borrow → seed (loan ≠ sell).
    function test_fork_borrow_and_seed_when_idle_and_margin() public {
        uint256 amt = 500_000e6;
        address eng = ENG;
        if (!IMinter(EUSD).isMinter(eng)) {
            CrownPoolEngineer e = new CrownPoolEngineer(YRSS, EUSD, USDC, RSS, NPM, HOT, ATTEST, HOT);
            vm.prank(HOT);
            IMinter(EUSD).setMinter(address(e), true);
            eng = address(e);
        }

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorpho(MORPHO).idToMarketParams(PARK);
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(loan, coll, oracle, irm, lltv);

        address lp = makeAddr("external_lp");
        deal(USDC, lp, amt);
        vm.startPrank(lp);
        IERC20b(USDC).approve(MORPHO, amt);
        IMorpho(MORPHO).supply(mp, amt, 0, lp, "");
        vm.stopPrank();

        // Live HOT PARK book is LTV-maxed; post idle RSS (locked coll, not sold) for headroom.
        uint256 rssPost = 500_000 ether;
        deal(RSS, HOT, rssPost);
        vm.startPrank(HOT);
        IERC20b(RSS).approve(MORPHO, rssPost);
        IMorpho(MORPHO).supplyCollateral(mp, rssPost, HOT, "");
        vm.stopPrank();

        CrownBorrowSeed helper = new CrownBorrowSeed(MORPHO, eng, USDC, HOT, PARK, HOT);
        uint256 poolBefore = IERC20b(USDC).balanceOf(POOL);
        uint256 rssBefore = IERC20b(RSS).balanceOf(HOT);

        vm.startPrank(HOT);
        IMorpho(MORPHO).setAuthorization(address(helper), true);
        CrownPoolEngineer(eng).setOperator(address(helper), true);
        helper.borrowAndSeed(amt);
        vm.stopPrank();

        assertGt(IERC20b(USDC).balanceOf(POOL), poolBefore);
        assertGe(IERC20b(RSS).balanceOf(HOT), rssBefore);
    }
}
