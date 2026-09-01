// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPrimeFlashFillDraw} from "../src/prime/CrownPrimeFlashFillDraw.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newAuthorized) external;
}

/// @notice Deploy flash-fill engine on live prime stack.
/// @dev KING_GO=1 FIRE_FLASH_FILL=1 forge script script/FirePrimeFlashFill.s.sol:FirePrimeFlashFill --rpc-url $BASE_RPC_URL --broadcast
contract FirePrimeFlashFill is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;
    address constant TREASURY = 0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97;
    address constant ROUTER = 0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_FLASH_FILL", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownPrimeFlashFillDraw engine = new CrownPrimeFlashFillDraw(
            MORPHO, USDC, FILL, CREDIT, TREASURY, LANDING, HOT, HOT
        );

        CrownPrime7683Fill(FILL).setFees(1000, 0);
        CrownPrimeCredit(CREDIT).setOperator(address(engine), true);
        IMorphoAuth(MORPHO).setAuthorization(address(engine), true);
        // Do NOT setRepayRails(yRSS) unless king approved engine on yRSS shares — breaks flash fill.

        vm.stopBroadcast();

        console2.log("CrownPrimeFlashFillDraw", address(engine));
        console2.log("protocolFeeBps", CrownPrime7683Fill(FILL).protocolFeeBps());
    }
}

/// @notice Fire flash fill on open 7683 order (one tx). Optional REPAY_TOPUP for live idle + draw.
/// @dev KING_GO=1 FIRE_FLASH_LIVE=1 ORDER_ID=0x… USDC_IN=4500000000 REPAY_TOPUP=0 forge script …:FirePrimeFlashLive
contract FirePrimeFlashLive is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ENGINE_DEFAULT = address(0); // set FLASH_ENGINE env after deploy

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_FLASH_LIVE", uint256(0)) == 1, "NO_LIVE");

        address engine = vm.envOr("FLASH_ENGINE", ENGINE_DEFAULT);
        require(engine != address(0), "FLASH_ENGINE");

        bytes32 orderId = vm.envBytes32("ORDER_ID");
        uint256 usdcIn = vm.envOr("USDC_IN", uint256(4_500_000e6));
        uint256 topUp = vm.envOr("REPAY_TOPUP", uint256(0));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        if (topUp > 0) {
            // topUp pulled inside engine from HOT
        }
        CrownPrimeFlashFillDraw(engine).flashFillAndDraw(orderId, usdcIn, LANDING, topUp);

        vm.stopBroadcast();
        console2.log("flashFill fired", usdcIn, "topUp", topUp);
    }
}

/// @notice Arm router + draw when credit idle is live.
/// @dev KING_GO=1 FIRE_DRAW=1 DRAW_AMT=4500000000 forge script …:FirePrimeDrawIdle
contract FirePrimeDrawIdle is Script {
    address constant ROUTER = 0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c;
    address constant CREDIT = 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_DRAW", uint256(0)) == 1, "NO_DRAW");

        uint256 amt = vm.envOr("DRAW_AMT", uint256(4_500_000e6));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        USDCBorrowRouter(ROUTER).setArmed(true);
        USDCBorrowRouter(ROUTER).draw(amt, address(0));

        vm.stopBroadcast();
        console2.log("draw", amt, "idle left", CrownPrimeCredit(CREDIT).freeUsdc());
    }
}
