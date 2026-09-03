// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPrimeFlashFillDraw} from "../src/prime/CrownPrimeFlashFillDraw.sol";

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoAuthL {
    function setAuthorization(address authorized, bool newAuthorized) external;
}

interface ICreditL {
    function freeUsdc() external view returns (uint256);
    function debtOf(address) external view returns (uint256);
    function setOperator(address, bool) external;
    function operator(address) external view returns (bool);
}

interface IFillL {
    function orders(bytes32)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            uint32,
            uint8 status,
            address,
            uint256 filledUsdc
        );
}

/// @notice Fork sim against live deployed stack + new engine bytecode.
contract FlashFillLiveEngineForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant TREASURY = 0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97;
    bytes32 constant ORDER_ID = 0x2c85b27d5a04300779222173c2add2a7d71e366734c5b8aab435fba579f5eada;

    uint256 constant ASK = 4_500_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_fork_live_order_flash_fill() public {
        (,,,,, uint8 statusBefore,,) = IFillL(FILL).orders(ORDER_ID);
        assertEq(statusBefore, 1, "order open");

        CrownPrimeFlashFillDraw engine = new CrownPrimeFlashFillDraw(
            MORPHO, USDC, FILL, CREDIT, TREASURY, LANDING, HOT, HOT
        );

        vm.startPrank(HOT);
        ICreditL(CREDIT).setOperator(address(engine), true);
        IMorphoAuthL(MORPHO).setAuthorization(address(engine), true);
        engine.flashFillAndDraw(ORDER_ID, ASK, LANDING, 0);
        vm.stopPrank();

        (,,,,, uint8 statusAfter,, uint256 filled) = IFillL(FILL).orders(ORDER_ID);
        assertEq(statusAfter, 2);
        assertEq(filled, ASK);
        assertEq(ICreditL(CREDIT).debtOf(HOT), ASK);
        assertEq(ICreditL(CREDIT).freeUsdc(), 0);
    }
}
