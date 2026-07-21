// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZeroMorpho} from "../src/CrownZeroMorpho.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(IMorphoAuth.MarketParams memory) external;
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IYrssA {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

/// @notice Scribe-left ~$300 dust → ZERO. One tx: flash, repay all, free 500 RSS coll, yRSS covers flash.
/// @dev LIVE-FIRE-LAW: KING_OK=1 and FIRE_ZERO=1 to broadcast.
contract FireZeroMorphoDebt is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "need KING_OK=1");
        bool doFire = vm.envOr("FIRE_ZERO", uint256(0)) == 1;

        IMorphoAuth.MarketParams memory mp =
            IMorphoAuth.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IMorphoAuth(MORPHO).accrueInterest(mp);
        (uint256 supBefore, uint128 borBefore, uint128 collBefore) = IMorphoAuth(MORPHO).position(MID, HOT);
        (,, uint128 bA, uint128 bS,,) = IMorphoAuth(MORPHO).market(MID);
        uint256 debtBefore = bS == 0 ? 0 : (uint256(borBefore) * uint256(bA) + uint256(bS) - 1) / uint256(bS);

        console2.log("debtBeforeUsdc", debtBefore);
        console2.log("collBeforeRss", uint256(collBefore));
        console2.log("supSharesBefore", uint256(supBefore));
        console2.log("yrssAssetsKing", IYrssA(YRSS).convertToAssets(IYrssA(YRSS).balanceOf(HOT)));
        console2.log("hotUsdc", IERC20A(USDC).balanceOf(HOT));

        if (!doFire) {
            console2.log("DRY - set FIRE_ZERO=1 to broadcast");
            return;
        }

        uint256 rssBefore = IERC20A(RSS).balanceOf(HOT);
        vm.startBroadcast(pk);
        CrownZeroMorpho z = new CrownZeroMorpho(MORPHO, USDC, RSS, YRSS, HOT, MID, ORACLE, IRM, LLTV, HOT);
        IMorphoAuth(MORPHO).setAuthorization(address(z), true);
        IYrssA(YRSS).approve(address(z), type(uint256).max);
        IERC20A(USDC).approve(address(z), type(uint256).max);
        z.zeroBooks();
        vm.stopBroadcast();

        (, uint128 borAfter, uint128 collAfter) = IMorphoAuth(MORPHO).position(MID, HOT);
        console2.log("borSharesAfter", uint256(borAfter));
        console2.log("collAfterRss", uint256(collAfter));
        console2.log("rssGained", IERC20A(RSS).balanceOf(HOT) - rssBefore);
        console2.log("hotUsdcAfter", IERC20A(USDC).balanceOf(HOT));
        require(borAfter == 0 && collAfter == 0, "MORPHO NOT ZERO");
        console2.log("ZERO_OK", uint256(1));
    }
}
