// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoA {
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

/// @notice ARM THE CREDIT LINE - post RSS collateral so $500k+ borrow is one tx when idle hits.
/// @dev Not a beg. Steakhouse parity: position inventory as Morpho collateral (token where it belongs).
///      Gates: KING_GO=1; FIRE_ARM=1 to broadcast.
///      Default posts 1_000_000 RSS (~$1M mark) => ~$700k+ soft borrow capacity @ 70% LTV.
contract FireArmCreditLine is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant DEFAULT_POST = 1_000_000 ether; // $1M Morpho mark
    uint256 constant SOFT_LTV_BPS = 7000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doFire = vm.envOr("FIRE_ARM", uint256(0)) == 1;
        uint256 postRss = vm.envOr("POST_RSS", DEFAULT_POST);

        IMorphoA.MarketParams memory mp = IMorphoA(MORPHO).idToMarketParams(MARKET_ID);
        require(mp.collateralToken == RSS && mp.loanToken == USDC, "market");

        uint256 bal = IERC20A(RSS).balanceOf(HOT);
        (, uint128 bor, uint128 coll) = IMorphoA(MORPHO).position(MARKET_ID, HOT);
        (uint128 supply,, uint128 borrowed,,,) = IMorphoA(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;

        uint256 capacity = ((uint256(coll) + postRss) * SOFT_LTV_BPS / 10_000) * 1e6 / 1e18; // USDC raw @ $1

        console2.log("=== ARM CREDIT LINE (Steakhouse posture) ===");
        console2.log("rssHot", bal);
        console2.log("collBefore", uint256(coll));
        console2.log("debtShares", uint256(bor));
        console2.log("postRss", postRss);
        console2.log("softCapacityUsdcApprox", capacity);
        console2.log("marketIdle", idle);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(bal >= postRss, "NEED FREE RSS");
        require(postRss >= 500_000 ether, "MIN 500k RSS");

        if (!doFire) {
            console2.log("PREFLIGHT OK - set FIRE_ARM=1 to post collateral");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        IERC20A(RSS).approve(MORPHO, postRss);
        IMorphoA(MORPHO).supplyCollateral(mp, postRss, HOT, "");
        vm.stopBroadcast();

        (, , uint128 collAfter) = IMorphoA(MORPHO).position(MARKET_ID, HOT);
        console2.log("collAfter", uint256(collAfter));
        console2.log("ARMED");
        console2.log("READY", uint256(1));
    }
}
