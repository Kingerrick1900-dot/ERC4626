// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoP5 {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function withdraw(
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

interface IERC20P5 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @notice PLAY 5 — Self-Supply Boost. supply(onBehalf) into RSS/USDC market.
/// @dev LOCKED: do not --broadcast until King OK / go.
/// Env: PRIVATE_KEY, SUPPLY_USDC (raw 6 decimals), ON_BEHALF (address),
///      optional PULL_AFTER=1 to withdraw same amount to RECEIVER (default KingVault).
contract FirePlay5SelfSupply is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
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
        uint256 supplyUsdc = vm.envUint("SUPPLY_USDC");
        address onBehalf = vm.envOr("ON_BEHALF", KING);
        bool pullAfter = vm.envOr("PULL_AFTER", uint256(0)) == 1;
        address receiver = vm.envOr("RECEIVER", KING_VAULT);

        require(supplyUsdc > 0, "ZERO");

        IMorphoP5.MarketParams memory mp = IMorphoP5.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 supplyBefore,, uint128 borrowBefore,,,) = IMorphoP5(MORPHO).market(MARKET_ID);
        console2.log("supplyBefore", uint256(supplyBefore));
        console2.log("borrowBefore", uint256(borrowBefore));
        console2.log("onBehalf", onBehalf);
        console2.log("supplyUsdc", supplyUsdc);
        console2.log("pullAfter", pullAfter);

        vm.startBroadcast(pk);
        IERC20P5(USDC).approve(MORPHO, supplyUsdc);
        IMorphoP5(MORPHO).supply(mp, supplyUsdc, 0, onBehalf, bytes(""));

        if (pullAfter) {
            IMorphoP5(MORPHO).withdraw(mp, supplyUsdc, 0, onBehalf, receiver);
        }
        vm.stopBroadcast();

        (uint128 supplyAfter,, uint128 borrowAfter,,,) = IMorphoP5(MORPHO).market(MARKET_ID);
        console2.log("supplyAfter", uint256(supplyAfter));
        console2.log("borrowAfter", uint256(borrowAfter));
        console2.log("vaultUsdc", IERC20P5(USDC).balanceOf(KING_VAULT));
    }
}
