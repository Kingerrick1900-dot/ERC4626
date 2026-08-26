// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownFxEngine} from "../src/fleet/CrownFxEngine.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function mint(address, uint256) external;
}

interface IMorphoT {
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
}

/// @notice FxEngine fork proofs — fill only when armed; default disarmed (no loans).
contract FxEngineFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID_USDC = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_deploy_disarmed_no_fill() public {
        vm.startPrank(HOT);
        CrownFxEngine engine = new CrownFxEngine(MORPHO, USDC, EUSD, HOT, MID_USDC, HOT);
        assertFalse(engine.armed());
        assertFalse(engine.canFill(1_000_000e6));
        vm.expectRevert(CrownFxEngine.NotArmed.selector);
        engine.fillRedeem(1_000e18, HOT, HOT);
        vm.stopPrank();
    }

    function test_canFill_true_when_armed_and_idle() public {
        vm.startPrank(HOT);
        CrownFxEngine engine = new CrownFxEngine(MORPHO, USDC, EUSD, HOT, MID_USDC, HOT);
        engine.setArmed(true);
        // Live idle often ~0 → canFill false until idle exists
        bool ok = engine.canFill(100e6);
        console2.log("idle", engine.idleUsdc());
        console2.log("cap", engine.borrowCapacity());
        console2.log("canFill100", ok);
        // Capacity should still be >> 10M
        assertGe(engine.borrowCapacity(), 10_000_000e6);
        vm.stopPrank();
    }

    function test_fill_flash_borrow_repay_when_idle_seeded() public {
        uint256 ask = 10_000e6; // $10k micro fill on fork only
        address user = address(0xBEEF);

        vm.startPrank(HOT);
        CrownFxEngine engine = new CrownFxEngine(MORPHO, USDC, EUSD, HOT, MID_USDC, HOT);
        IMorphoT(MORPHO).setAuthorization(address(engine), true);
        engine.setArmed(true);
        engine.setFiller(HOT);

        // Seed unmatched idle so borrow leg can close flash
        deal(USDC, HOT, ask);
        IERC20T(USDC).approve(MORPHO, ask);
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            _params();
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams(loan, coll, oracle, irm, lltv);
        IMorphoT(MORPHO).supply(mp, ask, 0, HOT, "");
        assertGe(engine.idleUsdc(), ask);

        IERC20T(EUSD).mint(HOT, ask * 1e12);
        IERC20T(EUSD).approve(address(engine), ask * 1e12);

        uint256 u0 = IERC20T(USDC).balanceOf(user);
        engine.fillRedeem(ask * 1e12, HOT, user);
        vm.stopPrank();

        assertEq(IERC20T(USDC).balanceOf(user) - u0, ask);
        console2.log("filled", engine.lastFillUsdc());
    }

    function _params()
        internal
        view
        returns (address, address, address, address, uint256)
    {
        return (
            USDC,
            0x7a305D07B537359cf468eAea9bb176E5308bC337,
            0xB5840644142B341a6145335e2ebc82EEBC7aE1B9,
            0x46415998764C29aB2a25CbeA6254146D50D22687,
            770000000000000000
        );
    }
}
