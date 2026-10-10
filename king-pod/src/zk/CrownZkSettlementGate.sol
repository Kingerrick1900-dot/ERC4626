// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";
import {ProofVecGuard} from "./ProofVecGuard.sol";

interface IGroth16SettlementVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
    ) external view returns (bool);
}

/// @notice ZK settlement gate — attest solver USDC ≥ minUsdc bound to ERC-7683 orderId.
/// @dev Does not call or modify ERC-7540 / ERC-7683. Solvers prove here, then fill live rails.
///      Public signals: [ok, commitment, orderId, minUsdc, subject].
contract CrownZkSettlementGate is Ownable {
    using ProofVecGuard for uint256[];

    IGroth16SettlementVerifier public immutable verifier;
    uint256 public proofTtl = 1 days;
    uint256 public minFillUsdc = 1e6; // $1 floor

    struct OrderAttestation {
        uint256 minUsdc;
        uint256 commitment;
        address filler;
        uint256 provenAt;
        bool valid;
    }

    mapping(bytes32 => OrderAttestation) private _orders;
    mapping(address => uint256) public fillerProvenAt;

    event SettlementProven(
        bytes32 indexed orderId, address indexed filler, uint256 minUsdc, uint256 commitment, uint256 provenAt
    );
    event SilentFailureFlag(bytes32 indexed orderId, bytes32 indexed code, uint256 minUsdc);
    event Ttl(uint256 proofTtl);
    event MinFill(uint256 minFillUsdc);

    error BadProof();
    error BadOrder();
    error BadSubject();
    error BadAmt();
    error Expired();

    constructor(address verifier_, address owner_) Ownable(owner_) {
        require(verifier_ != address(0), "ZERO");
        verifier = IGroth16SettlementVerifier(verifier_);
    }

    function setTtl(uint256 ttl) external onlyOwner {
        proofTtl = ttl;
        emit Ttl(ttl);
    }

    function setMinFillUsdc(uint256 v) external onlyOwner {
        if (v == 0) revert BadAmt();
        minFillUsdc = v;
        emit MinFill(v);
    }

    /// @notice Submit Groth16 settlement proof. publicSignals: [ok, commitment, orderId, minUsdc, subject]
    function submitProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata publicSignals
    ) external {
        _submit(a, b, c, publicSignals);
    }

    function submitProofVec(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicSignals
    ) external {
        uint256[5] memory pub = ProofVecGuard.decodeSettlementPublic(publicSignals);
        _submit(a, b, c, pub);
    }

    function _submit(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] memory publicSignals
    ) internal {
        for (uint256 i; i < 5; ++i) {
            if (publicSignals[i] >= ProofVecGuard.SNARK_SCALAR_FIELD) revert BadProof();
        }
        if (publicSignals[0] != 1) revert BadProof();
        if (publicSignals[3] < minFillUsdc || publicSignals[3] > ProofVecGuard.MAX_THRESHOLD) revert BadAmt();
        address subject = ProofVecGuard.requireAddressSubject(publicSignals[4]);
        if (publicSignals[2] == 0) revert BadOrder();

        bool ok = verifier.verifyProof(a, b, c, publicSignals);
        if (!ok) revert BadProof();

        if (publicSignals[1] == 0) {
            emit SilentFailureFlag(bytes32(publicSignals[2]), bytes32("ZERO_COMMIT"), publicSignals[3]);
        }

        bytes32 orderId = bytes32(publicSignals[2]); // already < snark scalar (field-reduced)
        _orders[orderId] = OrderAttestation({
            minUsdc: publicSignals[3],
            commitment: publicSignals[1],
            filler: subject,
            provenAt: block.timestamp,
            valid: true
        });
        fillerProvenAt[subject] = block.timestamp;
        emit SettlementProven(orderId, subject, publicSignals[3], publicSignals[1], block.timestamp);
    }

    /// @notice Map ERC-7683 orderId into BN254 field for circuit / storage key.
    function fieldOrderId(bytes32 orderId) public pure returns (bytes32) {
        return bytes32(uint256(orderId) % ProofVecGuard.SNARK_SCALAR_FIELD);
    }

    function isOrderProven(bytes32 orderId) public view returns (bool) {
        OrderAttestation memory a = _orders[fieldOrderId(orderId)];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        return true;
    }

    function requireOrderProven(bytes32 orderId) external view {
        if (!isOrderProven(orderId)) revert Expired();
    }

    function orderAttestation(bytes32 orderId)
        external
        view
        returns (uint256 minUsdc, uint256 commitment, address filler, uint256 provenAt, bool valid)
    {
        OrderAttestation memory a = _orders[fieldOrderId(orderId)];
        return (a.minUsdc, a.commitment, a.filler, a.provenAt, a.valid);
    }

    /// @notice Solver helper: check attestation before calling live 7683 fill / 7540 fulfill.
    function canFill(bytes32 orderId, address filler, uint256 minUsdc) external view returns (bool) {
        OrderAttestation memory a = _orders[fieldOrderId(orderId)];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        if (a.filler != filler) return false;
        if (a.minUsdc < minUsdc) return false;
        return true;
    }

    function revoke(bytes32 orderId) external onlyOwner {
        delete _orders[fieldOrderId(orderId)];
    }
}
