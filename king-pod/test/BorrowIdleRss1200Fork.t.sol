// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
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
    function accrueInterest(MarketParams memory marketParams) external;
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

/// @dev Fork proof: seed idle on RSS/$1200, post RSS coll, borrow $700k to Landing.
contract BorrowIdleRss1200ForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant WANT = 700_000e6;
    uint256 constant RSS_POST = 850 ether;

    function test_borrow_idle_to_landing_rss1200() public {
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);

        address whale = makeAddr("usdcWhale");
        deal(USDC, whale, WANT);
        vm.startPrank(whale);
        IERC20T(USDC).approve(MORPHO, WANT);
        IMorphoT(MORPHO).supply(mp, WANT, 0, whale, "");
        vm.stopPrank();

        IMorphoT(MORPHO).accrueInterest(mp);
        (uint128 supply,, uint128 borrow,,,) = IMorphoT(MORPHO).market(MID);
        uint256 idle = uint256(supply) - uint256(borrow);
        assertGe(idle, WANT);

        uint256 landingBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        IERC20T(RSS).approve(MORPHO, RSS_POST);
        IMorphoT(MORPHO).supplyCollateral(mp, RSS_POST, HOT, "");
        IMorphoT(MORPHO).borrow(mp, WANT, 0, HOT, LANDING);
        vm.stopPrank();

        uint256 landingAfter = IERC20T(USDC).balanceOf(LANDING);
        console2.log("landingDelta", landingAfter - landingBefore);
        assertGe(landingAfter - landingBefore, WANT);
    }
}
