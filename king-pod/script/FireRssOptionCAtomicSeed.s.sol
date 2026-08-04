// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoC {
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
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

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

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @notice Option C atomic seed: lender-funded RSS market idle → post RSS → borrow USDC to Landing.
/// @dev Elepan never touched. Reverts unless idle ≥ ASK (lender commitment live onchain).
///      Supports ADD_BORROW=1 when hot already has Morpho debt (post more RSS + borrow ask).
///      Env: PRIVATE_KEY, ASK_USDC (6dp, default 500_000e6), COLL_RSS (18dp extra to post),
///      FIRE=1 to broadcast. Without FIRE, dry-run logs only.
contract FireRssOptionCAtomicSeed is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    // Elepan — explicit denylist; never approve / never supply
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    function run() external {
        uint256 ask = vm.envOr("ASK_USDC", uint256(500_000e6));
        require(ask >= 500_000e6 && ask <= 700_000e6, "ASK_RANGE");
        // Default extra coll for $500k @ ~70% buffer ≈ 715k RSS; use 800k cushion
        uint256 coll = vm.envOr("COLL_RSS", uint256(800_000 ether));
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        bool addBorrow = vm.envOr("ADD_BORROW", uint256(0)) == 1;

        IMorphoC.MarketParams memory mp = IMorphoC.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        uint256 rssHot = IERC20C(RSS).balanceOf(HOT);
        uint256 landingBefore = IERC20C(USDC).balanceOf(LANDING);
        (uint128 supply,, uint128 borrow,,,) = IMorphoC(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        (, uint128 borrowShares, uint128 posted) = IMorphoC(MORPHO).position(MARKET_ID, HOT);

        console2.log("=== OPTION C GATES ===");
        console2.log("RSS hot", rssHot);
        console2.log("coll to post (extra)", coll);
        console2.log("ask USDC", ask);
        console2.log("market idle", idle);
        console2.log("hot borrowShares", uint256(borrowShares));
        console2.log("hot coll posted", uint256(posted));
        console2.log("Landing USDC before", landingBefore);
        console2.log("Elepan (untouched)", IERC20C(ELEPAN).balanceOf(HOT));
        console2.log("ADD_BORROW", addBorrow ? 1 : 0);

        // Soft LTV: (posted + newColl) * 0.70 ≥ existingDebtApprox + ask
        // existingDebtApprox from market util on shares is messy; use 70% of total coll vs ask alone
        // when ADD_BORROW: require totalColl*0.70/1e12 ≥ ask + 700k buffer for live ~700k debt
        uint256 totalColl = uint256(posted) + coll;
        uint256 maxBorrow70 = (totalColl * 70) / 100 / 1e12;
        uint256 existingDebtBudget = addBorrow ? uint256(700_000e6) : 0;
        bool step2 = rssHot >= coll;
        bool step1 = idle >= ask;
        bool clean = borrowShares == 0;
        bool debtOk = addBorrow ? (borrowShares > 0) : clean;
        bool ltvOk = maxBorrow70 >= ask + existingDebtBudget;

        console2.log("step1 lender idle", step1 ? 1 : 0);
        console2.log("step2 rss authority", step2 ? 1 : 0);
        console2.log("debt gate ok", debtOk ? 1 : 0);
        console2.log("ltv ok", ltvOk ? 1 : 0);
        console2.log("maxBorrow70 totalColl", maxBorrow70);

        if (!fire) {
            console2.log(step1 && step2 && debtOk && ltvOk ? "DRY ARMED" : "DRY BLOCKED - fix failing gates");
            console2.log("DRY RUN - set FIRE=1 only when Step 1 lender idle is live");
            return;
        }

        require(step2, "RSS_SHORT");
        require(step1, "LENDER_IDLE_SHORT");
        require(debtOk, "DEBT_GATE");
        require(ltvOk, "LTV_SHORT");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);
        require(sender == HOT, "NOT_HOT_KEY");

        vm.startBroadcast(pk);
        require(IERC20C(RSS).approve(MORPHO, coll), "APPROVE");
        IMorphoC(MORPHO).supplyCollateral(mp, coll, HOT, "");
        IMorphoC(MORPHO).borrow(mp, ask, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 landingAfter = IERC20C(USDC).balanceOf(LANDING);
        console2.log("Landing USDC after", landingAfter);
        console2.log("Landing delta", landingAfter - landingBefore);
        require(landingAfter >= landingBefore + ask, "LANDING_SEED_FAIL");
        console2.log("OPTION_C_SEED_OK");
    }
}
