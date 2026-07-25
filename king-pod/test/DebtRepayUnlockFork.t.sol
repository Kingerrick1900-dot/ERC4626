// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownDebtRepayUnlock} from "../src/CrownDebtRepayUnlock.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IVault {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract DebtRepayUnlockForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_live_unlock_clears_shares_net_dust() public {
        uint256 shares = IVault(YELE_K).balanceOf(HOT);
        uint256 assets = IVault(YELE_K).convertToAssets(shares);
        assertGt(shares, 0);
        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownDebtRepayUnlock h = new CrownDebtRepayUnlock(HOT, YELE_K);
        IERC20(YELE_K).approve(address(h), shares);
        h.unlock(assets, shares, HOT, HOT);
        vm.stopPrank();

        uint256 sharesLeft = IVault(YELE_K).balanceOf(HOT);
        uint256 usdc1 = IERC20(USDC).balanceOf(HOT);
        console2.log("sharesLeft", sharesLeft);
        console2.log("usdcDelta", usdc1 - usdc0);
        assertEq(sharesLeft, 0, "shares cleared");
        // matched ⇒ at most dust left after Morpho pulls flash
        assertLe(usdc1 - usdc0, 2e6);
    }
}
