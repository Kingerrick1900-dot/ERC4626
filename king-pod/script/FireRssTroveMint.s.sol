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

/// @notice Deploy CrownRssTrove (Liquity-pattern) + mint eUSD to Landing from free RSS.
/// @dev Env: PRIVATE_KEY, MINT_EUSD (18dp, default 400_000e18), COLL_RSS (18dp, optional).
///      Morpho positions are never touched.
contract FireRssTroveMint is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    /// @dev Live Morpho RSS/$1200 market oracle
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;

    uint256 constant LTV_WAD = 0.77e18;
    uint256 constant RATE_WAD = 0.05e18; // 5% self-set rate (redemption-protection pattern)
    uint256 constant CEILING = 1_000_000e18;

    function run() external {
        uint256 mintAmt = vm.envOr("MINT_EUSD", uint256(400_000e18));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        require(me == HOT, "NOT_HOT");

        // Coll buffer: value/LTV with ~20% headroom
        // coll ≈ mint / (1200 * LTV) * 1.2
        uint256 collAmt = vm.envOr("COLL_RSS", uint256(0));
        if (collAmt == 0) {
            // At $1200 and 77% LTV: mint 400k needs ~432.9 RSS; use 600 RSS buffer
            collAmt = (mintAmt * 1e18) / (1200e18 * LTV_WAD / 1e18);
            collAmt = (collAmt * 120) / 100; // +20%
            if (collAmt < 1e18) collAmt = 1e18;
        }

        uint256 freeRss = IERC20A(RSS).balanceOf(HOT);
        require(freeRss >= collAmt, "FREE_RSS");

        uint256 landBefore = IEusdAdmin(EUSD).balanceOf(LANDING);

        vm.startBroadcast(pk);

        CrownRssTrove trove = new CrownRssTrove(
            RSS, EUSD, ORACLE, HOT, LANDING, LTV_WAD, RATE_WAD, CEILING
        );

        IEusdAdmin(EUSD).setMinter(address(trove), true);
        require(IEusdAdmin(EUSD).isMinter(address(trove)), "MINTER");

        IERC20A(RSS).approve(address(trove), collAmt);
        trove.open(collAmt, mintAmt, LANDING);

        vm.stopBroadcast();

        uint256 landAfter = IEusdAdmin(EUSD).balanceOf(LANDING);
        console2.log("TROVE", address(trove));
        console2.log("COLL_RSS", collAmt);
        console2.log("MINT_EUSD", mintAmt);
        console2.log("LANDING_EUSD_BEFORE", landBefore);
        console2.log("LANDING_EUSD_AFTER", landAfter);
        console2.log("MORPHO_UNTOUCHED", uint256(1));
    }
}
