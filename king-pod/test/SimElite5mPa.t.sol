// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
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

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IPublicAllocatorS {
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

    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function fee(address vault) external view returns (uint256);
}

interface IMetaMorphoS {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
}

/// @notice Simulate the elite $5M yRSS PA maxIn cap — live engineering that has never been fired.
/// Path: seed yRSS idle market → PA.reallocateTo($5M) into RSS book → borrow $5M to HOT.
contract SimElite5mPaTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    // Elite PA target from ArmYrss* engineering (fixed $1 oracle RSS book)
    bytes32 constant RSS1 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant M41 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant ELITE_5M = 5_000_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_elite_5m_pa_cap_unused_path() public {
        (uint128 maxInRss1, uint128 maxOutRss1) = IPublicAllocatorS(PA).flowCaps(YRSS, RSS1);
        (uint128 maxIn41,) = IPublicAllocatorS(PA).flowCaps(YRSS, M41);
        (uint128 maxInIdle, uint128 maxOutIdle) = IPublicAllocatorS(PA).flowCaps(YRSS, IDLE);

        console2.log("elite maxIn RSS/$1", uint256(maxInRss1));
        console2.log("elite maxOut RSS/$1", uint256(maxOutRss1));
        console2.log("elite maxIn M41 $1200", uint256(maxIn41));
        console2.log("idle maxOut", uint256(maxOutIdle));

        assertEq(uint256(maxInRss1), ELITE_5M, "elite 5M maxIn on RSS/$1");
        assertEq(uint256(maxIn41), ELITE_5M, "elite 5M maxIn on M41");
        assertGe(uint256(maxOutIdle), ELITE_5M, "idle maxOut covers 5M");
        assertEq(uint256(maxInIdle), 50_000_000e6, "idle maxIn 50M buffer");

        // 1) Seed $5M liquid onto yRSS idle market (queue idle first)
        deal(USDC, HOT, ELITE_5M);
        bytes32[] memory q = new bytes32[](1);
        q[0] = IDLE;
        vm.prank(HOT);
        IMetaMorphoS(YRSS).setSupplyQueue(q);

        vm.startPrank(HOT);
        IERC20S(USDC).approve(YRSS, ELITE_5M);
        IMetaMorphoS(YRSS).deposit(ELITE_5M, HOT);
        vm.stopPrank();

        (uint256 idleShares,,) = IMorphoS(MORPHO).position(IDLE, YRSS);
        assertGt(idleShares, 0, "yRSS idle shares");
        console2.log("yRSS idle shares", idleShares);

        // 2) Fire the unused door: PA.reallocateTo IDLE → RSS/$1 for full $5M cap
        (address iLoan, address iColl, address iOracle, address iIrm, uint256 iLltv) =
            IMorphoS(MORPHO).idToMarketParams(IDLE);
        (address rLoan, address rColl, address rOracle, address rIrm, uint256 rLltv) =
            IMorphoS(MORPHO).idToMarketParams(RSS1);

        IPublicAllocatorS.Withdrawal[] memory w = new IPublicAllocatorS.Withdrawal[](1);
        w[0] = IPublicAllocatorS.Withdrawal({
            marketParams: IPublicAllocatorS.MarketParams({
                loanToken: iLoan, collateralToken: iColl, oracle: iOracle, irm: iIrm, lltv: iLltv
            }),
            amount: uint128(ELITE_5M)
        });

        (uint128 sBefore,, uint128 bBefore,,,) = IMorphoS(MORPHO).market(RSS1);
        uint256 idleBefore = uint256(sBefore) - uint256(bBefore);
        console2.log("RSS1 idle before PA", idleBefore);

        uint256 fee = IPublicAllocatorS(PA).fee(YRSS);
        // Permissionless — this is the elite door that was never used live
        IPublicAllocatorS(PA).reallocateTo{value: fee}(
            YRSS,
            w,
            IPublicAllocatorS.MarketParams({
                loanToken: rLoan, collateralToken: rColl, oracle: rOracle, irm: rIrm, lltv: rLltv
            })
        );

        (uint128 sAfter,, uint128 bAfter,,,) = IMorphoS(MORPHO).market(RSS1);
        uint256 idleAfter = uint256(sAfter) - uint256(bAfter);
        console2.log("RSS1 idle after PA", idleAfter);
        assertGe(idleAfter, ELITE_5M - 1e6, "PA delivered ~5M idle");

        // 3) Post RSS coll + borrow full $5M idle to HOT
        uint256 needColl = 7_000_000e18; // ask / 0.77 at $1 oracle with buffer
        deal(RSS, HOT, needColl);

        IMorphoS.MarketParams memory mp = IMorphoS.MarketParams({
            loanToken: rLoan, collateralToken: rColl, oracle: rOracle, irm: rIrm, lltv: rLltv
        });

        uint256 hotBefore = IERC20S(USDC).balanceOf(HOT);
        vm.startPrank(HOT);
        IERC20S(RSS).approve(MORPHO, needColl);
        IMorphoS(MORPHO).supplyCollateral(mp, needColl, HOT, "");
        (uint256 borrowed,) = IMorphoS(MORPHO).borrow(mp, ELITE_5M, 0, HOT, HOT);
        vm.stopPrank();

        console2.log("borrowed to HOT", borrowed);
        assertEq(borrowed, ELITE_5M, "full 5M borrow");

        uint256 hotAfter = IERC20S(USDC).balanceOf(HOT);
        console2.log("HOT USDC after", hotAfter);
        assertEq(hotAfter, hotBefore + ELITE_5M, "HOT receives full 5M");

        // Morpho PA flow caps are a spendable budget. Using the full $5M burns maxIn → 0.
        // That proves the elite door was unused before this sim (started at 5M, ended at 0).
        (uint128 maxInEnd, uint128 maxOutEnd) = IPublicAllocatorS(PA).flowCaps(YRSS, RSS1);
        console2.log("maxIn RSS1 after (budget spent)", uint256(maxInEnd));
        console2.log("maxOut RSS1 after", uint256(maxOutEnd));
        assertEq(uint256(maxInEnd), 0, "full 5M maxIn budget consumed");
        // Inflow credits maxOut by the same $5M (net-flow accounting) → 5M + 5M = 10M
        assertEq(uint256(maxOutEnd), 2 * ELITE_5M, "maxOut credited by the 5M inflow");

        console2.log("MISSION elite 5M PA cap simulated end-to-end");
    }
}
