// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {CrownZkAttest} from "../src/CrownZkAttest.sol";
import {CrownHuntRouter} from "../src/CrownHuntRouter.sol";
import {CrownRailShield} from "../src/CrownRailShield.sol";

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ISteak {
    function maxRedeem(address) external view returns (uint256);
    function redeem(uint256, address, address) external returns (uint256);
}

interface IYrssA {
    function totalAssets() external view returns (uint256);
}

/// @notice Deploy ZK armor + cold buffer + hunt router + rail shield; fund cold; first attest.
/// @dev FIRE=1 to execute. Uses HOT USDC + Steakhouse redeem dust for cold seed.
contract FireZkArmor is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant LSR = 0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant OCEAN_BAMM = 0xAb21623705493538e7E86AAcC79C0297427dc3B2;
    address constant ZK_SETTLE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    address constant ZK_ELEPAN = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    uint256 constant NAV_T = 228_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;

        uint256 nav = IYrssA(YRSS).totalAssets();
        console2.log("yRSS_totalAssets", nav);
        console2.log("hotUSDC", IERC20A(USDC).balanceOf(HOT));
        console2.log("steakShares", IERC20A(STEAK).balanceOf(HOT));

        vm.startBroadcast(pk);

        CrownRailShield shield = new CrownRailShield(HOT);
        CrownColdBuffer cold = new CrownColdBuffer(USDC, HOT, LSR);
        CrownZkAttest attest = new CrownZkAttest(YRSS, HOT, NAV_T, 8e6, ZK_SETTLE, ZK_ELEPAN);
        CrownHuntRouter hunt = new CrownHuntRouter(MORPHO, HOT, HOT);

        attest.setCold(address(cold));
        // redeemable window = dust-honest $8 until larger USDC capture
        attest.setThresholds(NAV_T, 8e6, 1 hours);

        shield.setRail(CrownRailShield.Rail.OpsGas, HOT);
        shield.setRail(CrownRailShield.Rail.Curator, HOT);
        shield.setRail(CrownRailShield.Rail.Landing, LANDING);
        shield.setRail(CrownRailShield.Rail.Ocean, OCEAN_BAMM);
        shield.setRail(CrownRailShield.Rail.Attest, address(attest));
        shield.setRail(CrownRailShield.Rail.Cold, address(cold));
        shield.setRail(CrownRailShield.Rail.Hunt, address(hunt));

        hunt.setHunter(HOT, true);
        hunt.setMinTipWei(0);

        if (doFire) {
            // Pull Steakhouse dust → USDC
            uint256 mr = ISteak(STEAK).maxRedeem(HOT);
            if (mr > 0) {
                ISteak(STEAK).redeem(mr, HOT, HOT);
            }
            uint256 usdcBal = IERC20A(USDC).balanceOf(HOT);
            if (usdcBal > 0) {
                IERC20A(USDC).approve(address(cold), usdcBal);
                cold.fund(usdcBal);
            }

            // Payroll root for last 10M mint (commitment)
            bytes32 payrollRoot = keccak256(abi.encode(LANDING, uint256(10_000_000 ether), block.chainid));
            attest.commitPayrollRoot(payrollRoot, true);
            attest.attestLive(payrollRoot);

            // Smoke hunt: flash $1 USDC, empty calls, tip 0 — proves router path
            hunt.setKillSwitch(false);
            address[] memory t;
            uint256[] memory v;
            bytes[] memory d;
            hunt.hunt(USDC, 1e6, t, v, d, 0);
            hunt.setKillSwitch(true); // re-lock after smoke
        }

        vm.stopBroadcast();

        console2.log("shield", address(shield));
        console2.log("cold", address(cold));
        console2.log("attest", address(attest));
        console2.log("hunt", address(hunt));
        console2.log("coldBal", cold.balance());
        console2.log("bordersSecure", attest.bordersSecure() ? uint256(1) : uint256(0));
        console2.log("epoch", attest.epoch());
    }
}
