// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssPodWrap} from "../src/peapods/CrownRssPodWrap.sol";
import {CrownFusdVault} from "../src/peapods/CrownFusdVault.sol";
import {CrownPeapodsPair} from "../src/peapods/CrownPeapodsPair.sol";
import {CrownPeapodsRssSelfLend} from "../src/peapods/CrownPeapodsRssSelfLend.sol";

interface IERC20P {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IUniV2FactoryP {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

/// @notice Peapods-exact self-lend fire on RSS/$1200 (Phase 1).
/// @dev KING_GO=1 FIRE_PEAPODS=1
///      L1 flash → L2 fUSDC → L3 wrap+LP → L5 coll → L6 borrow → L7 repay.
///      Equal USD legs at $1200/RSS via whole tokens: usdc = ASK_RSS * 1200e6
contract FirePeapodsRss1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    uint256 constant RSS_USD = 1200;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        bool doFire = vm.envOr("FIRE_PEAPODS", uint256(0)) == 1;
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 rssTokens = vm.envOr("ASK_RSS", uint256(834)); // whole RSS @ $1200
        uint256 rssAmt = rssTokens * 1e18;
        uint256 usdcAmt = rssTokens * RSS_USD * 1e6;

        require(IERC20P(RSS).balanceOf(HOT) >= rssAmt, "RSS_BAL");
        require(IERC20P(USDC).balanceOf(MORPHO) >= usdcAmt, "MORPHO_FLASH");

        console2.log("PLAYBOOK", "Peapods RSS/$1200 L1-L7");
        console2.log("usdcAmt", usdcAmt);
        console2.log("rssAmt", rssAmt);
        console2.log("rssUsd", RSS_USD);

        vm.startBroadcast(pk);

        CrownRssPodWrap pRss = CrownRssPodWrap(vm.envOr("PRSS", address(0)));
        if (address(pRss) == address(0)) {
            pRss = new CrownRssPodWrap(RSS, HOT);
            console2.log("pRSS", address(pRss));
        }

        CrownFusdVault vault = CrownFusdVault(vm.envOr("FUSDC", address(0)));
        if (address(vault) == address(0)) {
            vault = new CrownFusdVault(USDC, HOT);
            console2.log("fUSDC", address(vault));
        }

        address lp = IUniV2FactoryP(FACTORY).getPair(address(pRss), address(vault));
        if (lp == address(0)) {
            lp = IUniV2FactoryP(FACTORY).createPair(address(pRss), address(vault));
            console2.log("lpCreated", lp);
        } else {
            console2.log("lpExisting", lp);
        }

        CrownPeapodsPair pair = CrownPeapodsPair(vm.envOr("PAIR", address(0)));
        if (address(pair) == address(0)) {
            pair = new CrownPeapodsPair(address(vault), lp, HOT);
            vault.setPair(address(pair));
            console2.log("pair", address(pair));
        }

        CrownPeapodsRssSelfLend seeder = CrownPeapodsRssSelfLend(vm.envOr("SEEDER", address(0)));
        if (address(seeder) == address(0)) {
            seeder = new CrownPeapodsRssSelfLend(
                MORPHO, USDC, RSS, address(pRss), address(vault), address(pair), ROUTER, lp, HOT, HOT
            );
            console2.log("seeder", address(seeder));
        }

        if (IERC20P(RSS).allowance(HOT, address(seeder)) < rssAmt) {
            IERC20P(RSS).approve(address(seeder), type(uint256).max);
        }

        if (doFire) {
            seeder.selfLend(rssAmt, usdcAmt);
        }

        vm.stopBroadcast();

        console2.log("vaultCash", vault.cash());
        console2.log("vaultBorrows", vault.totalBorrows());
        console2.log("vaultAssets", vault.totalAssets());
        console2.log("pairDebt", pair.debt(HOT));
        console2.log("pairColl", pair.collateral(HOT));
        console2.log("utilBps", vault.totalAssets() == 0 ? 0 : (vault.totalBorrows() * 10_000) / vault.totalAssets());

        if (doFire) {
            require(vault.totalBorrows() >= usdcAmt - 1, "BORROW_MISS");
            require(pair.collateral(HOT) > 0, "COLL_MISS");
            console2.log("PEAPODS_RSS1200_OK", uint256(1));
        } else {
            console2.log("PEAPODS_RSS1200_PREP_OK", uint256(1));
        }
    }
}
