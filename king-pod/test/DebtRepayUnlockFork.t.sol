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
    function maxWithdraw(address) external view returns (uint256);
}

interface IMorpho {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

contract DebtRepayUnlockForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_unlock_withdraws_freed_idle() public {
        uint256 shares0 = IVault(YELE_K).balanceOf(HOT);
        uint256 claim0 = IVault(YELE_K).convertToAssets(shares0);
        assertGt(shares0, 0);

        (uint256 vSupplyShares,,) = IMorpho(MORPHO).position(ELE77, YELE_K);
        (uint128 sa, uint128 ss,,,,) = IMorpho(MORPHO).market(ELE77);
        uint256 vaultEleAssets = (vSupplyShares * uint256(sa)) / uint256(ss);
        uint256 flash = vaultEleAssets > 2e6 ? vaultEleAssets - 2e6 : vaultEleAssets;

        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownDebtRepayUnlock h = new CrownDebtRepayUnlock(HOT, YELE_K);
        IERC20(YELE_K).approve(address(h), type(uint256).max);
        h.unlock(flash, HOT, HOT);
        vm.stopPrank();

        uint256 shares1 = IVault(YELE_K).balanceOf(HOT);
        uint256 claim1 = IVault(YELE_K).convertToAssets(shares1);
        uint256 usdc1 = IERC20(USDC).balanceOf(HOT);
        console2.log("claim0", claim0);
        console2.log("claim1", claim1);
        console2.log("shares0", shares0);
        console2.log("shares1", shares1);
        console2.log("usdcDelta", usdc1 - usdc0);
        // Matched: wallet USDC unchanged; share claim collapses toward 0
        assertLe(usdc1 - usdc0, 2e6);
        assertLt(claim1, 20e6, "claim should be residual dust");
    }
}
