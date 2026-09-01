// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPrimeIdleTap} from "../src/prime/CrownPrimeIdleTap.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function setAuthorization(address authorized, bool newAuthorized) external;
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20T {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fork: stand up eUSD/USDC Morpho book, seed real USDC, tap into credit idle.
contract IdleTapForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    uint256 constant LLTV = 860000000000000000;
    uint256 constant SEED = 100_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_fork_tap_puts_usdc_in_credit() public {
        MorphoFixedOracle oracle = new MorphoFixedOracle(1e24);
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));

        CrownPrimeIdleTap tap = new CrownPrimeIdleTap(MORPHO, USDC, EUSD, CREDIT, HOT, address(this));
        tap.setEusdMarket(address(oracle), IRM, LLTV, id);

        deal(USDC, address(this), SEED);
        IERC20T(USDC).approve(MORPHO, SEED);
        IMorphoT(MORPHO).supply(mp, SEED, 0, address(this), "");

        vm.startPrank(HOT);
        IMorphoT(MORPHO).setAuthorization(address(tap), true);
        IERC20T(EUSD).approve(address(tap), 200_000e18);
        tap.postEusd(200_000e18);
        uint256 idleBefore = IERC20T(USDC).balanceOf(CREDIT);
        tap.tapEusd(SEED);
        vm.stopPrank();

        uint256 idleAfter = IERC20T(USDC).balanceOf(CREDIT);
        assertEq(idleAfter - idleBefore, SEED);
        (uint128 sup,, uint128 bor,,,) = IMorphoT(MORPHO).market(id);
        assertEq(uint256(sup), uint256(bor));
    }
}
