// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactETHForTokens(uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, Route[] calldata routes) external view returns (uint256[] memory amounts);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IYrssF {
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

    function totalAssets() external view returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;
}

interface IOracleF {
    function price() external view returns (uint256);
}

/// @notice Finish BRETT rail: yRSS USDC -> BRETT book, buy BRETT, post coll, borrow -> Landing.
/// @dev KING_OK=1 FIRE_BRETT_FINISH=1
contract FireFinishBrett is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant ORACLE_RSS = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant RSS91 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    uint256 constant LLTV_BRETT = 625000000000000000;
    uint256 constant LLTV_RSS91 = 915000000000000000;
    uint256 constant GAS_RESERVE = 0.00025 ether;
    uint256 constant SAFE_BORROW_BPS = 5000; // 50% of max LLTV headroom

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_BRETT_FINISH", uint256(0)) == 1, "FIRE_BRETT_FINISH");

        IMorphoF.MarketParams memory brettMp =
            IMorphoF.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_BRETT);

        (uint128 bSupBefore,, uint128 bBorBefore,,,) = IMorphoF(MORPHO).market(BRETT_M);
        uint256 idleBefore = bSupBefore > bBorBefore ? uint256(bSupBefore) - uint256(bBorBefore) : 0;
        console2.log("brettIdleBefore", idleBefore);
        console2.log("yrssTvl", IYrssF(YRSS).totalAssets());

        vm.startBroadcast(pk);

        // 1) Move yRSS USDC from RSS91 -> BRETT book (lender idle for borrow)
        IYrssF.MarketParams memory rss91Mp =
            IYrssF.MarketParams(USDC, 0x7a305D07B537359cf468eAea9bb176E5308bC337, ORACLE_RSS, IRM, LLTV_RSS91);
        IYrssF.MarketParams memory brettYrssMp =
            IYrssF.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_BRETT);

        IYrssF.MarketAllocation[] memory moves = new IYrssF.MarketAllocation[](2);
        moves[0] = IYrssF.MarketAllocation({marketParams: rss91Mp, assets: 0});
        moves[1] = IYrssF.MarketAllocation({marketParams: brettYrssMp, assets: type(uint256).max});
        IYrssF(YRSS).reallocate(moves);

        // 2) ETH -> BRETT (Aerodrome)
        uint256 ethBal = HOT.balance;
        require(ethBal > GAS_RESERVE + 0.00005 ether, "ETH_LOW");
        uint256 swapEth = ethBal - GAS_RESERVE;

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: WETH, to: BRETT, stable: false, factory: AERO_FACTORY});
        uint256[] memory quoted = IAeroRouter(AERO).getAmountsOut(swapEth, routes);
        uint256 minOut = (quoted[1] * 90) / 100;
        IAeroRouter(AERO).swapExactETHForTokens{value: swapEth}(minOut, routes, HOT, block.timestamp + 20 minutes);
        uint256 brettBal = IERC20F(BRETT).balanceOf(HOT);
        console2.log("brettBought", brettBal);
        require(brettBal > 0, "NO_BRETT");

        // 3) Post BRETT collateral
        IERC20F(BRETT).approve(MORPHO, brettBal);
        IMorphoF(MORPHO).supplyCollateral(brettMp, brettBal, HOT, "");

        // 4) Borrow USDC -> Landing (min of idle, safe LTV)
        (bSupBefore,, bBorBefore,,,) = IMorphoF(MORPHO).market(BRETT_M);
        uint256 idle = uint256(bSupBefore) > uint256(bBorBefore) ? uint256(bSupBefore) - uint256(bBorBefore) : 0;

        uint256 px = IOracleF(ORACLE_BRETT).price();
        uint256 collUsd = (brettBal * px) / 1e36;
        uint256 maxBorrow = (collUsd * LLTV_BRETT) / 1e18;
        uint256 wantBorrow = (maxBorrow * SAFE_BORROW_BPS) / 10_000;
        if (wantBorrow > idle) wantBorrow = idle;
        require(wantBorrow > 0, "NO_BORROW");

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        IMorphoF(MORPHO).borrow(brettMp, wantBorrow, 0, HOT, LANDING);
        uint256 landGain = IERC20F(USDC).balanceOf(LANDING) - landBefore;

        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoF(MORPHO).position(BRETT_M, HOT);
        console2.log("brettCollPosted", uint256(coll));
        console2.log("brettDebtUsdc", uint256(bor));
        console2.log("landingGain", landGain);
        console2.log("BRETT_FINISH_OK", uint256(1));
    }
}
