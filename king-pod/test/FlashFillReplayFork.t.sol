// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

interface IEngine {
    function flashFillAndDraw(bytes32 orderId, uint256 usdcIn, address drawTo, uint256 repayTopUp) external;
}

interface IFill {
    function orders(bytes32)
        external
        view
        returns (address, address, uint256, uint256, uint32, uint8, address, uint256);
}

/// @dev Replay live deployed engine on fork to catch revert.
contract FlashFillReplayForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ENGINE = 0x8e5932cAD340A37EE669510A8A7FB91deA879997;
    bytes32 constant ORDER_ID = 0x2c85b27d5a04300779222173c2add2a7d71e366734c5b8aab435fba579f5eada;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")), 50731626);
    }

    function test_replay_live_engine() public {
        vm.prank(HOT);
        IEngine(ENGINE).flashFillAndDraw(ORDER_ID, 4_500_000e6, LANDING, 0);
        (,,,,, uint8 status,,) = IFill(0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab).orders(ORDER_ID);
        assertEq(status, 2);
    }
}
