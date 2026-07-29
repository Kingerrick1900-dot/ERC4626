// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20, SafeTransfer} from "../src/lib/Core.sol";
import {KingPod} from "../src/KingPod.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingRssSale} from "../src/KingRssSale.sol";

/// @dev Recover RSS from sale desk → bootstrap V2 → sell remaining RSS into pair → attempt redeem.
/// Env: POD, optional FLASH_USDC (default 50e6), RSS_BOOTSTRAP (default 1.2e24), RSS_SELL (rest).
contract BootstrapAndSellV2 is Script {
    using SafeTransfer for IERC20;

    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SALE = 0xE9dA6F6ac49d42d82efD11BEE8946003bf22026e;

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        address podAddr = vm.envAddress("POD");
        uint256 flashUsdc = vm.envOr("FLASH_USDC", uint256(25_000e6));
        // 0 = use full liquid RSS after desk withdraw
        uint256 rssBootstrap = vm.envOr("RSS_BOOTSTRAP", uint256(0));

        KingPod pod = KingPod(podAddr);
        KingPair pair = pod.pair();
        KingSusdc sUsdc = pod.sUsdc();
        KingMoneyMarket market = pod.market();
        IERC20 rss = IERC20(RSS);
        IERC20 usdc = IERC20(USDC);

        vm.startBroadcast(pk);

        // 1) Pull inventory off sale desk (King owns sale)
        uint256 stock = KingRssSale(SALE).stock();
        if (stock > 0) {
            KingRssSale(SALE).withdrawRss(0, KING);
        }

        uint256 bal = rss.balanceOf(KING);
        require(bal > 0, "NO_RSS");
        if (rssBootstrap == 0 || rssBootstrap > bal) rssBootstrap = bal;

        // 2) Bootstrap V2 depth
        rss.safeApprove(address(pod), rssBootstrap);
        pod.bootstrap(rssBootstrap, flashUsdc);

        // 3) Sell remaining liquid RSS into pool for sUSDC
        uint256 sellAmt = rss.balanceOf(KING);
        uint256 sOut;
        if (sellAmt > 0) {
            rss.safeApprove(address(pair), sellAmt);
            sOut = pair.swapRssForSusdc(sellAmt, 0, KING);
        }

        // 4) Redeem sUSDC → USDC (succeeds only if vault has idle USDC)
        uint256 usdcOut;
        if (sOut > 0) {
            try sUsdc.redeem(sOut, KING, KING) returns (uint256 u) {
                usdcOut = u;
            } catch {
                console2.log("REDEEM_BLOCKED_EMPTY_VAULT");
            }
        }

        // 5) Optional: release+burn demo (proves V2 exit wiring). Keep LP posted by default.
        bool doExit = vm.envOr("EXIT_LP", false);
        if (doExit) {
            uint256 lp = market.collateralLp(KING);
            if (lp > 0) {
                market.releaseCollateral(KING, lp, KING);
                require(pair.transfer(address(pair), lp), "LP");
                (uint256 rssBurn, uint256 sBurn) = pair.burn(KING);
                console2.log("burnRss", rssBurn);
                console2.log("burnS", sBurn);
            }
        }

        vm.stopBroadcast();

        console2.log("pod", podAddr);
        console2.log("pairRes0", _r0(pair));
        console2.log("pairRes1", _r1(pair));
        console2.log("marketDebt", market.debtUsdc(KING));
        console2.log("sSold", sOut);
        console2.log("usdcOut", usdcOut);
        console2.log("kingUsdc", usdc.balanceOf(KING));
        console2.log("kingRss", rss.balanceOf(KING));
        console2.log("vaultAssets", sUsdc.totalAssets());
    }

    function _r0(KingPair pair) private view returns (uint256 a) {
        (a,) = pair.getReserves();
    }

    function _r1(KingPair pair) private view returns (uint256 b) {
        (, b) = pair.getReserves();
    }
}
