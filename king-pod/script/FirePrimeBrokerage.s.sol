// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {CrownLitePsm} from "../src/prime/CrownLitePsm.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";
import {SelfRepayingTreasury} from "../src/prime/SelfRepayingTreasury.sol";

/// @notice Deploy Prime Brokerage stack on Base. Does NOT arm router or lock float — King only.
/// @dev KING_GO=1 FIRE_PRIME=1 forge script script/FirePrimeBrokerage.s.sol:FirePrimeBrokerage --rpc-url $BASE_RPC_URL --broadcast
contract FirePrimeBrokerage is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    // Live gUSD (Base) — override with GUSD env if redeployed
    address constant GUSD_DEFAULT = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_PRIME", uint256(0)) == 1, "NO_FIRE");

        address gusd = vm.envOr("GUSD", GUSD_DEFAULT);
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownBoundLandingCollateral coll = new CrownBoundLandingCollateral(EUSD, gusd, HOT, HOT);
        CrownPrimeCredit credit = new CrownPrimeCredit(USDC, address(coll), HOT, LANDING, HOT);
        CrownLitePsm psm = new CrownLitePsm(EUSD, USDC, HOT);
        SelfRepayingTreasury treasury = new SelfRepayingTreasury(USDC, HOT, HOT);
        CrownPrime7683Fill fill7683 = new CrownPrime7683Fill(EUSD, USDC, HOT);
        USDCBorrowRouter router = new USDCBorrowRouter(address(coll), address(credit), USDC, HOT, HOT);

        coll.setDebtOperator(address(credit), true);
        // 1B Mansa Lite safe defaults: paper $22M mark, 50% LLTV → $11M debt max
        coll.setFloatUsd8(2.2e6);
        coll.setLltv(50e16);
        credit.setOperator(address(router), true);
        psm.setCredit(address(credit), true);
        treasury.setCredit(address(credit));
        fill7683.setConfig(address(psm), address(credit), address(treasury));
        router.setTargets(address(psm), LANDING);
        // router stays disarmed until King; kingEmergencyDraw available once cash lands

        vm.stopBroadcast();

        console2.log("CrownBoundLandingCollateral", address(coll));
        console2.log("CrownPrimeCredit", address(credit));
        console2.log("CrownLitePsm", address(psm));
        console2.log("CrownPrime7683Fill", address(fill7683));
        console2.log("USDCBorrowRouter", address(router));
        console2.log("SelfRepayingTreasury", address(treasury));
        console2.log("armed", router.armed());
    }
}
