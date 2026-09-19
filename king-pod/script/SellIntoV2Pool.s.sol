// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20, SafeTransfer} from "../src/lib/Core.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";

interface IMorphoW {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @dev Pull Morpho RSS → sell into V2 pair → try redeem; optionally prove releaseCollateral.
contract SellIntoV2Pool is Script {
    using SafeTransfer for IERC20;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant LLTV = 770000000000000000;
    uint256 constant HF_FLOOR = 1005000000000000000;

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        address pairAddr = vm.envAddress("PAIR");
        address sUsdcAddr = vm.envAddress("SUSDC");
        address marketAddr = vm.envAddress("MARKET");
        bool proveExit = vm.envOr("PROVE_EXIT", true);

        KingPair pair = KingPair(pairAddr);
        KingSusdc sUsdc = KingSusdc(sUsdcAddr);
        KingMoneyMarket market = KingMoneyMarket(marketAddr);
        IERC20 rss = IERC20(RSS);
        IERC20 usdc = IERC20(USDC);

        IMorphoW.MarketParams memory params = IMorphoW.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        bytes32 marketId = keccak256(abi.encode(params));
        (,, uint128 collateral) = IMorphoW(MORPHO).position(marketId, KING);
        uint256 withdrawAmt = _maxWithdraw(collateral, marketId);

        vm.startBroadcast(pk);

        if (withdrawAmt > 0) {
            IMorphoW(MORPHO).withdrawCollateral(params, withdrawAmt, KING, KING);
        }

        uint256 sellAmt = rss.balanceOf(KING);
        uint256 sOut;
        if (sellAmt > 0) {
            rss.safeApprove(pairAddr, sellAmt);
            sOut = pair.swapRssForSusdc(sellAmt, 0, KING);
        }

        uint256 usdcOut;
        uint256 vault = sUsdc.totalAssets();
        if (sOut > 0 && vault > 0) {
            usdcOut = sUsdc.redeem(sOut, KING, KING);
        } else if (sOut > 0) {
            console2.log("REDEEM_BLOCKED_EMPTY_VAULT_sOut", sOut);
        }

        if (proveExit) {
            uint256 lp = market.collateralLp(KING);
            // Prove V2 releaseCollateral + burn wire. Does not mint wallet USDC while vault empty.
            uint256 slice = lp / 100;
            if (slice > 0) {
                market.releaseCollateral(KING, slice, KING);
                require(pair.transfer(pairAddr, slice), "LP");
                (uint256 rssBurn, uint256 sBurn) = pair.burn(KING);
                console2.log("proveExitRss", rssBurn);
                console2.log("proveExitS", sBurn);
                if (sBurn > 0 && sUsdc.totalAssets() > 0) {
                    console2.log("proveExitUsdc", sUsdc.redeem(sBurn, KING, KING));
                } else {
                    console2.log("PROVE_EXIT_REDEEM_EMPTY_VAULT");
                }
            }
        }

        vm.stopBroadcast();

        console2.log("morphoWithdraw", withdrawAmt);
        console2.log("sSold", sOut);
        console2.log("usdcOut", usdcOut);
        console2.log("kingUsdc", usdc.balanceOf(KING));
        console2.log("kingRss", rss.balanceOf(KING));
        console2.log("kingSUsdc", sUsdc.balanceOf(KING));
        console2.log("vaultAssets", sUsdc.totalAssets());
        console2.log("debt", market.debtUsdc(KING));
        console2.log("collLp", market.collateralLp(KING));
    }

    function _maxWithdraw(uint128 collateral, bytes32 marketId) internal view returns (uint256) {
        if (collateral == 0) return 0;
        (bool ok, bytes memory data) = ORACLE.staticcall(abi.encodeWithSignature("price()"));
        require(ok && data.length >= 32, "ORACLE");
        uint256 px = abi.decode(data, (uint256));
        (, uint128 borrowShares,) = IMorphoW(MORPHO).position(marketId, KING);
        if (borrowShares == 0) return collateral;
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = IMorphoW(MORPHO).market(marketId);
        uint256 borrowAssets =
            (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1) / uint256(totalBorrowShares);
        uint256 lo = 0;
        uint256 hi = collateral;
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 rem = uint256(collateral) - mid;
            uint256 collValue = (rem * px) / 1e36;
            uint256 maxBorrow = (collValue * LLTV) / 1e18;
            uint256 hf = (maxBorrow * 1e18) / borrowAssets;
            if (hf >= HF_FLOOR) lo = mid;
            else hi = mid - 1;
        }
        return lo;
    }
}
