// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256, uint256);
    function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IYrss {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract Probe is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function test_unwind() public {
        IMorpho morpho = IMorpho(MORPHO);
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);

        (uint256 sup, uint128 bor, uint128 coll) = morpho.position(MID, HOT);
        console2.log("sup", sup);
        console2.log("bor", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("maxW before", IYrss(YRSS).maxWithdraw(HOT));

        // Impersonate hot and try the unwind steps with deal/prank
        vm.startPrank(HOT);
        morpho.accrueInterest(mp);
        (,, uint128 tba, uint128 tbs,,) = morpho.market(MID);
        uint256 flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        flashAmt += 1000e6;
        console2.log("flashAmt", flashAmt);

        // Simulate callback body without actual flash: deal USDC to this script... use a helper contract
        vm.stopPrank();

        Unwind u = new Unwind();
        // fund u with flashAmt by dealing from morpho's balance conceptually
        deal(USDC, address(u), flashAmt);
        vm.prank(HOT);
        morpho.setAuthorization(address(u), true);
        vm.prank(HOT);
        IYrss(YRSS).approve(address(u), type(uint256).max);

        u.go(flashAmt, uint256(bor), uint256(coll));

        (, uint128 bor2, uint128 coll2) = morpho.position(MID, HOT);
        console2.log("borAfter", uint256(bor2));
        console2.log("collAfter", uint256(coll2));
        console2.log("rssHot", IERC20(RSS).balanceOf(HOT));
        console2.log("maxW after", IYrss(YRSS).maxWithdraw(HOT));
    }
}

contract Unwind {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function go(uint256 assets, uint256 borShares, uint256 coll) external {
        IMorpho morpho = IMorpho(MORPHO);
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IERC20(USDC).approve(MORPHO, type(uint256).max);

        console2.log("have0", IERC20(USDC).balanceOf(address(this)));
        morpho.repay(mp, 0, borShares, HOT, "");
        console2.log("have1 after repay", IERC20(USDC).balanceOf(address(this)));
        console2.log("maxW mid", IYrss(YRSS).maxWithdraw(HOT));
        (,, uint128 tba, , ,) = morpho.market(MID);
        console2.log("tba borrow after", uint256(tba));

        if (coll > 0) morpho.withdrawCollateral(mp, coll, HOT, HOT);

        uint256 have = IERC20(USDC).balanceOf(address(this));
        if (have < assets) {
            uint256 need = assets - have;
            uint256 maxW = IYrss(YRSS).maxWithdraw(HOT);
            console2.log("need", need);
            console2.log("maxW", maxW);
            if (maxW < need) {
                console2.log("SHORT would fire");
                // try withdrawing maxW anyway then redeem path
                if (maxW > 0) IYrss(YRSS).withdraw(maxW, address(this), HOT);
                console2.log("have after maxW pull", IERC20(USDC).balanceOf(address(this)));
            } else {
                IYrss(YRSS).withdraw(need, address(this), HOT);
                console2.log("yRSS withdraw ok");
            }
        }
        console2.log("final have", IERC20(USDC).balanceOf(address(this)));
        console2.log("rssHot", IERC20(RSS).balanceOf(HOT));
    }
}
