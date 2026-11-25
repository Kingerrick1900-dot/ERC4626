// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IVaultV {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IERC20V {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Controlled $1 vault deposit — verify shares, not scale.
/// @dev No loop. No exit. No reallocate. King gold is not a debug budget.
contract VerifyVaultDeposit is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    uint256 constant ONE_USD = 1e6;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        IVaultV v = IVaultV(YSYNTH);
        uint256 n = v.supplyQueueLength();
        for (uint256 i; i < n; ++i) {
            require(v.supplyQueue(i) != IDLE, "IDLE_IN_QUEUE");
        }

        uint256 assetsBefore = v.totalAssets();
        uint256 supplyBefore = v.totalSupply();
        uint256 balBefore = v.balanceOf(HOT);
        uint256 lastBefore = v.lastTotalAssets();
        uint256 hotUsdc = IERC20V(USDC).balanceOf(HOT);
        require(hotUsdc >= ONE_USD, "NEED_$1");

        console2.log("VERIFY", "vault-deposit-$1");
        console2.log("assetsBefore", assetsBefore);
        console2.log("supplyBefore", supplyBefore);
        console2.log("balBefore", balBefore);
        console2.log("lastBefore", lastBefore);
        console2.log("hotUsdcBefore", hotUsdc);

        vm.startBroadcast(pk);
        IERC20V(USDC).approve(YSYNTH, ONE_USD);
        uint256 shares = v.deposit(ONE_USD, HOT);
        vm.stopBroadcast();

        uint256 assetsAfter = v.totalAssets();
        uint256 supplyAfter = v.totalSupply();
        uint256 balAfter = v.balanceOf(HOT);
        uint256 lastAfter = v.lastTotalAssets();

        console2.log("sharesMinted", shares);
        console2.log("assetsAfter", assetsAfter);
        console2.log("supplyAfter", supplyAfter);
        console2.log("balAfter", balAfter);
        console2.log("lastAfter", lastAfter);
        console2.log("assetsDelta", assetsAfter - assetsBefore);
        console2.log("balDelta", balAfter - balBefore);
        console2.log("PASS_VAULT_HOLDS", balAfter > balBefore && assetsAfter > assetsBefore ? 1 : 0);
    }
}
