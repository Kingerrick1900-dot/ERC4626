// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssDutchBond} from "../src/CrownRssDutchBond.sol";

interface IERC20O {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoO {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function accrueInterest(MarketParams memory) external;
}

/// @notice STRIKE OPS — loop funds hot, hot arms 1M RSS, slashes Dutch, clears BRETT dust if funded.
/// @dev No Landing key. No fortress.
///      Phase 1: LOOP_PRIVATE_KEY → fund hot (USDC/ETH)
///      Phase 2: PRIVATE_KEY (hot) → Morpho + Dutch
///      KING_OK=1 KING_GO=1 FIRE_OPS=1
contract FireKingdomOps is Script {
    address constant OPS_LOOP = 0x8d3cfbFc6A276f118579517E4d166e94C66F8585;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    address constant DUTCH = 0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81;
    uint256 constant LLTV_BRETT = 625000000000000000;

    function run() external {
        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        require(vm.envOr("FIRE_OPS", uint256(0)) == 1, "FIRE_OPS");

        bool doFund = vm.envOr("DO_FUND", uint256(1)) == 1;
        bool doBrettZero = vm.envOr("DO_BRETT_ZERO", uint256(1)) == 1;
        bool doArm = vm.envOr("DO_ARM", uint256(1)) == 1;
        bool doSlash = vm.envOr("DO_SLASH", uint256(1)) == 1;

        uint256 postRss = vm.envOr("POST_RSS", uint256(1_000_000 ether));
        uint256 dutchFloor = vm.envOr("DUTCH_FLOOR", uint256(850_000));
        uint256 dutchCeil = vm.envOr("DUTCH_CEIL", uint256(990_000));
        uint256 dutchDur = vm.envOr("DUTCH_DURATION", uint256(7 days));
        uint256 hotUsdcTarget = vm.envOr("HOT_USDC_TARGET", uint256(10_000_000));
        uint256 loopUsdcFloor = vm.envOr("LOOP_USDC_FLOOR", uint256(1_000_000));
        uint256 fundEth = vm.envOr("FUND_ETH", uint256(0.001 ether));

        console2.log("=== KINGDOM STRIKE OPS ===");
        console2.log("hotUsdcBefore", IERC20O(USDC).balanceOf(HOT));
        console2.log("loopUsdc", IERC20O(USDC).balanceOf(OPS_LOOP));

        // Phase 1: Loop → Hot (OPS wallet — not Landing cold key)
        if (doFund) {
            uint256 loopPk = vm.envOr("LOOP_PRIVATE_KEY", uint256(0));
            if (loopPk != 0 && vm.addr(loopPk) == OPS_LOOP) {
                uint256 loopUsdc = IERC20O(USDC).balanceOf(OPS_LOOP);
                uint256 hotUsdc = IERC20O(USDC).balanceOf(HOT);
                uint256 sendUsdc;
                if (hotUsdc < hotUsdcTarget && loopUsdc > loopUsdcFloor) {
                    sendUsdc = hotUsdcTarget - hotUsdc;
                    uint256 avail = loopUsdc - loopUsdcFloor;
                    if (sendUsdc > avail) sendUsdc = avail;
                }
                uint256 sendEth;
                if (fundEth > 0 && OPS_LOOP.balance > fundEth + 0.0002 ether) {
                    sendEth = fundEth;
                }
                if (sendUsdc > 0 || sendEth > 0) {
                    vm.startBroadcast(loopPk);
                    if (sendUsdc > 0) IERC20O(USDC).transfer(HOT, sendUsdc);
                    if (sendEth > 0) {
                        (bool ok,) = HOT.call{value: sendEth}("");
                        require(ok, "ETH");
                    }
                    vm.stopBroadcast();
                    console2.log("loopFundUsdc", sendUsdc);
                    console2.log("loopFundEth", sendEth);
                } else {
                    console2.log("loopFundSkipped", uint256(1));
                }
            } else {
                console2.log("loopFundNeedKey", uint256(1));
            }
        }

        // Phase 2: Hot strike (one broadcast batch — use --slow on hot)
        vm.startBroadcast(hotPk);

        if (doArm) {
            IMorphoO.MarketParams memory rmp = IMorphoO(MORPHO).idToMarketParams(RSS77);
            (, uint128 rDebt, uint128 rColl) = IMorphoO(MORPHO).position(RSS77, HOT);
            if (rDebt == 0 && rColl == 0 && IERC20O(RSS).balanceOf(HOT) >= postRss) {
                IERC20O(RSS).approve(MORPHO, postRss);
                IMorphoO(MORPHO).supplyCollateral(rmp, postRss, HOT, "");
                console2.log("rssCollPosted", postRss);
            }
        }

        if (doSlash) {
            CrownRssDutchBond(DUTCH).armDutch(LANDING, dutchFloor, dutchCeil, dutchDur, 500_000e6, true);
            console2.log("dutchSlashedFloor", dutchFloor);
        }

        if (doBrettZero) {
            IMorphoO.MarketParams memory bmp =
                IMorphoO.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_BRETT);
            IMorphoO(MORPHO).accrueInterest(bmp);
            (, uint128 bShares,) = IMorphoO(MORPHO).position(BRETT_M, HOT);
            if (bShares > 0) {
                (,, uint128 bA, uint128 bS,,) = IMorphoO(MORPHO).market(BRETT_M);
                uint256 debt = (uint256(bShares) * uint256(bA) + uint256(bS) - 1) / uint256(bS);
                if (IERC20O(USDC).balanceOf(HOT) >= debt) {
                    IERC20O(USDC).approve(MORPHO, debt);
                    IMorphoO(MORPHO).repay(bmp, debt, 0, HOT, "");
                    console2.log("brettDebtRepaid", debt);
                }
            }
        }

        vm.stopBroadcast();

        (, uint128 bor77, uint128 coll77) = IMorphoO(MORPHO).position(RSS77, HOT);
        console2.log("hotUsdcAfter", IERC20O(USDC).balanceOf(HOT));
        console2.log("rss77Coll", uint256(coll77));
        console2.log("rss77DebtShares", uint256(bor77));
        console2.log("OPS_OK", uint256(1));
    }
}
