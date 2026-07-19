// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorpho {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IMorphoView {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Seed BRETT with $1 from hot USDC. Never drain wallets below $1.
contract SeedBrettOneUsdc is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    uint256 constant ONE_USDC = 1e6;
    uint256 constant FLOOR = 1e6; // always leave ≥ $1 on source wallet

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address king = vm.addr(pk);

        uint256 hotBal = IERC20(USDC).balanceOf(king);
        uint256 kvBal = IERC20(USDC).balanceOf(KING_VAULT);
        console2.log("hotUsdcBefore", hotBal);
        console2.log("kingVaultUsdc", kvBal);
        require(hotBal >= ONE_USDC + FLOOR, "NEED_2_USDC_KEEP_FLOOR");

        (uint256 brettBefore,,) = IMorphoView(MORPHO).position(BRETT_M, YRSS);
        console2.log("brettSharesBefore", brettBefore);

        vm.startBroadcast(pk);
        IERC20(USDC).approve(YRSS, ONE_USDC);
        uint256 shares = IMetaMorpho(YRSS).deposit(ONE_USDC, king);
        vm.stopBroadcast();

        (uint256 brettAfter,,) = IMorphoView(MORPHO).position(BRETT_M, YRSS);
        (uint128 bSup,,,,,) = IMorphoView(MORPHO).market(BRETT_M);
        console2.log("depositShares", shares);
        console2.log("brettSharesAfter", brettAfter);
        console2.log("brettMarketSupply", uint256(bSup));
        console2.log("hotUsdcAfter", IERC20(USDC).balanceOf(king));
        console2.log("yrssTotalAssets", IMetaMorpho(YRSS).totalAssets());
        require(IERC20(USDC).balanceOf(king) >= FLOOR, "FLOOR_HOT");
        require(IERC20(USDC).balanceOf(KING_VAULT) >= FLOOR, "FLOOR_KV");
    }
}
