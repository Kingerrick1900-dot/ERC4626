// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MorphoRssEusdOracle} from "../src/MorphoRssEusdOracle.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

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

    function createMarket(MarketParams memory) external;
    function setAuthorization(address, bool) external;
}

contract SovereignAmoForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    uint256 constant SUPPLY = 100_000_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        // Live AMO fire drained Landing eUSD / hot RSS; re-seed for isolated fork proofs.
        deal(EUSD, LANDING, 200_000_000e18);
        deal(RSS, HOT, 20_000_000 ether);
    }

    function test_100m_eusd_supply_creates_idle() public {
        uint256 landBefore = IERC20T(EUSD).balanceOf(LANDING);

        vm.startPrank(HOT);
        MorphoRssEusdOracle oracle = new MorphoRssEusdOracle();
        assertEq(oracle.priceValue(), 1200e36);

        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: EUSD,
            collateralToken: RSS,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 mid = keccak256(abi.encode(mp));

        CrownSovereignAmo amo = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, address(0), HOT, LANDING, mid, address(oracle), IRM, LLTV, HOT
        );
        amo.setRequireGate(false);

        vm.stopPrank();
        vm.prank(LANDING);
        IERC20T(EUSD).approve(address(amo), SUPPLY);
        vm.prank(HOT);
        amo.supplyAmo(LANDING, SUPPLY);

        assertGe(amo.idle(), SUPPLY, "idle miss");
        assertEq(IERC20T(EUSD).balanceOf(LANDING), landBefore - SUPPLY);

        console2.log("idle", amo.idle());
        console2.log("landing eUSD left", IERC20T(EUSD).balanceOf(LANDING));
    }

    function test_supply_post_borrow_eusd() public {
        vm.startPrank(HOT);
        MorphoRssEusdOracle oracle = new MorphoRssEusdOracle();
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: EUSD,
            collateralToken: RSS,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 mid = keccak256(abi.encode(mp));

        CrownSovereignAmo amo = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, address(0), HOT, LANDING, mid, address(oracle), IRM, LLTV, HOT
        );
        amo.setRequireGate(false);

        uint256 chunk = 10_000_000e18;
        vm.stopPrank();
        vm.prank(LANDING);
        IERC20T(EUSD).approve(address(amo), chunk);
        vm.startPrank(HOT);
        amo.supplyAmo(LANDING, chunk);

        uint256 rss = 100_000 ether;
        IERC20T(RSS).approve(address(amo), rss);
        amo.postCollateral(rss);

        IMorphoT(MORPHO).setAuthorization(address(amo), true);
        uint256 borrowAsk = 1_000_000e18;
        amo.borrowEusd(borrowAsk, HOT);
        vm.stopPrank();

        assertGe(IERC20T(EUSD).balanceOf(HOT), borrowAsk);
        console2.log("hot eUSD", IERC20T(EUSD).balanceOf(HOT));
        console2.log("idle after borrow", amo.idle());
    }

    function test_exit_full_roundtrip() public {
        uint256 supply = 100_000_000e18;
        uint256 rssAmt = 100_000 ether;
        uint256 borrowAsk = 1_000_000e18;

        vm.startPrank(HOT);
        MorphoRssEusdOracle oracle = new MorphoRssEusdOracle();
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: EUSD,
            collateralToken: RSS,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 mid = keccak256(abi.encode(mp));

        CrownSovereignAmo amo = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, address(0), HOT, LANDING, mid, address(oracle), IRM, LLTV, HOT
        );
        amo.setRequireGate(false);
        CrownSovereignExit exiter = new CrownSovereignExit(
            MORPHO, EUSD, RSS, HOT, LANDING, mid, address(oracle), IRM, LLTV, HOT
        );
        IMorphoT(MORPHO).setAuthorization(address(amo), true);
        IMorphoT(MORPHO).setAuthorization(address(exiter), true);
        vm.stopPrank();
        vm.prank(LANDING);
        IMorphoT(MORPHO).setAuthorization(address(exiter), true);

        uint256 land0 = IERC20T(EUSD).balanceOf(LANDING);
        uint256 rss0 = IERC20T(RSS).balanceOf(HOT);

        vm.prank(LANDING);
        IERC20T(EUSD).approve(address(amo), supply);
        vm.prank(HOT);
        amo.supplyAmo(LANDING, supply);

        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(amo), rssAmt);
        amo.postCollateral(rssAmt);
        amo.borrowEusd(borrowAsk, HOT);
        IERC20T(EUSD).approve(address(exiter), type(uint256).max);
        exiter.exitFull();
        vm.stopPrank();

        assertGe(IERC20T(EUSD).balanceOf(LANDING), land0 - 1e18, "landing recall");
        assertGe(IERC20T(RSS).balanceOf(HOT), rss0, "rss back");
        (, uint128 bor, uint128 coll) = IMorphoPosT(MORPHO).position(mid, HOT);
        (uint256 sup,,) = IMorphoPosT(MORPHO).position(mid, LANDING);
        assertEq(bor, 0);
        assertEq(coll, 0);
        assertEq(sup, 0);
        console2.log("landing eUSD after exit", IERC20T(EUSD).balanceOf(LANDING));
    }
}

interface IMorphoPosT {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}
