// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {IERC20} from "../src/lib/Core.sol";
import {CrownRwaLoop} from "../src/CrownRwaLoop.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
}

interface IYrssPilot {
    function maxWithdraw(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Arm + seed/pull + loop 10M RWA pilot. FIRE_RWA_PILOT=1 · ZK_SHIELD=1 · HOT_KEY · LOOP · ASK_USDC
/// @dev Prefers yRSS pull; falls back to SEED_USDC from HOT wallet. Blocks if neither liquid.
contract FireRwaPilot10M is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function run() external {
        require(vm.envOr("FIRE_RWA_PILOT", uint256(0)) == 1, "FIRE_RWA_PILOT");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownRwaLoop loop_ = CrownRwaLoop(vm.envAddress("LOOP"));
        uint256 ask = vm.envOr("ASK_USDC", uint256(10_000_000e6));
        require(ask <= 10_000_000e6, "PILOT_10M_MAX");
        require(ask <= 35_000_000e6, "NO_FAKE_90M");

        uint256 minBps = vm.envOr("MIN_RWA_BPS", uint256(9800));
        bool useFlash = vm.envOr("USE_FLASH", uint256(0)) == 1;

        uint256 maxW = IYrssPilot(YRSS).maxWithdraw(HOT);
        uint256 hotUsdc = IERC20(USDC).balanceOf(HOT);
        console2.log("maxWithdraw", maxW);
        console2.log("hotUsdc", hotUsdc);
        console2.log("ask", ask);

        vm.startBroadcast(pk);
        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(loop_))) {
            IMorphoAuth(MORPHO).setAuthorization(address(loop_), true);
        }
        loop_.setArmed(true);

        if (useFlash) {
            loop_.flashLeverage(ask, minBps);
        } else if (maxW >= ask) {
            IYrssPilot(YRSS).approve(address(loop_), type(uint256).max);
            loop_.pullFromYrss(ask);
            loop_.loopIdle(minBps);
        } else if (hotUsdc >= ask) {
            IERC20(USDC).approve(address(loop_), ask);
            loop_.seedUsdc(ask);
            loop_.loopIdle(minBps);
        } else {
            revert("NO_FREE_USDC_SLEEVE");
        }

        uint256 skim = IERC20(USDC).balanceOf(address(loop_));
        if (skim > 0 && address(loop_.coldBuffer()) != address(0)) {
            loop_.pushYield(skim);
        }
        vm.stopBroadcast();

        console2.log("totalPulled", loop_.totalPulled());
        console2.log("totalRwaHeld", loop_.totalRwaHeld());
        console2.log("totalBorrowed", loop_.totalBorrowed());
        console2.log("totalYieldPushed", loop_.totalYieldPushed());
        console2.log("pilotRemaining", loop_.pilotRemaining());
        console2.log("MISSION RWA pilot seated");
    }
}
