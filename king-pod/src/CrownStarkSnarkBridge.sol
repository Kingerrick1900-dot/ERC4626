// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkAttestBridge {
    function attestLive(bytes32 payloadHash) external;
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function bordersSecure() external view returns (bool);
    function epoch() external view returns (uint256);
}

/// @title CrownStarkSnarkBridge
/// @notice Software-first STARK→SNARK binding: commit STARK digest, then bind into ZkAttest epoch.
/// @dev Full STARK verify is off-chain / future verifier; on-chain we lock the digest + SNARK path.
contract CrownStarkSnarkBridge is Ownable {
    IZkAttestBridge public attest;

    mapping(bytes32 => StarkCommit) public commits;
    bytes32 public lastStarkRoot;
    bytes32 public lastBoundPayload;

    struct StarkCommit {
        bytes32 starkRoot;
        bytes32 publicInputsHash;
        address prover;
        uint64 committedAt;
        bool snarkBound;
    }

    event AttestSet(address attest);
    event StarkCommitted(bytes32 indexed starkRoot, bytes32 publicInputsHash, address prover);
    event BoundToAttest(bytes32 indexed starkRoot, bytes32 payloadHash, uint256 epoch);

    error Bad();
    error Unknown();
    error Already();

    constructor(address attest_, address owner_) Ownable(owner_) {
        attest = IZkAttestBridge(attest_);
        emit AttestSet(attest_);
    }

    function setAttest(address a) external onlyOwner {
        attest = IZkAttestBridge(a);
        emit AttestSet(a);
    }

    /// @notice Commit a STARK proof digest (verified off-chain / air-gap) before SNARK bind.
    function commitStark(bytes32 starkRoot, bytes32 publicInputsHash) external onlyOwner {
        if (starkRoot == bytes32(0)) revert Bad();
        if (commits[starkRoot].committedAt != 0) revert Already();
        commits[starkRoot] =
            StarkCommit({starkRoot: starkRoot, publicInputsHash: publicInputsHash, prover: msg.sender, committedAt: uint64(block.timestamp), snarkBound: false});
        lastStarkRoot = starkRoot;
        emit StarkCommitted(starkRoot, publicInputsHash, msg.sender);
    }

    /// @notice Bind STARK commit into ZkAttest live epoch (SNARK path / borders refresh).
    function bindToAttest(bytes32 starkRoot) external onlyOwner returns (bytes32 payload) {
        StarkCommit storage c = commits[starkRoot];
        if (c.committedAt == 0) revert Unknown();
        if (c.snarkBound) revert Already();
        payload = keccak256(abi.encode("STARK-SNARK", starkRoot, c.publicInputsHash, block.chainid));
        attest.commitPayrollRoot(payload, true);
        attest.attestLive(payload);
        c.snarkBound = true;
        lastBoundPayload = payload;
        emit BoundToAttest(starkRoot, payload, attest.epoch());
    }
}
