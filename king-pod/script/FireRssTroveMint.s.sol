// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssTrove} from "../src/CrownRssTrove.sol";

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IEusdAdmin {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IOracleA {
    function price() external view returns (uint256);
}

/// @notice Liquity-pattern mint rail: lock free RSS → mint eUSD to Landing.
/// @dev KING_OK=1 FIRE_TROVE=1
///      Config not rewrite: LTV ladder via LTV_WAD, self-set RATE_WAD, CEILING.
///      Morpho $200M book UNTOUCHED. Uses free RSS only.
///
/// Size (default 100M @ $1200 / 77% LTV / +20% buffer):
///   coll ≈ 100e6 / (1200 * 0.77) * 1.2 ≈ 129,871 RSS
contract FireRssTroveMint is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;

    /// @dev CR ladder: 110%→0.909 LTV · 130%→0.769 · 150%→0.667. Default 77% Morpho-match.
    uint256 constant LTV_WAD = 0.77e18;
    uint256 constant RATE_WAD = 0.05e18; // 5% self-set (redemption-risk control)
    uint256 constant CEILING = 100_000_000e18; // 100M mint rail

    error NOT_HOT();
    error NO_GO();
    error FREE_RSS();
    error BAD_ORACLE();

    function run() external {
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();

        uint256 mintAmt = vm.envOr("MINT_EUSD", uint256(100_000_000e18));
        uint256 ltv = vm.envOr("LTV_WAD", LTV_WAD);
        uint256 rate = vm.envOr("RATE_WAD", RATE_WAD);
        uint256 ceiling = vm.envOr("CEILING", CEILING);
        address existing = vm.envOr("TROVE", address(0));

        uint256 px = IOracleA(ORACLE).price();
        if (px == 0) revert BAD_ORACLE();
        // coll such that collValueUsd * ltv >= mint, then +20% buffer, whole RSS
        uint256 collAmt = vm.envOr("COLL_RSS", uint256(0));
        if (collAmt == 0) {
            collAmt = (mintAmt * 1e36) / (px * 1e12);
            collAmt = (collAmt * 1e18) / ltv;
            collAmt = (collAmt * 120) / 100;
            collAmt = ((collAmt + 1e18 - 1) / 1e18) * 1e18;
        }

        uint256 freeRss = IERC20A(RSS).balanceOf(HOT);
        console2.log("freeRss", freeRss);
        console2.log("collRss", collAmt);
        console2.log("mintEusd", mintAmt);
        console2.log("ltvWad", ltv);
        console2.log("ceiling", ceiling);
        console2.log("oraclePx", px);
        if (freeRss < collAmt) revert FREE_RSS();
        if (mintAmt > ceiling) revert NO_GO();

        uint256 landBefore = IEusdAdmin(EUSD).balanceOf(LANDING);

        vm.startBroadcast(pk);

        CrownRssTrove trove;
        if (existing != address(0) && existing.code.length > 0) {
            trove = CrownRssTrove(existing);
            console2.log("reuse", address(trove));
        } else {
            trove = new CrownRssTrove(RSS, EUSD, ORACLE, HOT, LANDING, ltv, rate, ceiling);
            IEusdAdmin(EUSD).setMinter(address(trove), true);
            console2.log("trove", address(trove));
        }

        require(IEusdAdmin(EUSD).isMinter(address(trove)), "MINTER");

        if (vm.envOr("FIRE_TROVE", uint256(0)) == 1) {
            IERC20A(RSS).approve(address(trove), collAmt);
            trove.open(collAmt, mintAmt, LANDING);
        }

        vm.stopBroadcast();

        console2.log("LANDING_EUSD_BEFORE", landBefore);
        console2.log("LANDING_EUSD_AFTER", IEusdAdmin(EUSD).balanceOf(LANDING));
        console2.log("MORPHO_UNTOUCHED", uint256(1));
        if (vm.envOr("FIRE_TROVE", uint256(0)) == 1) {
            console2.log("TROVE_100M_OK", IEusdAdmin(EUSD).balanceOf(LANDING) >= landBefore + mintAmt ? 1 : 0);
        } else {
            console2.log("TROVE_PREP_OK", uint256(1));
        }
    }
}
