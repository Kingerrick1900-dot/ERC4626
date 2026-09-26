// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignEusd} from "../src/CrownSovereignEusd.sol";
import {CrownSpendVault} from "../src/CrownSpendVault.sol";
import {CrownLsrEusd} from "../src/CrownLsrEusd.sol";
import {CrownKingAgent} from "../src/CrownKingAgent.sol";
import {CrownPayAdapter} from "../src/CrownPayAdapter.sol";
import {CrownOpenMoney} from "../src/CrownOpenMoney.sol";
import {CrownAllowlist} from "../src/CrownAllowlist.sol";
import {CrownZkAttest} from "../src/CrownZkAttest.sol";
import {CrownNavMirror} from "../src/CrownNavMirror.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {CrownRailShield} from "../src/CrownRailShield.sol";

/// @notice Polygon expansion: CrownKingAgent + Open Money + ZK NAV mirror. Seed = vault POL gas.
/// @dev FIRE=1 broadcast. PRIVATE_KEY = Polygon vault key. USDC = native Polygon USDC.
contract FirePolygonExpand is Script {
    // Native USDC on Polygon
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    // Base yRSS address hashed into mirror source
    bytes32 constant BASE_YRSS =
        bytes32(uint256(uint160(0xF80C0529bD94C773844E459853CD91B9263dD525)));
    uint256 constant NAV_T = 228_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address vault = vm.addr(pk);
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;
        console2.log("vault", vault);
        console2.log("pol", vault.balance);

        vm.startBroadcast(pk);

        CrownSovereignEusd eusd = new CrownSovereignEusd(vault);
        CrownSpendVault spend = new CrownSpendVault(vault, vault);
        CrownLsrEusd lsr = new CrownLsrEusd(USDC, address(eusd), vault, vault, vault);
        CrownKingAgent agent = new CrownKingAgent(vault, vault, vault);
        CrownNavMirror nav = new CrownNavMirror(vault, NAV_T, BASE_YRSS); // seed at threshold
        // bump mirror to live-ish Base TVL band
        nav.setNav(228_900_000e6, BASE_YRSS);
        CrownZkAttest attest = new CrownZkAttest(address(nav), vault, NAV_T, 8e6, address(0), address(0));
        CrownColdBuffer cold = new CrownColdBuffer(USDC, vault, address(lsr));
        attest.setCold(address(cold));
        CrownPayAdapter pay = new CrownPayAdapter(address(eusd), vault);
        CrownOpenMoney openMoney = new CrownOpenMoney(address(eusd), USDC, vault);
        CrownAllowlist al = new CrownAllowlist(vault);
        CrownRailShield shield = new CrownRailShield(vault);

        // Wire LSR minter + agent operator
        eusd.setMinter(address(lsr), true);
        lsr.setOperator(address(agent), true);
        agent.setModules(address(spend), address(lsr), address(0));
        spend.setAgent(address(agent));
        spend.setTarget(address(lsr), true);
        spend.setTarget(address(pay), true);
        spend.setTarget(address(openMoney), true);

        pay.setMerchant(vault, true);
        openMoney.setMerchant(vault, true);

        al.setAttest(address(attest));
        al.setRequireBorders(true);
        al.setAllowed(address(agent), bytes4(0x6233cbb2), true); // firePayroll
        al.setAllowed(address(agent), bytes4(0x14fc78fc), true); // observe
        al.setAllowed(address(pay), bytes4(0x5e5571ac), true); // pay
        al.setAllowed(address(attest), bytes4(0xb64c95ea), true); // attestLive

        shield.setRail(CrownRailShield.Rail.OpsGas, vault);
        shield.setRail(CrownRailShield.Rail.Landing, vault);
        shield.setRail(CrownRailShield.Rail.Attest, address(attest));
        shield.setRail(CrownRailShield.Rail.Cold, address(cold));
        shield.setRail(CrownRailShield.Rail.Curator, vault);

        if (doFire) {
            // Fund cold with vault USDC dust if any
            uint256 usdcBal = _bal(USDC, vault);
            if (usdcBal > 0) {
                _approve(USDC, address(cold), usdcBal);
                cold.fund(usdcBal);
            }
            bytes32 root = keccak256(abi.encode("POLY-KAR", block.chainid, block.timestamp));
            attest.commitPayrollRoot(root, true);
            attest.attestLive(root);
            // Smoke payroll 1M eUSD to vault/landing
            agent.firePayroll(1_000_000e18);
            // Sample Open Money invoice
            bytes32 inv = keccak256("FIRST-GLOBAL-INVOICE");
            openMoney.createInvoice(inv, vault, address(eusd), 100e18);
        }

        vm.stopBroadcast();

        console2.log("eusd", address(eusd));
        console2.log("spend", address(spend));
        console2.log("lsr", address(lsr));
        console2.log("agent", address(agent));
        console2.log("navMirror", address(nav));
        console2.log("attest", address(attest));
        console2.log("cold", address(cold));
        console2.log("pay", address(pay));
        console2.log("openMoney", address(openMoney));
        console2.log("allowlist", address(al));
        console2.log("shield", address(shield));
        console2.log("borders", attest.bordersSecure() ? uint256(1) : uint256(0));
        console2.log("eusdSupply", eusd.totalSupply());
    }

    function _bal(address t, address a) internal view returns (uint256) {
        (bool ok, bytes memory d) = t.staticcall(abi.encodeWithSignature("balanceOf(address)", a));
        require(ok && d.length >= 32, "BAL");
        return abi.decode(d, (uint256));
    }

    function _approve(address t, address s, uint256 amt) internal {
        (bool ok,) = t.call(abi.encodeWithSignature("approve(address,uint256)", s, amt));
        require(ok, "APPROVE");
    }
}
