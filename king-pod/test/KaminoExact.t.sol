// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKaminoExact} from "../src/CrownKaminoExact.sol";

interface IMorphoFull {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Exact Kamino with free RSS — same steps as USDe/USDG Multiply.
contract KaminoExactFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    // Kamino had USDG vault liquidity — mirror with a lender supply (not King WETH)
    address lender;

    uint256 constant FLASH = 500_000e6;
    uint256 constant WANT = 700_000e6;
    uint256 constant EQUITY_RSS = 10_000e18; // free RSS on hot — user deposit (like USDe)

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        lender = makeAddr("kaminoLender");
        // Mirror Kamino debt-asset vault liquidity (Sentora/USDG pool analog)
        deal(USDC, lender, FLASH + WANT + 1_000e6);
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoFull(MORPHO).idToMarketParams(MID);
        IMorphoFull.MarketParams memory mp = IMorphoFull.MarketParams(loan, coll, oracle, irm, lltv);
        vm.startPrank(lender);
        IERC20T(USDC).approve(MORPHO, FLASH + WANT);
        IMorphoFull(MORPHO).supply(mp, FLASH + WANT, 0, lender, "");
        vm.stopPrank();
    }

    function test_kamino_exact_free_rss_landing_700k() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        assertGe(IERC20T(RSS).balanceOf(HOT), EQUITY_RSS, "free RSS");

        vm.startPrank(HOT);
        CrownKaminoExact k = new CrownKaminoExact(MORPHO, USDC, RSS, AERO, HOT, LANDING, MID);
        IMorphoFull(MORPHO).setAuthorization(address(k), true);
        IERC20T(RSS).approve(address(k), EQUITY_RSS);
        k.multiply(EQUITY_RSS, FLASH, WANT, 1);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        console2.log("landingDelta", delta);
        console2.log("rssSupplied", k.lastRssSupplied());
        console2.log("borrowed", k.lastBorrowed());
        console2.log("closed", k.lastClosed());

        assertTrue(k.lastClosed());
        assertEq(delta, WANT, "Landing MUST hit 700k");
        assertEq(k.lastEquityRss(), EQUITY_RSS);
    }
}
