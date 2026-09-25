// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSpendVault} from "../src/CrownSpendVault.sol";
import {CrownLsrEusd} from "../src/CrownLsrEusd.sol";
import {CrownBammOcean} from "../src/CrownBammOcean.sol";
import {CrownKingAgent} from "../src/CrownKingAgent.sol";

interface IEusdMinter {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
}

/// @notice Deploy Crown integration stack on Base. KING_GO=1 to broadcast.
contract FireCrownIntegration is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant EUSD_M = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        require(me == HOT, "NOT_HOT");
        bool go = vm.envOr("KING_GO", false);
        require(go, "SET KING_GO=1");

        vm.startBroadcast(pk);

        CrownSpendVault vault = new CrownSpendVault(HOT, HOT);
        CrownLsrEusd lsr = new CrownLsrEusd(USDC, EUSD, HOT, LANDING, HOT);
        CrownBammOcean bamm = new CrownBammOcean(GUSD, EUSD, HOT, HOT);
        CrownKingAgent agent = new CrownKingAgent(HOT, LANDING, HOT);

        agent.setModules(address(vault), address(lsr), address(bamm));
        agent.setRails(YRSS, PA, MORPHO);
        agent.setMarkets(PARK, EUSD_M);
        agent.setPayrollChunk(1_000_000e18, false);

        lsr.setOperator(address(agent), true);
        lsr.setOperator(address(vault), true);

        vault.setAgent(address(agent));
        vault.setTarget(address(lsr), true);
        vault.setTarget(address(bamm), true);
        vault.setTarget(YRSS, true);
        vault.setTarget(PA, true);
        vault.setLimits(50_000_000e18, 500_000_000e18);

        // Grant LSR minter so payroll / sellGem work
        IEusdMinter(EUSD).setMinter(address(lsr), true);

        // Optional first payroll if FIRE_PAYROLL=1
        if (vm.envOr("FIRE_PAYROLL", false)) {
            uint256 amt = vm.envOr("PAYROLL_AMT", uint256(10_000_000e18));
            agent.firePayroll(amt);
        }

        vm.stopBroadcast();

        console2.log("CrownSpendVault", address(vault));
        console2.log("CrownLsrEusd", address(lsr));
        console2.log("CrownBammOcean", address(bamm));
        console2.log("CrownKingAgent", address(agent));
    }
}
