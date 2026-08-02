// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownComfortSeed} from "../src/CrownComfortSeed.sol";

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaT {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
    function owner() external view returns (address);
}

/// @notice Fork-prove comfort self-seed on live Base state (dust fold + RSS keep).
contract ComfortThroneForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", vm.envOr("RPC_URL", string("https://mainnet.base.org"))));
        vm.createSelectFork(rpc);
    }

    function test_ComfortSeed_KeepsRss_FoldsDust() public {
        uint256 rssKeep = 1_000_000e18;
        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);
        (, uint128 dustBorrow, uint128 dustColl) = IMorphoT(MORPHO).position(RSS_M, HOT);
        console2.log("rssBefore", rssBefore);
        console2.log("dustColl", uint256(dustColl));
        console2.log("dustBorrowShares", uint256(dustBorrow));

        vm.startPrank(HOT);
        bytes32[] memory q = new bytes32[](4);
        q[0] = RSS_M;
        q[1] = CBBTC_M;
        q[2] = WETH_M;
        q[3] = BRETT_M;
        if (IMetaT(YRSS).supplyQueue(0) != RSS_M) {
            IMetaT(YRSS).setSupplyQueue(q);
        }

        CrownComfortSeed seeder = new CrownComfortSeed(MORPHO, USDC, RSS, YRSS, HOT, RSS_M, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        IERC20T(RSS).approve(address(seeder), type(uint256).max);

        seeder.comfortSeed(rssKeep, 0, 0, 4860);
        vm.stopPrank();

        uint256 rssFree = IERC20T(RSS).balanceOf(HOT);
        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(RSS_M, HOT);
        (uint128 sup,, uint128 mBor,,,) = IMorphoT(MORPHO).market(RSS_M);
        uint256 yrssAssets = IMetaT(YRSS).convertToAssets(IMetaT(YRSS).balanceOf(HOT));

        console2.log("rssFree", rssFree);
        console2.log("coll", uint256(coll));
        console2.log("borShares", uint256(bor));
        console2.log("mSupply", uint256(sup));
        console2.log("mBorrow", uint256(mBor));
        console2.log("yrssAssets", yrssAssets);

        assertEq(rssFree, rssKeep, "keep free RSS");
        assertGt(uint256(coll), uint256(dustColl), "folded + posted coll");
        assertGt(uint256(bor), 0, "has debt");
        assertGt(yrssAssets, 100_000e6, "yRSS war chest");
        // util near 100% without sleeve — idle small
        uint256 idle = uint256(sup) > uint256(mBor) ? uint256(sup) - uint256(mBor) : 0;
        console2.log("idle", idle);
        // LTV soft: debt/coll value <= 70%
        // approx debt ~ mBorrow if king is sole borrower
        uint256 collUsd6 = uint256(coll) / 1e12;
        assertLe(uint256(mBor) * 10_000, collUsd6 * 7000 + 1e6, "under 70% LTV");
    }

    function test_ComfortSeed_WithSleeve_CreatesIdle() public {
        uint256 rssKeep = 1_000_000e18;
        uint256 sleeve = 250_000e6; // $250k comfort sleeve
        deal(USDC, HOT, sleeve);

        vm.startPrank(HOT);
        bytes32[] memory q = new bytes32[](4);
        q[0] = RSS_M;
        q[1] = CBBTC_M;
        q[2] = WETH_M;
        q[3] = BRETT_M;
        if (IMetaT(YRSS).supplyQueue(0) != RSS_M) {
            IMetaT(YRSS).setSupplyQueue(q);
        }

        CrownComfortSeed seeder = new CrownComfortSeed(MORPHO, USDC, RSS, YRSS, HOT, RSS_M, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        IERC20T(RSS).approve(address(seeder), type(uint256).max);
        IERC20T(USDC).approve(address(seeder), type(uint256).max);

        seeder.comfortSeed(rssKeep, 0, sleeve, 4860);
        vm.stopPrank();

        (uint128 sup,, uint128 mBor,,,) = IMorphoT(MORPHO).market(RSS_M);
        uint256 idle = uint256(sup) > uint256(mBor) ? uint256(sup) - uint256(mBor) : 0;
        console2.log("sleeveIdle", idle);
        assertGe(idle, sleeve - 1e6, "sleeve becomes idle");
    }
}
