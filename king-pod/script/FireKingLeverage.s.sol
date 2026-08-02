// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoL {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address) external view returns (bool);
    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function totalAssets() external view returns (uint256);
    function withdrawQueue(uint256) external view returns (bytes32);
    function withdrawQueueLength() external view returns (uint256);
}

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice TWO THINGS locked: (1) fees/yield to Landing (2) King sole governance.
///         Leverage: post RSS → borrow USDC → Landing. Cold miss = revert.
/// @dev KING_OK=1 FIRE_KING_LEVERAGE=1
///      DRAW=1 KING_GO=1 to borrow (requires Morpho RSS market idle ≥ USDC_AMT)
///      Default USDC_AMT = 500_000e6 (test size); set 700_000e6 for full ask.
contract FireKingLeverage is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant V2 = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant LLTV = 770000000000000000;
    uint96 constant FEE_10 = 0.1e18;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_KING_LEVERAGE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // ——— 1) FEES & YIELD ———
        uint96 fee = IMetaMorphoL(YRSS).fee();
        address feeTo = IMetaMorphoL(YRSS).feeRecipient();
        console2.log("yRssFeeWad", uint256(fee));
        console2.log("feeRecipient", feeTo);
        require(fee == FEE_10, "FEE_NOT_10PCT");
        require(feeTo == LANDING, "FEE_NOT_LANDING");

        // ——— 2) GOVERNANCE ———
        require(IMetaMorphoL(YRSS).owner() == HOT, "YRSS_OWNER");
        require(IMetaMorphoL(YRSS).curator() == HOT, "YRSS_CURATOR");
        require(IMetaMorphoL(YRSS).isAllocator(HOT), "YRSS_ALLOCATOR");
        console2.log("yRssGov", "King sole owner/curator/allocator");
        console2.log("vaultV2", V2);
        console2.log("yRssTvl", IMetaMorphoL(YRSS).totalAssets());

        (uint128 supply,, uint128 borrow,,,) = IMorphoL(MORPHO).market(RSS_M);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        console2.log("rssMarketIdle", idle);

        if (vm.envOr("DRAW", uint256(0)) != 1) {
            console2.log("SEATS_OK", "set DRAW=1 KING_GO=1 when vault USDC is in RSS market");
            return;
        }

        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
        uint256 usdcAmt = vm.envOr("USDC_AMT", uint256(500_000e6));
        uint256 rssColl = vm.envOr("RSS_COLL", uint256(1_000_000 ether)); // ~70% room at $1 / 77% LLTV for 700k
        require(idle >= usdcAmt, "NO_IDLE_IN_MARKET");

        IMorphoL.MarketParams memory mp = IMorphoL.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        uint256 landBefore = IERC20L(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);
        IERC20L(RSS).approve(MORPHO, rssColl);
        IMorphoL(MORPHO).supplyCollateral(mp, rssColl, HOT, "");
        IMorphoL(MORPHO).borrow(mp, usdcAmt, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 landAfter = IERC20L(USDC).balanceOf(LANDING);
        require(landAfter >= landBefore + usdcAmt, "LANDING_MISS");
        console2.log("coldGain", landAfter - landBefore);
        console2.log("LEVERAGE_OK", uint256(1));
    }
}
