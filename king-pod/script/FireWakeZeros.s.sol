// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20W {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoW {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYrssW {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;
}

/// @notice Wake kingdom zeros: yRSS TVL, Morpho RSS coll, BRETT/RSS market supply depth.
/// @dev KING_OK=1 FIRE_WAKE=1. Uses hot USDC -> yRSS -> reallocate. Posts RSS coll (default 1M).
contract FireWakeZeros is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant BRETT_ORACLE = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    uint256 constant LLTV_RSS = 770000000000000000;
    uint256 constant LLTV_BRETT = 625000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK=1");
        bool doFire = vm.envOr("FIRE_WAKE", uint256(0)) == 1;

        uint256 postRss = vm.envOr("POST_RSS", uint256(1_000_000 ether));
        uint256 usdcHot = IERC20W(USDC).balanceOf(HOT);
        uint256 yrssBefore = IYrssW(YRSS).totalAssets();
        (, uint128 borBefore, uint128 collBefore) = IMorphoW(MORPHO).position(RSS77, HOT);

        console2.log("=== WAKE ZEROS ===");
        console2.log("hotUsdc", usdcHot);
        console2.log("yrssTvlBefore", yrssBefore);
        console2.log("rssCollBefore", uint256(collBefore));
        console2.log("postRss", postRss);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        if (!doFire) {
            console2.log("DRY - set FIRE_WAKE=1");
            return;
        }

        require(postRss == 0 || IERC20W(RSS).balanceOf(HOT) >= postRss, "RSS");

        vm.startBroadcast(pk);

        // 1) Hot USDC -> yRSS (TVL off zero)
        if (usdcHot > 0) {
            IERC20W(USDC).approve(YRSS, usdcHot);
            IYrssW(YRSS).deposit(usdcHot, HOT);
        }

        // 2) Curator: push vault USDC into RSS77 + BRETT books (market supply off seed-only)
        IYrssW.MarketParams memory rssMp =
            IYrssW.MarketParams(USDC, RSS, RSS_ORACLE, IRM, LLTV_RSS);
        IYrssW.MarketParams memory brettMp =
            IYrssW.MarketParams(USDC, BRETT, BRETT_ORACLE, IRM, LLTV_BRETT);

        IYrssW.MarketAllocation[] memory allocs = new IYrssW.MarketAllocation[](2);
        allocs[0] = IYrssW.MarketAllocation({marketParams: rssMp, assets: type(uint256).max});
        allocs[1] = IYrssW.MarketAllocation({marketParams: brettMp, assets: type(uint256).max});
        IYrssW(YRSS).reallocate(allocs);

        // 3) Post RSS collateral when POST_RSS > 0 (skip if already armed)
        if (postRss > 0) {
            IMorphoW.MarketParams memory mp = IMorphoW(MORPHO).idToMarketParams(RSS77);
            IERC20W(RSS).approve(MORPHO, postRss);
            IMorphoW(MORPHO).supplyCollateral(mp, postRss, HOT, "");
        }

        vm.stopBroadcast();

        console2.log("yrssTvlAfter", IYrssW(YRSS).totalAssets());
        (, , uint128 collAfter) = IMorphoW(MORPHO).position(RSS77, HOT);
        console2.log("rssCollAfter", uint256(collAfter));
        (uint128 rssSup,,,,,) = IMorphoW(MORPHO).market(RSS77);
        (uint128 brettSup,,,,,) = IMorphoW(MORPHO).market(BRETT_M);
        console2.log("rssMarketSupply", uint256(rssSup));
        console2.log("brettMarketSupply", uint256(brettSup));
        console2.log("WAKE_OK", uint256(1));
    }
}
