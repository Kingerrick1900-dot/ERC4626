// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorphoVault {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
}

/// @notice Deposit USDC into King yRSS (fat curator vault). Env: PRIVATE_KEY, AMOUNT_USDC (raw 6dp).
contract DepositYrss is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        uint256 amount = vm.envUint("AMOUNT_USDC");
        require(amount > 0, "AMOUNT");

        uint256 bal = IERC20(USDC).balanceOf(me);
        console2.log("usdc", bal);
        require(bal >= amount, "BAL");

        vm.startBroadcast(pk);
        IERC20(USDC).approve(YRSS, amount);
        uint256 shares = IMetaMorphoVault(YRSS).deposit(amount, me);
        vm.stopBroadcast();

        console2.log("shares", shares);
        console2.log("vaultTotalAssets", IMetaMorphoVault(YRSS).totalAssets());
    }
}
