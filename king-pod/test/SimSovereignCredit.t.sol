// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKRT} from "../src/CrownKRT.sol";
import {CrownSovereignCredit} from "../src/CrownSovereignCredit.sol";
import {CrownSovereignColdKrt} from "../src/CrownSovereignColdKrt.sol";

contract SimSovereignCredit is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant KILLER = 0x7273ffE28a0aa8323d5c8F3D23793a7fA19ebD17;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant PAR_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant B2_ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;

    function test_mint_30m_against_killer_par() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        // TTL may be stale on tip — mock WalletGate for capacity/mint path unit.
        vm.mockCall(ZK, abi.encodeWithSignature("isProven(address)", SAFE), abi.encode(true));

        vm.startPrank(HOT);
        CrownSovereignCredit credit = new CrownSovereignCredit(
            MORPHO, ZK, ATTEST, PAR, KILLER, RSS, PAR_ORACLE, SAFE, HOT
        );
        CrownKRT krt = new CrownKRT(ZK, ATTEST, B2_ORACLE, RAIL, SAFE, address(credit));
        credit.wireKrt(address(krt));
        CrownSovereignColdKrt cold = new CrownSovereignColdKrt(address(krt), SAFE, HOT);
        credit.wireCold(address(cold));

        (uint256 collWei, uint256 collUsd6, uint256 maxMint,) = credit.creditCapacity();
        console2.log("collWei", collWei);
        console2.log("collUsd6", collUsd6);
        console2.log("maxMint", maxMint);
        assertGt(collWei, 0, "killer coll");
        assertGe(maxMint, 30_000_000 ether, "cap");

        credit.mintAndSplit(HOT, 30_000_000 ether);
        vm.stopPrank();

        assertEq(krt.balanceOf(HOT), 24_000_000 ether, "80%");
        assertEq(krt.balanceOf(address(cold)), 6_000_000 ether, "20%");
        assertEq(credit.totalMinted(), 30_000_000 ether, "minted");
    }
}
