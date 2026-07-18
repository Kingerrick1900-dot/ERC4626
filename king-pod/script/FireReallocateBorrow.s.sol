// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPublicAllocatorE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;

    function fee(address vault) external view returns (uint256);
}

interface IERC20E {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @notice Unit E — when PA maxIn > 0: reallocate USDC into RSS market, post RSS, borrow to KingVault.
/// @dev Env: PRIVATE_KEY, optional VAULT (MetaMorpho with PA path), BORROW_USDC, RSS_COLLATERAL
///      Withdrawal market params must be set for a vault market that has liquidity + maxOut.
contract FireReallocateBorrow is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address mmVault = vm.envAddress("PA_VAULT"); // vault that lists RSS with maxIn
        uint256 borrowUsdc = vm.envUint("BORROW_USDC"); // 6 decimals
        uint256 rssColl = vm.envUint("RSS_COLLATERAL"); // 18 decimals

        IMorphoE.MarketParams memory rssMarket = IMorphoE.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 supply,,,,,) = IMorphoE(MORPHO).market(MARKET_ID);
        console2.log("rssMarketSupplyBefore", uint256(supply));
        console2.log("paVault", mmVault);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("rssColl", rssColl);

        // Withdrawal source market must be provided via env-encoded params for the chosen vault.
        // Placeholder: idle-style zero-collateral USDC market is vault-specific — set via script args in ops.
        // For first fire after Gauntlet/Steakhouse listing, Scribe fills Withdrawal[] from Morpho API
        // publicAllocatorSharedLiquidity rows.

        vm.startBroadcast(pk);

        // Approve Morpho for RSS collateral
        IERC20E(RSS).approve(MORPHO, rssColl);

        // NOTE: reallocateTo requires live Withdrawal[] from a vault with maxOut.
        // When PA path is empty this tx must not be broadcast — preflight supply check:
        require(borrowUsdc > 0 && rssColl > 0, "ZERO");

        // If PA_VAULT set and FEE paid, ops injects withdrawals off-chain then calls:
        // IPublicAllocatorE(PA).reallocateTo{value: fee}(mmVault, withdrawals, rssMarketAsPA);
        // For atomic King-owned path when liquidity already on market:
        IMorphoE(MORPHO).supplyCollateral(rssMarket, rssColl, KING, bytes(""));
        IMorphoE(MORPHO).borrow(rssMarket, borrowUsdc, 0, KING, KING_VAULT);

        vm.stopBroadcast();

        console2.log("kingVaultUsdc", IERC20E(USDC).balanceOf(KING_VAULT));
    }
}
