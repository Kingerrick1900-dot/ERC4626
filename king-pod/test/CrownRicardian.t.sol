// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownRicardian} from "../src/CrownRicardian.sol";

contract CrownRicardianTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function test_document_binds_prose_and_settlement() public {
        bytes32 h = keccak256(bytes("KE-Sov Ricardian Charter - King Errick Sovereignty"));
        CrownRicardian ric = new CrownRicardian(HOT, LANDING, h, "deployments/ke-sov/LEGAL-PROSE.md");
        (string memory ent, bytes32 ph,, address sink, bool corp, uint256 ver) = ric.document();
        assertEq(ent, "KE-Sov");
        assertEq(ph, h);
        assertEq(sink, LANDING);
        assertFalse(corp);
        assertEq(ver, 1);
    }

    function test_open_three_offers() public {
        bytes32 h = keccak256("prose");
        CrownRicardian ric = new CrownRicardian(HOT, LANDING, h, "uri");
        vm.startPrank(HOT);
        ric.openOffer(keccak256("AnchorX"), address(0), 700_000e6, keccak256("A"));
        ric.openOffer(keccak256("Conflux"), address(0), 700_000e6, keccak256("C"));
        ric.openOffer(keccak256("SBI"), address(0), 700_000e6, keccak256("S"));
        ric.markIncorporated("PENDING-EIN", "PENDING-FDIC");
        vm.stopPrank();
        assertEq(ric.offerCount(), 3);
        assertTrue(ric.incorporated());
    }
}

contract KeSovForkSmoke is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        vm.skip(bytes(rpc).length == 0);
        vm.createSelectFork(rpc);
    }

    function test_fork_allowlist_owned_by_hot() public view {
        (bool ok, bytes memory data) = ALLOWLIST.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok);
        assertEq(abi.decode(data, (address)), HOT);
    }

    function test_fork_yrss_pa_readable() public view {
        (bool ok, bytes memory data) =
            PA.staticcall(abi.encodeWithSignature("flowCaps(address,bytes32)", YRSS, PARK));
        assertTrue(ok);
        (uint128 maxIn,) = abi.decode(data, (uint128, uint128));
        assertGe(uint256(maxIn), 0);
    }
}
