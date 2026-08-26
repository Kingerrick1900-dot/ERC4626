// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

/// @notice Migrate: free RSS from $1200 → post on $50k AMO book.
/// Uses Landing withdraw buffer (not more borrow) so repay clears.
contract FireMigrate50k is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant ORACLE1200 = 0x4153669Cc3671B6b8b68D47Fd852Ad1a48b950e0;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    bytes32 constant MID1200 = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;
    bytes32 constant MID50 = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MIGRATE", uint256(0)) == 1, "NEED FIRE_MIGRATE=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");
        uint256 landPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);

        IMorphoM.MarketParams memory mp1200 = IMorphoM.MarketParams({
            loanToken: EUSD, collateralToken: RSS, oracle: ORACLE1200, irm: IRM, lltv: LLTV
        });
        IMorphoM.MarketParams memory mp50 = IMorphoM.MarketParams({
            loanToken: EUSD, collateralToken: RSS, oracle: ORACLE50, irm: IRM, lltv: LLTV
        });

        // A) Unwrap gUSD
        vm.startBroadcast(hotPk);
        uint256 gBal = CrownGoldUsd(GUSD).balanceOf(HOT);
        if (gBal > 0) {
            CrownGoldUsd(GUSD).unwrap(gBal, HOT);
            console2.log("unwrappedGusd", gBal);
        }
        vm.stopBroadcast();

        // B) Landing withdraws repay buffer to HOT (does NOT increase debt)
        uint256 buf = vm.envOr("REPAY_BUF", uint256(50_000e18));
        vm.startBroadcast(landPk);
        IMorphoM(MORPHO).accrueInterest(mp1200);
        IMorphoM(MORPHO).withdraw(mp1200, buf, 0, LANDING, HOT);
        console2.log("landWithdrawToHot", buf);
        vm.stopBroadcast();

        // C) HOT: repay all debt shares, withdraw all coll, leave Landing supply for later recall
        vm.startBroadcast(hotPk);
        IMorphoM(MORPHO).accrueInterest(mp1200);
        (, uint128 borShares, uint128 coll) = IMorphoM(MORPHO).position(MID1200, HOT);
        uint256 hotBal = IERC20M(EUSD).balanceOf(HOT);
        console2.log("hotBal", hotBal);
        console2.log("borShares", uint256(borShares));

        IERC20M(EUSD).approve(MORPHO, type(uint256).max);
        (uint256 repaid,) = IMorphoM(MORPHO).repay(mp1200, 0, borShares, HOT, "");
        console2.log("repaid", repaid);
        (, uint128 borAfter,) = IMorphoM(MORPHO).position(MID1200, HOT);
        require(borAfter == 0, "DEBT_LEFT");

        IMorphoM(MORPHO).withdrawCollateral(mp1200, coll, HOT, HOT);
        console2.log("rssFreed", IERC20M(RSS).balanceOf(HOT));
        vm.stopBroadcast();

        // D) Landing recalls remaining 1200 supply to self
        vm.startBroadcast(landPk);
        (uint256 supShares,,) = IMorphoM(MORPHO).position(MID1200, LANDING);
        if (supShares > 0) {
            IMorphoM(MORPHO).withdraw(mp1200, 0, supShares, LANDING, LANDING);
        }
        uint256 landEusd = IERC20M(EUSD).balanceOf(LANDING);
        console2.log("landEusd", landEusd);
        // Any dust eUSD on HOT from over-buffer → Landing
        vm.stopBroadcast();

        vm.startBroadcast(hotPk);
        uint256 dust = IERC20M(EUSD).balanceOf(HOT);
        if (dust > 0) {
            IERC20M(EUSD).transfer(LANDING, dust);
            console2.log("dustToLand", dust);
        }

        // E) Deploy $50k AMO + Exit
        CrownSovereignAmo amo50 = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, GATE, HOT, LANDING, MID50, ORACLE50, IRM, LLTV, LANDING
        );
        CrownSovereignExit exit50 = new CrownSovereignExit(
            MORPHO, EUSD, RSS, HOT, LANDING, MID50, ORACLE50, IRM, LLTV, HOT
        );
        console2.log("amo50", address(amo50));
        console2.log("exit50", address(exit50));
        IMorphoM(MORPHO).setAuthorization(address(amo50), true);
        IMorphoM(MORPHO).setAuthorization(address(exit50), true);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        amo50.setRequireGate(false);
        IMorphoM(MORPHO).setAuthorization(address(exit50), true);
        landEusd = IERC20M(EUSD).balanceOf(LANDING);
        IERC20M(EUSD).approve(address(amo50), landEusd);
        vm.stopBroadcast();

        // F) Fire $50k book
        vm.startBroadcast(hotPk);
        amo50.supplyAmo(LANDING, landEusd);
        console2.log("supplied50", landEusd);
        console2.log("idle50", amo50.idle());

        IERC20M(RSS).approve(address(amo50), type(uint256).max);
        amo50.postCollateral(0);

        uint256 idle = amo50.idle();
        // Borrow 90% of idle — LTV at $50k is not the constraint
        uint256 borrowAsk = idle * 90 / 100;
        amo50.borrowEusd(borrowAsk, HOT);
        console2.log("borrowed50", borrowAsk);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        amo50.setRequireGate(true);
        vm.stopBroadcast();

        (, uint128 b50, uint128 c50) = IMorphoM(MORPHO).position(MID50, HOT);
        (uint256 s50,,) = IMorphoM(MORPHO).position(MID50, LANDING);
        console2.log("supShares50", s50);
        console2.log("borShares50", uint256(b50));
        console2.log("coll50", uint256(c50));
        console2.log("hotEusd", IERC20M(EUSD).balanceOf(HOT));
        console2.log("idleFinal", amo50.idle());
        console2.log("MIGRATE_50K_OK", uint256(1));
    }
}
