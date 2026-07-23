// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkGateC {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy Access-Clause Elepan CDP (cold=Landing) on live multi-minter eUSD, then mint $13M.
/// @dev KING_GO=1 FIRE_COLD_MINT=1. Reuses eUSD 0xE8aA… — does not mint to hot.
///      On-chain: mint credits only immutable treasury; ColdMiss reverts debt open if credit fails.
contract FireElepanColdMint13M is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357; // cold wallet
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;

    uint256 constant LR = 1.5e18;
    uint256 constant FLOOR = 1.55e18;
    uint256 constant FEE_BPS = 500;
    uint256 constant MINT = 13_000_000 ether;
    uint256 constant COLL = 20_200_000e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_COLD_MINT", uint256(0)) == 1, "NEED FIRE_COLD_MINT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateC(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");
        require(IERC20C(ELEPAN).balanceOf(HOT) >= COLL, "ELEPAN_BAL");

        CrownElepanUsd eusd = CrownElepanUsd(EUSD);
        require(eusd.owner() == HOT, "EUSD_OWNER");

        uint256 landingBefore = eusd.balanceOf(LANDING);
        uint256 hotBefore = eusd.balanceOf(HOT);

        vm.startBroadcast(pk);

        CrownElepanCdpVault vault = new CrownElepanCdpVault(
            ELEPAN, EUSD, ORACLE, ZK_GATE, HOT, LANDING, LANDING, LR, FLOOR, FEE_BPS
        );
        require(vault.treasury() == LANDING, "TREASURY");
        require(vault.feeRecipient() == LANDING, "FEE_TO");

        eusd.setMinter(address(vault), true);

        IERC20C(ELEPAN).approve(address(vault), COLL);
        vault.deposit(COLL);
        // mintTo(cold) — wrong recipient reverts ColdMiss; cold credit failure reverts debt.
        vault.mintTo(LANDING, MINT);

        vm.stopBroadcast();

        uint256 landingAfter = eusd.balanceOf(LANDING);
        require(landingAfter >= landingBefore + MINT, "COLD_MISS_LANDING");
        require(eusd.balanceOf(HOT) == hotBefore, "HOT_MUST_NOT_RECEIVE");
        require(eusd.balanceOf(address(vault)) == 0, "VAULT_HOLD");
        require(vault.accruedDebt() >= MINT, "DEBT");
        require(vault.healthFactor() >= vault.safetyFloor(), "HF");

        console2.log("CDP", address(vault));
        console2.log("eUSD", EUSD);
        console2.log("cold", LANDING);
        console2.log("coll", vault.coll());
        console2.log("debt", vault.accruedDebt());
        console2.log("hf", vault.healthFactor());
        console2.log("landingEusd", landingAfter);
        console2.log("COLD_MINT_13M_OK", uint256(1));
    }
}
