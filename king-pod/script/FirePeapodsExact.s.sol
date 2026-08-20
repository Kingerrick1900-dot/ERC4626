// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPodWrap} from "../src/peapods/CrownPodWrap.sol";
import {CrownFusdVault} from "../src/peapods/CrownFusdVault.sol";
import {CrownPeapodsPair} from "../src/peapods/CrownPeapodsPair.sol";
import {CrownPeapodsSelfLend} from "../src/peapods/CrownPeapodsSelfLend.sol";

interface IERC20P {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IUniV2FactoryP {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

/// @notice Peapods-exact self-lend fire on Base.
/// @dev KING_GO=1 FIRE_PEAPODS=1
///      L1 flash → L2 fUSDC → L3 wrap+LP → L5 coll → L6 borrow → L7 repay.
contract FirePeapodsExact is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        bool doFire = vm.envOr("FIRE_PEAPODS", uint256(0)) == 1;
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        // Equal soft-$1 legs: USDC 6dp ↔ ELE 8dp
        uint256 usdcAmt = vm.envOr("ASK_USDC", uint256(1_000_000e6));
        uint256 eleAmt = usdcAmt * 100; // 1e8/1e6
        require(IERC20P(ELE).balanceOf(HOT) >= eleAmt, "ELE_BAL");
        require(IERC20P(USDC).balanceOf(MORPHO) >= usdcAmt, "MORPHO_FLASH");

        console2.log("PLAYBOOK", "Peapods L1-L7 exact");
        console2.log("usdcAmt", usdcAmt);
        console2.log("eleAmt", eleAmt);

        vm.startBroadcast(pk);

        CrownPodWrap pEle = CrownPodWrap(vm.envOr("PELE", address(0)));
        if (address(pEle) == address(0)) {
            pEle = new CrownPodWrap(ELE, HOT);
            console2.log("pELE", address(pEle));
        }

        CrownFusdVault vault = CrownFusdVault(vm.envOr("FUSDC", address(0)));
        if (address(vault) == address(0)) {
            vault = new CrownFusdVault(USDC, HOT);
            console2.log("fUSDC", address(vault));
        }

        address lp = IUniV2FactoryP(FACTORY).getPair(address(pEle), address(vault));
        if (lp == address(0)) {
            lp = IUniV2FactoryP(FACTORY).createPair(address(pEle), address(vault));
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

        CrownPeapodsSelfLend seeder = CrownPeapodsSelfLend(vm.envOr("SEEDER", address(0)));
        if (address(seeder) == address(0)) {
            seeder = new CrownPeapodsSelfLend(
                MORPHO, USDC, ELE, address(pEle), address(vault), address(pair), ROUTER, lp, HOT, HOT
            );
            console2.log("seeder", address(seeder));
        }

        if (IERC20P(ELE).allowance(HOT, address(seeder)) < eleAmt) {
            IERC20P(ELE).approve(address(seeder), type(uint256).max);
        }

        if (doFire) {
            seeder.selfLend(eleAmt, usdcAmt);
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
            console2.log("PEAPODS_SELF_LEND_OK", uint256(1));
        } else {
            console2.log("PEAPODS_PREP_OK", uint256(1));
        }
    }
}
