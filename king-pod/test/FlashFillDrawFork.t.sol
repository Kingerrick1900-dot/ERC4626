// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPrimeFlashFillDraw} from "../src/prime/CrownPrimeFlashFillDraw.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoAuthF {
    function setAuthorization(address authorized, bool newAuthorized) external;
}

interface ICreditF {
    function freeUsdc() external view returns (uint256);
    function debtOf(address) external view returns (uint256);
    function setOperator(address, bool) external;
}

/// @notice Fork Base — cancel typo order, reopen $4.5M, flash fill → order filled.
contract FlashFillDrawForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant TREASURY = 0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97;
    bytes32 constant BROKEN_ORDER =
        0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c;

    uint256 constant ASK = 4_500_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_fork_cancel_reopen_flash_fill() public {
        CrownPrimeFlashFillDraw engine = new CrownPrimeFlashFillDraw(
            MORPHO, USDC, FILL, CREDIT, TREASURY, LANDING, HOT, HOT
        );

        vm.startPrank(HOT);
        CrownPrime7683Fill(FILL).cancel(BROKEN_ORDER);
        CrownPrime7683Fill(FILL).setFees(1000, 0);
        bytes32 oid = CrownPrime7683Fill(FILL).openOrder(HOT, 5_000_000e18, ASK, uint32(block.timestamp + 7 days));
        ICreditF(CREDIT).setOperator(address(engine), true);
        IMorphoAuthF(MORPHO).setAuthorization(address(engine), true);
        engine.flashFillAndDraw(oid, ASK, LANDING, 0);
        vm.stopPrank();

        (,,,,, uint8 status,, uint256 filled) = CrownPrime7683Fill(FILL).orders(oid);
        assertEq(status, 2);
        assertEq(filled, ASK);
        assertEq(ICreditF(CREDIT).freeUsdc(), 0);
        assertEq(ICreditF(CREDIT).debtOf(HOT), ASK);
        assertGt(IERC20F(EUSD).balanceOf(HOT), 4_999_000e18);
    }
}
