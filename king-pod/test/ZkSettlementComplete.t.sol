// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownZkSettlementGate} from "../src/zk/CrownZkSettlementGate.sol";
import {Groth16SettlementVerifier} from "../src/zk/Groth16SettlementVerifier.sol";
import {ProofVecGuard} from "../src/zk/ProofVecGuard.sol";
import {ZkKingGate, IZkGateBook} from "../src/lib/ZkKingGate.sol";

contract AlwaysAcceptSettlementVerifier {
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[5] calldata)
        external
        pure
        returns (bool)
    {
        return true;
    }
}

contract AlwaysRejectSettlementVerifier {
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[5] calldata)
        external
        pure
        returns (bool)
    {
        return false;
    }
}

/// @dev Minimal wallet gate double with (threshold, provenAt, bool) attestations for ABI pack.
contract MockWalletGateBook {
    uint256 public minThreshold = 700_000e6;
    mapping(address => bool) public proven;
    mapping(address => uint256) public thr;

    function set(address a, uint256 t, bool p) external {
        proven[a] = p;
        thr[a] = t;
    }

    function isProven(address a) external view returns (bool) {
        return proven[a];
    }

    function attestations(address a) external view returns (uint256, uint256, bool) {
        return (thr[a], block.timestamp, proven[a]);
    }
}

contract ZkSettlementCompleteTest is Test {
    address filler = address(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1);

    function test_settlement_mock_accept_and_canFill() public {
        AlwaysAcceptSettlementVerifier v = new AlwaysAcceptSettlementVerifier();
        CrownZkSettlementGate gate = new CrownZkSettlementGate(address(v), address(this));

        bytes32 rawOrder = keccak256("order-1");
        bytes32 fieldId = gate.fieldOrderId(rawOrder);
        uint256[5] memory pub;
        pub[0] = 1;
        pub[1] = 12345; // commitment
        pub[2] = uint256(fieldId);
        pub[3] = 500e6;
        pub[4] = uint256(uint160(filler));

        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;
        gate.submitProof(a, b, c, pub);

        assertTrue(gate.isOrderProven(rawOrder));
        assertTrue(gate.canFill(rawOrder, filler, 500e6));
        assertFalse(gate.canFill(rawOrder, address(0xBEEF), 500e6));
    }

    function test_settlement_reject_bad_ok_and_verifier() public {
        AlwaysRejectSettlementVerifier v = new AlwaysRejectSettlementVerifier();
        CrownZkSettlementGate gate = new CrownZkSettlementGate(address(v), address(this));

        uint256[5] memory pub;
        pub[0] = 1;
        pub[1] = 1;
        pub[2] = 99;
        pub[3] = 1e6;
        pub[4] = uint256(uint160(filler));
        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;
        vm.expectRevert(CrownZkSettlementGate.BadProof.selector);
        gate.submitProof(a, b, c, pub);

        AlwaysAcceptSettlementVerifier v2 = new AlwaysAcceptSettlementVerifier();
        CrownZkSettlementGate gate2 = new CrownZkSettlementGate(address(v2), address(this));
        pub[0] = 0;
        vm.expectRevert(CrownZkSettlementGate.BadProof.selector);
        gate2.submitProof(a, b, c, pub);
    }

    function test_settlement_real_groth16_proof() public {
        // Embedded proof from zk/proofs/settlement_proof_solidity.json (liq=1e9, min=5e8, subject=hot)
        uint256[2] memory a = [
            uint256(18356366545112964101018783601644879706594486011617690096339986608765871537345),
            uint256(13859719679154045427510078275716756220299473218611755147820956591362246361614)
        ];
        uint256[2][2] memory b;
        b[0][0] = 19570015869606323113157539435421677428926769125266377647970882721818312993156;
        b[0][1] = 474424184206331418168390459998246849204193041474893922882566563164150554212;
        b[1][0] = 2599227040305008602333672394777189172259201843263820766378603393193566365809;
        b[1][1] = 20832033227701589537531568289570673053552385838055297675508233795124923277114;
        uint256[2] memory c = [
            uint256(19369737961116859398822215494692627616001069148277529327696864375509439164145),
            uint256(14894234961737504528030300460586618510123298889237683257527863354301375900075)
        ];
        uint256[5] memory pub;
        pub[0] = 1;
        pub[1] = 15778138559586534360010514377279810639930750436081062254470560647519972840374;
        pub[2] = 13167463239018645121472401858882519523925245802772065491305606236986174979819;
        pub[3] = 500000000;
        pub[4] = 588224148543878888622858987941633173888015968209;

        Groth16SettlementVerifier ver = new Groth16SettlementVerifier();
        assertTrue(ver.verifyProof(a, b, c, pub));

        CrownZkSettlementGate gate = new CrownZkSettlementGate(address(ver), address(this));
        gate.submitProof(a, b, c, pub);
        bytes32 oid = bytes32(pub[2]);
        assertTrue(gate.isOrderProven(oid));
        assertTrue(gate.canFill(oid, address(uint160(pub[4])), pub[3]));
    }

    function test_zkKingGate_abi_bool_attestation() public {
        MockWalletGateBook book = new MockWalletGateBook();
        address king = address(0xA11CE);
        book.set(king, 700_000e6, true);
        ZkKingGate.requireProven(IZkGateBook(address(book)), king);
        assertEq(ZkKingGate.attestValue(IZkGateBook(address(book)), king), 700_000e6);
    }

    function test_settlement_vec_bad_len() public {
        AlwaysAcceptSettlementVerifier v = new AlwaysAcceptSettlementVerifier();
        CrownZkSettlementGate gate = new CrownZkSettlementGate(address(v), address(this));
        uint256[] memory bad = new uint256[](4);
        uint256[2] memory a;
        uint256[2][2] memory b;
        uint256[2] memory c;
        vm.expectRevert(ProofVecGuard.BadLen.selector);
        gate.submitProofVec(a, b, c, bad);
    }
}
