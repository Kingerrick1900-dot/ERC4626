// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

struct B3Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
    bytes32 callbackHash;
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

interface IBundler3Pack {
    function multicall(B3Call[] calldata bundle) external payable;
}

interface IGA1 {
    function erc20TransferFrom(address token, address receiver, uint256 amount) external;
    function morphoSupplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function morphoBorrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        uint256 minSharePriceE27,
        address receiver
    ) external;
}

interface IMorphoB3 {
    function isAuthorized(address authorizer, address authorized) external view returns (bool);

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

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}

interface IPublicAllocatorB3 {
    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function fee(address vault) external view returns (uint256);
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;
}

interface IERC20B3 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @notice Primary live executor: Morpho Bundler3 atomic pack → Landing USDC.
/// @dev R2 path: erc20TransferFrom(RSS) → morphoSupplyCollateral → morphoBorrow(Landing).
///      R3 path: optional PA.reallocateTo then same borrow (PA_VAULT + PULL_USDC).
///      Env: PRIVATE_KEY, ASK_USDC, COLL_RSS, FIRE=1, optional PA_VAULT/PULL_USDC.
///      Elepan denylist — never touched.
contract FireBundler3AtomicPack is Script {
    address constant BUNDLER3 = 0x6BFd8137e702540E7A42B74178A4a49Ba43920C4;
    address constant GA1 = 0xb98c948CFA24072e58935BC004a8A7b376AE746A;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant WETH_MARKET = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    function run() external {
        uint256 ask = vm.envOr("ASK_USDC", uint256(500_000e6));
        require(ask >= 500_000e6 && ask <= 700_000e6, "ASK_RANGE");
        uint256 coll = vm.envOr("COLL_RSS", uint256(800_000 ether));
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        address paVault = vm.envOr("PA_VAULT", address(0));
        uint256 pullUsdc = vm.envOr("PULL_USDC", uint256(0));

        MarketParams memory mp =
            MarketParams({loanToken: USDC, collateralToken: RSS, oracle: ORACLE, irm: IRM, lltv: LLTV});

        uint256 rssHot = IERC20B3(RSS).balanceOf(HOT);
        uint256 landingBefore = IERC20B3(USDC).balanceOf(LANDING);
        (uint128 supply,, uint128 borrow,,,) = IMorphoB3(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        (, uint128 borrowShares, uint128 posted) = IMorphoB3(MORPHO).position(MARKET_ID, HOT);
        bool auth = IMorphoB3(MORPHO).isAuthorized(HOT, GA1);
        uint256 allowGa1 = IERC20B3(RSS).allowance(HOT, GA1);

        console2.log("=== BUNDLER3 ATOMIC PACK ===");
        console2.log("Bundler3", BUNDLER3);
        console2.log("GA1", GA1);
        console2.log("ask", ask);
        console2.log("coll extra", coll);
        console2.log("idle", idle);
        console2.log("rss hot", rssHot);
        console2.log("posted", uint256(posted));
        console2.log("borrowShares", uint256(borrowShares));
        console2.log("ga1 authorized", auth ? 1 : 0);
        console2.log("rss allowance GA1", allowGa1);
        console2.log("Landing before", landingBefore);
        console2.log("Elepan untouched", IERC20B3(ELEPAN).balanceOf(HOT));

        uint256 effectiveIdle = idle;
        if (paVault != address(0) && pullUsdc > 0) {
            (uint128 maxIn,) = IPublicAllocatorB3(PA).flowCaps(paVault, MARKET_ID);
            console2.log("PA_VAULT", paVault);
            console2.log("PULL_USDC", pullUsdc);
            console2.log("PA maxIn", uint256(maxIn));
            require(maxIn >= pullUsdc, "PA_MAXIN_SHORT");
            effectiveIdle = idle + pullUsdc;
        }

        bool idleOk = effectiveIdle >= ask;
        bool rssOk = rssHot >= coll;
        uint256 debtBudget = borrowShares > 0 ? 700_000e6 : 0;
        bool ltvOk = ((uint256(posted) + coll) * 70) / 100 / 1e12 >= ask + debtBudget;

        console2.log("gate idleOk", idleOk ? 1 : 0);
        console2.log("gate rssOk", rssOk ? 1 : 0);
        console2.log("gate ltvOk", ltvOk ? 1 : 0);

        if (!fire) {
            console2.log(idleOk && rssOk && ltvOk && auth ? "DRY ARMED" : "DRY BLOCKED");
            console2.log("Set FIRE=1 to broadcast Bundler3 multicall");
            return;
        }

        require(idleOk, "IDLE_SHORT");
        require(rssOk, "RSS_SHORT");
        require(ltvOk, "LTV_SHORT");
        require(auth, "GA1_NOT_AUTH");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT_KEY");

        uint256 n = 3 + ((paVault != address(0) && pullUsdc > 0) ? 1 : 0);
        B3Call[] memory bundle = new B3Call[](n);
        uint256 idx;
        uint256 paFee;

        if (paVault != address(0) && pullUsdc > 0) {
            paFee = IPublicAllocatorB3(PA).fee(paVault);
            MarketParams memory wethMp = IMorphoB3(MORPHO).idToMarketParams(WETH_MARKET);
            IPublicAllocatorB3.Withdrawal[] memory withdrawals = new IPublicAllocatorB3.Withdrawal[](1);
            withdrawals[0] =
                IPublicAllocatorB3.Withdrawal({marketParams: wethMp, amount: uint128(pullUsdc)});
            bundle[idx++] = B3Call({
                to: PA,
                data: abi.encodeCall(IPublicAllocatorB3.reallocateTo, (paVault, withdrawals, mp)),
                value: paFee,
                skipRevert: false,
                callbackHash: bytes32(0)
            });
        }

        bundle[idx++] = B3Call({
            to: GA1,
            data: abi.encodeCall(IGA1.erc20TransferFrom, (RSS, GA1, coll)),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        bundle[idx++] = B3Call({
            to: GA1,
            data: abi.encodeCall(IGA1.morphoSupplyCollateral, (mp, coll, HOT, bytes(""))),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        bundle[idx++] = B3Call({
            to: GA1,
            data: abi.encodeCall(IGA1.morphoBorrow, (mp, ask, uint256(0), uint256(0), LANDING)),
            value: 0,
            skipRevert: false,
            callbackHash: bytes32(0)
        });

        require(idx == n, "BUNDLE_LEN");

        vm.startBroadcast(pk);
        if (allowGa1 < coll) {
            require(IERC20B3(RSS).approve(GA1, type(uint256).max), "APPROVE_GA1");
        }
        IBundler3Pack(BUNDLER3).multicall{value: paFee}(bundle);
        vm.stopBroadcast();

        uint256 landingAfter = IERC20B3(USDC).balanceOf(LANDING);
        console2.log("Landing after", landingAfter);
        console2.log("Landing delta", landingAfter - landingBefore);
        require(landingAfter >= landingBefore + ask, "LANDING_FAIL");
        console2.log("BUNDLER3_PACK_OK");
    }
}
