// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownLitePsm} from "../src/prime/CrownLitePsm.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";
import {SelfRepayingTreasury} from "../src/prime/SelfRepayingTreasury.sol";
import {CrownPrimeIdleTap} from "../src/prime/CrownPrimeIdleTap.sol";

interface IMorphoAuthClear {
    function setAuthorization(address authorized, bool newAuthorized) external;
}

/// @notice Replace poisoned credit ($4.5M phantom flash debt) with a clean pool. No flash.
/// @dev KING_GO=1 FIRE_CLEAR_DEBT=1 forge script script/FireClearPhantomDebt.s.sol:FireClearPhantomDebt --broadcast --slow
contract FireClearPhantomDebt is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address constant COLL = 0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8;
    address constant OLD_CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant OLD_ROUTER = 0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c;
    address constant PSM = 0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B;
    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant TREASURY = 0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97;
    address constant OLD_TAP = 0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5;
    address constant FLASH = 0xf84af71DE78AaCddc4201F5dc8c9238C69851429;

    address constant ORACLE_EUSD = 0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_86 = 860000000000000000;
    bytes32 constant EUSD_MKT = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_CLEAR_DEBT", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownPrimeCredit credit = new CrownPrimeCredit(USDC, COLL, HOT, LANDING, HOT);
        USDCBorrowRouter router = new USDCBorrowRouter(COLL, address(credit), USDC, HOT, HOT);
        CrownPrimeIdleTap tap = new CrownPrimeIdleTap(MORPHO, USDC, EUSD, address(credit), HOT, HOT);

        credit.setOperator(address(router), true);
        credit.setOperator(PSM, true);
        credit.setOperator(address(tap), true);
        router.setTargets(PSM, LANDING);

        tap.setEusdMarket(ORACLE_EUSD, IRM, LLTV_86, EUSD_MKT);
        IMorphoAuthClear(MORPHO).setAuthorization(address(tap), true);

        CrownBoundLandingCollateral coll = CrownBoundLandingCollateral(COLL);
        coll.setDebtOperator(HOT, true);
        coll.setReservedDebtUsd6(0);
        coll.setDebtOperator(address(credit), true);
        coll.setDebtOperator(OLD_CREDIT, false);

        CrownPrimeCredit(OLD_CREDIT).setOperator(OLD_ROUTER, false);
        CrownPrimeCredit(OLD_CREDIT).setOperator(FLASH, false);
        USDCBorrowRouter(OLD_ROUTER).setArmed(false);

        CrownLitePsm(PSM).setCredit(address(credit), true);
        CrownPrime7683Fill(FILL).setConfig(PSM, address(credit), TREASURY);
        SelfRepayingTreasury(TREASURY).setCredit(address(credit));

        vm.stopBroadcast();

        console2.log("NEW_CREDIT", address(credit));
        console2.log("NEW_ROUTER", address(router));
        console2.log("NEW_TAP", address(tap));
        console2.log("newDebt", credit.debtOf(HOT));
        console2.log("reserved", coll.reservedDebtUsd6());
        console2.log("oldDebtZombie", CrownPrimeCredit(OLD_CREDIT).debtOf(HOT));
    }
}
