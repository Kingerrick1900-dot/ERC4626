// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20Y {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IEusdY {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoY {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function supplyCollateral(MarketParams memory m, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256);
}

interface IMetaMorphoY {
    function setWithdrawQueue(bytes32[] calldata ids) external;
    function withdrawQueue(uint256) external view returns (bytes32);
    function withdrawQueueLength() external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}

/// @notice NEVER-DONE idle-in-yRSS from code alone. See deployments/SIM-YRSS-IDLE-FROM-CODE.md
contract SimYrssIdleFromCodeTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    bytes32 constant EUSD_MKT = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;
    uint256 constant ASK = 5_000_000e6;

    uint256 public midMaxWithdraw;
    uint256 public midIdleShares;
    uint256 public midTotalAssets;
    uint8 public flashMode;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_fine_print_idle_withdraw_queue_king_control() public {
        bool had = _queueHasIdle();
        if (!had) {
            console2.log("FINE PRINT: IDLE absent from withdrawQueue (strand trap live)");
            _addIdleToWithdrawQueue();
            console2.log("King favor: added IDLE via timelock 0");
        } else {
            console2.log("FINE PRINT: IDLE already on withdrawQueue (trap closed)");
        }
        assertTrue(_queueHasIdle(), "IDLE must be withdrawable for engineered idle to exit");
    }

    function test_yrss_idle_from_morpho_flash_onBehalf_no_deal() public {
        _addIdleToWithdrawQueue();
        uint256 assetsBefore = IMetaMorphoY(YRSS).totalAssets();
        uint256 hotBefore = IERC20Y(USDC).balanceOf(HOT);
        console2.log("totalAssets before", assetsBefore);

        flashMode = 1;
        IMorphoY(MORPHO).flashLoan(USDC, ASK, hex"");

        assertGe(midMaxWithdraw, ASK, "maxWithdraw opened");
        assertGe(midIdleShares, 1, "idle shares");
        assertGe(midTotalAssets, assetsBefore + ASK - 1e6, "TVL rose w/o ERC4626 deposit");
        assertEq(IERC20Y(USDC).balanceOf(HOT), hotBefore, "unwind flat");
        console2.log("mid maxWithdraw", midMaxWithdraw);
        console2.log("mid idle shares", midIdleShares);
        console2.log("mid totalAssets", midTotalAssets);
        console2.log("MISSION yRSS idle from flash+onBehalf (no deal USDC)");
    }

    function test_yrss_permanent_inventory_via_eusd_mint_flash() public {
        assertTrue(IEusdY(EUSD).isMinter(HOT), "King eUSD minter");
        uint256 assetsBefore = IMetaMorphoY(YRSS).totalAssets();
        (uint256 posBefore,,) = IMorphoY(MORPHO).position(EUSD_MKT, YRSS);

        flashMode = 2;
        IMorphoY(MORPHO).flashLoan(USDC, ASK, hex"");

        (uint256 posAfter,,) = IMorphoY(MORPHO).position(EUSD_MKT, YRSS);
        uint256 assetsAfter = IMetaMorphoY(YRSS).totalAssets();
        console2.log("eUSD-mkt shares before", posBefore);
        console2.log("eUSD-mkt shares after", posAfter);
        console2.log("totalAssets before", assetsBefore);
        console2.log("totalAssets after", assetsAfter);

        assertGt(posAfter, posBefore, "yRSS gained Morpho USDC inventory");
        assertGe(assetsAfter, assetsBefore + ASK - 1e6, "TVL grew without USDC deal");
        console2.log("MISSION permanent yRSS inventory via eUSD mint + flash onBehalf");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO, "MORPHO");
        if (flashMode == 1) _callbackIdleUnwind(assets);
        else if (flashMode == 2) _callbackEusdBootstrap(assets);
        else revert("MODE");
    }

    function _callbackIdleUnwind(uint256 assets) internal {
        IERC20Y(USDC).approve(MORPHO, assets);
        IMorphoY.MarketParams memory mp = _params(IDLE);
        IMorphoY(MORPHO).supply(mp, assets, 0, YRSS, "");
        (midIdleShares,,) = IMorphoY(MORPHO).position(IDLE, YRSS);
        midMaxWithdraw = IMetaMorphoY(YRSS).maxWithdraw(HOT);
        midTotalAssets = IMetaMorphoY(YRSS).totalAssets();
        require(midIdleShares > 0 && midMaxWithdraw >= assets, "IDLE_NOT_ENGINEERED");
        vm.prank(HOT);
        IMetaMorphoY(YRSS).withdraw(assets, address(this), HOT);
        IERC20Y(USDC).approve(MORPHO, assets);
    }

    function _callbackEusdBootstrap(uint256 assets) internal {
        IERC20Y(USDC).approve(MORPHO, type(uint256).max);
        IMorphoY.MarketParams memory mp = _params(EUSD_MKT);
        IMorphoY(MORPHO).supply(mp, assets, 0, YRSS, "");

        uint256 collAmt = assets * 2e12;
        vm.prank(HOT);
        IEusdY(EUSD).mint(HOT, collAmt);

        vm.startPrank(HOT);
        IEusdY(EUSD).approve(MORPHO, collAmt);
        IMorphoY(MORPHO).supplyCollateral(mp, collAmt, HOT, "");
        IMorphoY(MORPHO).borrow(mp, assets, 0, HOT, address(this));
        vm.stopPrank();
        IERC20Y(USDC).approve(MORPHO, assets);
    }

    function _params(bytes32 id) internal view returns (IMorphoY.MarketParams memory mp) {
        (address a, address b, address c, address d, uint256 e) = IMorphoY(MORPHO).idToMarketParams(id);
        mp = IMorphoY.MarketParams({loanToken: a, collateralToken: b, oracle: c, irm: d, lltv: e});
    }

    function _queueHasIdle() internal view returns (bool found) {
        uint256 n = IMetaMorphoY(YRSS).withdrawQueueLength();
        for (uint256 i; i < n; i++) {
            if (IMetaMorphoY(YRSS).withdrawQueue(i) == IDLE) return true;
        }
    }

    function _addIdleToWithdrawQueue() internal {
        if (_queueHasIdle()) return;
        uint256 n = IMetaMorphoY(YRSS).withdrawQueueLength();
        bytes32[] memory q = new bytes32[](n + 1);
        for (uint256 i; i < n; i++) {
            q[i] = IMetaMorphoY(YRSS).withdrawQueue(i);
        }
        q[n] = IDLE;
        vm.prank(HOT);
        IMetaMorphoY(YRSS).setWithdrawQueue(q);
    }
}
