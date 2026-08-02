// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldAttestSync} from "../src/scroll/CrownGoldAttestSync.sol";
import {CrownSpoilsDominion} from "../src/scroll/CrownSpoilsDominion.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IGateE {
    function attest(address, uint256) external;
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, bool);
    function owner() external view returns (address);
}

interface ICdpE {
    function deposit(uint256) external;
    function mintToLanding(uint256) external;
    function maxMintable() external view returns (uint256);
    function coll() external view returns (uint256);
    function debt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
}

interface ICreditE {
    function maxBorrow(address) external view returns (uint256);
    function lltv() external view returns (uint256);
}

interface ICompleterE {
    function maxAsk() external view returns (uint256);
}

/// @notice KING_GO=1 FIRE_SCROLL_GOLD_ENGINE=1 — gold attestation + CDP generate → Landing
/// @dev Scroll only. Base untouched. No Morpho. kXAU is the capacity + mint engine.
contract FireScrollGoldEngine is Script {
    uint256 constant SCROLL_CHAIN = 534352;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant SCROLL_LANDING = 0x3ebed6C1d15C11a009Dc711670ac1c7e5022e13f;
    address constant GATE = 0x777CCe01CbF472070b6c66dB2295b2d616171887;
    address constant CREDIT = 0x5c2511748a398AA7Fe144B44e0a433F5156A1368;
    address constant COMPLETER = 0x2cf08F8150f7E89c7323615016b0c4D2811266f6;
    address constant EUSD = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant SPOILS = 0x8E5ff2552f8fE0730E89dA7fBF1721f910615DcD;
    address constant GOLD = 0x156d912F37C179798D8396Da5d58919FA634262d;
    address constant ORACLE = 0xccB83516c5E9c557B9407ABF00865fe516B4a8c8;
    address constant GOLD_CDP = 0x6876E987F8C9d9e661068C610D9290Df41D4889f;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SCROLL_GOLD_ENGINE", uint256(0)) == 1, "NEED FIRE_SCROLL_GOLD_ENGINE=1");
        require(block.chainid == SCROLL_CHAIN, "NOT_SCROLL");

        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");
        require(IGateE(GATE).owner() == SCROLL_HOT, "GATE_OWNER");

        uint256 goldBefore = IERC20E(GOLD).balanceOf(SCROLL_HOT);
        uint256 landEusdBefore = IERC20E(EUSD).balanceOf(SCROLL_LANDING);
        console2.log("domain", "SCROLL_GOLD_ENGINE");
        console2.log("BASE_UNTOUCHED", uint256(1));
        console2.log("hotKxauBefore", goldBefore);
        console2.log("landingEusdBefore", landEusdBefore);

        vm.startBroadcast(pk);

        // 1) Gold capacity sync module (completer reads gate after sync)
        CrownGoldAttestSync syncer =
            new CrownGoldAttestSync(SCROLL_HOT, GATE, GOLD, ORACLE, GOLD_CDP);
        console2.log("goldAttestSync", address(syncer));
        console2.log("capacityBeforeDeposit", syncer.capacityUsdc6());

        // 2) Pre-sync: free kXAU sets gold-backed attestation
        uint256 cap0 = syncer.capacityUsdc6();
        IGateE(GATE).attest(SCROLL_HOT, cap0);
        console2.log("attestedCap0", cap0);
        console2.log("maxAsk0", ICompleterE(COMPLETER).maxAsk());

        // 3) Gold → eUSD: deposit all free kXAU, mint max to Landing
        uint256 dep = IERC20E(GOLD).balanceOf(SCROLL_HOT);
        require(dep > 0, "NO_GOLD");
        IERC20E(GOLD).approve(GOLD_CDP, dep);
        ICdpE(GOLD_CDP).deposit(dep);
        console2.log("depositedKxau", dep);

        uint256 mintAmt = ICdpE(GOLD_CDP).maxMintable();
        require(mintAmt > 0, "NO_MINT");
        ICdpE(GOLD_CDP).mintToLanding(mintAmt);
        console2.log("mintedEusdToLanding", mintAmt);

        // 4) Re-sync attestation from CDP-locked gold (same units, locked)
        uint256 cap1 = syncer.capacityUsdc6();
        IGateE(GATE).attest(SCROLL_HOT, cap1);
        console2.log("attestedCap1", cap1);

        // 5) Spoils accounting — gold engine spoil
        uint256 mintedUsdc6 = mintAmt / 1e12; // eUSD 18dp → USDC 6dp notional
        CrownSpoilsDominion(SPOILS).recordSpoil(mintedUsdc6, keccak256("GOLD_ENGINE_MINT"));
        CrownSpoilsDominion(SPOILS).setCapacity(cap1);

        vm.stopBroadcast();

        (uint256 th,, bool ok) = IGateE(GATE).attestations(SCROLL_HOT);
        console2.log("gateProven", IGateE(GATE).isProven(SCROLL_HOT) ? uint256(1) : uint256(0));
        console2.log("gateThreshold", th);
        console2.log("gateOk", ok ? uint256(1) : uint256(0));
        console2.log("completerMaxAsk", ICompleterE(COMPLETER).maxAsk());
        console2.log("cdpColl", ICdpE(GOLD_CDP).coll());
        console2.log("cdpDebt", ICdpE(GOLD_CDP).debt());
        console2.log("cdpHf", ICdpE(GOLD_CDP).healthFactor());
        console2.log("hotKxauAfter", IERC20E(GOLD).balanceOf(SCROLL_HOT));
        console2.log("landingEusdAfter", IERC20E(EUSD).balanceOf(SCROLL_LANDING));
        console2.log("SCROLL_GOLD_ENGINE_OK", uint256(1));
    }
}
