// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20, SafeTransfer} from "../src/lib/Core.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingSusdc} from "../src/KingSusdc.sol";

/// @dev Burn KingPair LP (via market.releaseCollateral) → sUSDC → USDC → repay market debt.
/// forge script script/ExitKingLp.s.sol:ExitKingLp --rpc-url $BASE_RPC --broadcast --legacy
contract ExitKingLp is Script {
    using SafeTransfer for IERC20;

    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant SUSDC = 0x4af86Ac17Eb6F12588b2f3B70969f304933d1021;
    address constant PAIR = 0x56EbFC0Af28E1a9D8e6F9d0F3262ff1ad1a78F8c;
    address constant MARKET = 0x50A61cA6b06563f1A44f7F2186A325b5301e2578;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        uint256 lpExit = vm.envOr("LP_EXIT", uint256(0)); // 0 = full collateral
        bool repayDebt = vm.envOr("REPAY_DEBT", true);

        KingMoneyMarket market = KingMoneyMarket(MARKET);
        KingPair pair = KingPair(PAIR);
        KingSusdc sUsdc = KingSusdc(SUSDC);
        IERC20 usdc = IERC20(USDC);
        IERC20 rss = IERC20(RSS);

        uint256 coll = market.collateralLp(KING);
        if (lpExit == 0 || lpExit > coll) lpExit = coll;
        require(lpExit > 0, "NO_LP");

        console2.log("lpExit", lpExit);
        console2.log("debtBefore", market.debtUsdc(KING));

        vm.startBroadcast(pk);

        market.releaseCollateral(KING, lpExit, KING);
        require(pair.transfer(address(pair), lpExit), "LP_TO_PAIR");

        (uint256 rssOut, uint256 sOut) = pair.burn(KING);
        uint256 usdcOut = sUsdc.redeem(sOut, KING, KING);

        if (repayDebt) {
            uint256 debt = market.debtUsdc(KING);
            if (debt > 0) {
                uint256 repayAmt = usdcOut < debt ? usdcOut : debt;
                usdc.safeApprove(MARKET, repayAmt);
                market.repay(repayAmt);
            }
        }

        vm.stopBroadcast();

        console2.log("rssOut", rssOut);
        console2.log("sOut", sOut);
        console2.log("usdcOut", usdcOut);
        console2.log("kingUsdc", usdc.balanceOf(KING));
        console2.log("kingRss", rss.balanceOf(KING));
        console2.log("debtAfter", market.debtUsdc(KING));
        console2.log("collAfter", market.collateralLp(KING));
    }
}
