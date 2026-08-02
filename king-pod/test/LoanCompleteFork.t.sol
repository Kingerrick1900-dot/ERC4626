// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownZkLoanComplete} from "../src/CrownZkLoanComplete.sol";
import {CrownZkAutoDraw} from "../src/CrownZkAutoDraw.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkCreditOpT {
    function setOperator(address, bool) external;
    function operator(address) external view returns (bool);
    function maxBorrow(address) external view returns (uint256);
}

/// @notice Fork-proves fixed completer + auto-draw land USDC on Landing.
contract LoanCompleteForkTest is Test {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant ASK = 500_000e6;

    CrownZkLoanComplete completer;
    CrownZkAutoDraw autoDraw;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);

        vm.startPrank(HOT);
        completer = new CrownZkLoanComplete(CREDIT, USDC);
        autoDraw = new CrownZkAutoDraw(CREDIT, USDC);
        IZkCreditOpT(CREDIT).setOperator(address(completer), true);
        IZkCreditOpT(CREDIT).setOperator(address(autoDraw), true);
        vm.stopPrank();

        require(IZkCreditOpT(CREDIT).operator(address(completer)), "op c");
        require(IZkCreditOpT(CREDIT).operator(address(autoDraw)), "op a");
    }

    function test_complete_500k_to_landing() public {
        address matcher = makeAddr("matcher");
        deal(USDC, matcher, ASK);

        uint256 before = IERC20T(USDC).balanceOf(LANDING);
        assertGe(completer.maxAsk(), ASK, "maxAsk");

        vm.startPrank(matcher);
        require(IERC20T(USDC).approve(address(completer), ASK), "approve");
        uint256 landingAfter = completer.complete(ASK);
        vm.stopPrank();

        assertEq(landingAfter, before + ASK, "landing delta");
        assertEq(IERC20T(USDC).balanceOf(LANDING), before + ASK, "landing bal");
        assertEq(IERC20T(USDC).balanceOf(matcher), 0, "matcher spent");
        console2.log("LOAN_COMPLETE_FORK_OK", uint256(1));
        console2.log("completer", address(completer));
        console2.log("landingUsdc", landingAfter);
    }

    function test_supply_then_autodraw_500k() public {
        address matcher = makeAddr("matcher2");
        deal(USDC, matcher, ASK);
        uint256 before = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(matcher);
        require(IERC20T(USDC).approve(CREDIT, ASK), "approve");
        (bool ok,) = CREDIT.call(abi.encodeWithSignature("supply(uint256)", ASK));
        require(ok, "supply");
        vm.stopPrank();

        assertEq(IZkCreditOpT(CREDIT).maxBorrow(HOT), ASK, "maxBorrow");

        autoDraw.poke();
        assertEq(IERC20T(USDC).balanceOf(LANDING), before + ASK, "landing after poke");
        console2.log("AUTO_DRAW_FORK_OK", uint256(1));
    }
}
