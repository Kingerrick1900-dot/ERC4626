// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssBond} from "../src/CrownRssBond.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @dev Fork-prove bond rail: USDC buyer -> Landing, RSS out at discount.
contract RssBondForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function test_bond_usdc_to_landing() public {
        uint256 stock = 520_000 ether;
        uint256 buyUsdc = 100_000e6; // $100k sim fill

        vm.startPrank(HOT);
        CrownRssBond bond = new CrownRssBond(RSS, USDC, HOT, HOT);
        IERC20T(RSS).approve(address(bond), stock);
        bond.stock(stock);
        bond.arm(LANDING, 0.97e6, 500_000e6, true);
        vm.stopPrank();

        address buyer = makeAddr("buyer");
        deal(USDC, buyer, buyUsdc);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(buyer);
        IERC20T(USDC).approve(address(bond), buyUsdc);
        uint256 rssOut = bond.bondWithUsdc(buyUsdc);
        vm.stopPrank();

        assertEq(IERC20T(USDC).balanceOf(LANDING), landBefore + buyUsdc);
        assertEq(IERC20T(RSS).balanceOf(buyer), rssOut);
        assertEq(bond.raisedUsdc(), buyUsdc);
        console2.log("rssOut", rssOut / 1e18);
        console2.log("landingGain", buyUsdc / 1e6);
    }
}
