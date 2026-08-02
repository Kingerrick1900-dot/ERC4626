// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IVaultV2S {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address) external view returns (bool);
    function asset() external view returns (address);
    function liquidityAdapter() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function allocate(address adapter, bytes memory data, uint256 assets) external;
}

interface IMorphoS {
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

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice King's 7 steps — Vault V2 USDC → RSS market → borrow → Landing.
/// @dev Steps 1–5 already LIVE. This script verifies seats + optional deposit,
///      then DRAW posts RSS and borrows idle USDC to Landing (cold-or-revert).
///
/// KING_OK=1 FIRE_V2_SEVEN=1
/// DEPOSIT_USDC=... (optional top-up into vault; liquidityAdapter auto-routes)
/// DRAW=1 KING_GO=1 to borrow idle → Landing
contract FireVaultV2SevenSteps is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant V2 = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_V2_SEVEN", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // ——— STEP 1: Vault V2 USDC — curator/allocator ———
        require(IVaultV2S(V2).asset() == USDC, "NOT_USDC_VAULT");
        require(IVaultV2S(V2).curator() == HOT, "NOT_CURATOR");
        require(IVaultV2S(V2).isAllocator(HOT), "NOT_ALLOCATOR");
        console2.log("STEP1_vault", V2);
        console2.log("STEP1_curator_allocator", HOT);
        console2.log("STEP1_owner_landing", IVaultV2S(V2).owner());

        // ——— STEP 2–3: RSS/USDC market via liquidityAdapter ———
        address liq = IVaultV2S(V2).liquidityAdapter();
        require(liq == ADAPTER, "BAD_ADAPTER");
        console2.log("STEP2_3_liquidityAdapter", liq);
        console2.log("STEP2_3_rssMarket", uint256(RSS_M));
        console2.log("STEP2_3_marketWired", "RSS/USDC params set at deploy");

        IMorphoS.MarketParams memory mp = IMorphoS.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (uint128 supplyBefore,, uint128 borrowBefore,,,) = IMorphoS(MORPHO).market(RSS_M);
        uint256 idleBefore =
            uint256(supplyBefore) > uint256(borrowBefore) ? uint256(supplyBefore) - uint256(borrowBefore) : 0;
        console2.log("STEP5_marketIdleBefore", idleBefore);
        console2.log("STEP4_vaultSeedLive", "dead $1 deposit already on vault");

        uint256 depositAmt = vm.envOr("DEPOSIT_USDC", uint256(0));
        if (depositAmt > 0) {
            vm.startBroadcast(pk);
            uint256 hotBal = IERC20S(USDC).balanceOf(HOT);
            uint256 floor = vm.envOr("HOT_FLOOR", uint256(1e6));
            if (hotBal > floor) {
                uint256 maxDep = hotBal - floor;
                if (depositAmt > maxDep) depositAmt = maxDep;
            } else {
                depositAmt = 0;
            }
            if (depositAmt > 0) {
                IERC20S(USDC).approve(V2, depositAmt);
                IVaultV2S(V2).deposit(depositAmt, HOT);
                console2.log("STEP4_deposited", depositAmt);
            }
            vm.stopBroadcast();
        }

        (uint128 supply,, uint128 borrow,,,) = IMorphoS(MORPHO).market(RSS_M);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        console2.log("STEP5_marketIdleNow", idle);

        if (vm.envOr("DRAW", uint256(0)) != 1) {
            console2.log("STEPS_1_TO_5_LIVE", uint256(1));
            console2.log("SET_DRAW", "DRAW=1 KING_GO=1 to post RSS and borrow idle -> Landing");
            return;
        }

        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_KING_GO");
        require(idle > 0, "NO_IDLE");

        uint256 borrowAmt = vm.envOr("USDC_AMT", idle);
        if (borrowAmt > idle) borrowAmt = idle;
        // leave 1 wei unborrowed if full idle to avoid dust edge cases
        if (borrowAmt == idle && idle > 1) borrowAmt = idle - 1;

        uint256 rssColl = vm.envOr("RSS_COLL", uint256(1_000_000 ether));
        uint256 landBefore = IERC20S(USDC).balanceOf(LANDING);

        // ——— STEP 6–7: post RSS, borrow USDC → Landing ———
        vm.startBroadcast(pk);
        IERC20S(RSS).approve(MORPHO, rssColl);
        IMorphoS(MORPHO).supplyCollateral(mp, rssColl, HOT, "");
        IMorphoS(MORPHO).borrow(mp, borrowAmt, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 landAfter = IERC20S(USDC).balanceOf(LANDING);
        require(landAfter >= landBefore + borrowAmt, "LANDING_MISS");
        console2.log("STEP6_rssPosted", rssColl);
        console2.log("STEP7_usdcToLanding", landAfter - landBefore);
        console2.log("SEVEN_STEPS_OK", uint256(1));
    }
}
