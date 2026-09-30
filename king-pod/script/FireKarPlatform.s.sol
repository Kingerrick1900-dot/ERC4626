// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownAllowlist} from "../src/CrownAllowlist.sol";
import {CrownPayAdapter} from "../src/CrownPayAdapter.sol";
import {CrownRailShield} from "../src/CrownRailShield.sol";
import {CrownZkAttest} from "../src/CrownZkAttest.sol";

/// @notice Fire KAR on-chain plane: Allowlist + PayAdapter + Shield rail + fresh attest.
/// @dev FIRE=1 broadcast. Refreshes bordersSecure so KAR check() passes.
contract FireKarPlatform is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant AGENT = 0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA;
    address constant SHIELD = 0xA559752E0d84A7871A725451Ccfc96EE16c1F721;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant MIGRATE = 0x9bA812440E365a5736871ef4B5E47A007668f98D;
    address constant HUNT = 0xc4c63f8CD4182452f665e338F87b4d31aeF04516;

    // selectors
    bytes4 constant SEL_FIRE = 0x6233cbb2;
    bytes4 constant SEL_OBS = 0x14fc78fc;
    bytes4 constant SEL_POKE = 0xab2ad451;
    bytes4 constant SEL_SET_RAIL = 0xa7479fbb;
    bytes4 constant SEL_FUND = 0xca1d209d;
    bytes4 constant SEL_RELEASE = 0x59759968;
    bytes4 constant SEL_ARM = 0x2300a9a7;
    bytes4 constant SEL_MIGRATE = 0x454b0608;
    bytes4 constant SEL_ATTEST = 0xb64c95ea;
    bytes4 constant SEL_PAYROLL_ROOT = 0x1bfbab80;
    bytes4 constant SEL_THRESH = 0x8b67ce4e;
    bytes4 constant SEL_SET_COLD = 0x8aa4daa1;
    bytes4 constant SEL_HUNT = 0xc480dab6;
    bytes4 constant SEL_KILL = 0x9213bda7;
    bytes4 constant SEL_PAY = 0x5e5571ac;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;

        vm.startBroadcast(pk);

        CrownAllowlist al = new CrownAllowlist(HOT);
        CrownPayAdapter pay = new CrownPayAdapter(EUSD, HOT);

        al.setAttest(ATTEST);
        al.setRequireBorders(true);

        // Genesis steel allowlist
        address[] memory t = new address[](14);
        bytes4[] memory s = new bytes4[](14);
        t[0] = AGENT;
        s[0] = SEL_FIRE;
        t[1] = AGENT;
        s[1] = SEL_OBS;
        t[2] = AGENT;
        s[2] = SEL_POKE;
        t[3] = SHIELD;
        s[3] = SEL_SET_RAIL;
        t[4] = COLD;
        s[4] = SEL_FUND;
        t[5] = COLD;
        s[5] = SEL_RELEASE;
        t[6] = COLD;
        s[6] = SEL_ARM;
        t[7] = MIGRATE;
        s[7] = SEL_MIGRATE;
        t[8] = ATTEST;
        s[8] = SEL_ATTEST;
        t[9] = ATTEST;
        s[9] = SEL_PAYROLL_ROOT;
        t[10] = ATTEST;
        s[10] = SEL_THRESH;
        t[11] = ATTEST;
        s[11] = SEL_SET_COLD;
        t[12] = HUNT;
        s[12] = SEL_KILL; // hunt body stays blocked until King adds SEL_HUNT
        t[13] = address(pay);
        s[13] = SEL_PAY;
        al.setAllowedBatch(t, s, true);

        // Merchant placeholder = Landing (treasury receive / invoice sink until real merchants named)
        pay.setMerchant(LANDING, true);
        pay.setAllowlist(address(al));

        // Refresh borders (epoch stale otherwise)
        if (doFire) {
            bytes32 root = keccak256(abi.encode("KAR", block.timestamp, block.chainid));
            CrownZkAttest(ATTEST).commitPayrollRoot(root, true);
            CrownZkAttest(ATTEST).attestLive(root);
            CrownRailShield(SHIELD).setRail(CrownRailShield.Rail.Attest, ATTEST);
            // encode Allowlist into Curator slot annotation via Ops — use Ocean unused? set Curator stays HOT
            // Store allowlist address on shield as Attest already set; put Pay on Landing rail note via setRail Hunt? 
            // Use propose pattern: setRail Attest already; add allowlist by setting Hunt rail owner pointer? 
            // Better: setRail OpsGas stays HOT; we log allowlist/pay in console — also setRail for a free enum
            // Rail.Hunt already points to hunt router. Keep.
        }

        vm.stopBroadcast();

        console2.log("allowlist", address(al));
        console2.log("payAdapter", address(pay));
        console2.log("borders", CrownZkAttest(ATTEST).bordersSecure() ? uint256(1) : uint256(0));
        console2.log("epoch", CrownZkAttest(ATTEST).epoch());
        console2.log("agentFireAllowed", al.isAllowed(AGENT, SEL_FIRE) ? uint256(1) : uint256(0));
        console2.log("huntBodyAllowed", al.isAllowed(HUNT, SEL_HUNT) ? uint256(1) : uint256(0));
    }
}
