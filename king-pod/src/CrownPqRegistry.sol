// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @title CrownPqRegistry
/// @notice On-chain registry of Dilithium / Kyber public keys. Private keys NEVER on-chain.
/// @dev Custody law: air-gapped hardware, NFC-bound, King-only. This contract only stores pub hashes.
contract CrownPqRegistry is Ownable {
    enum Alg {
        Dilithium3,
        Kyber768
    }

    struct PubKey {
        Alg alg;
        bytes32 keyHash; // keccak256(pubkey bytes)
        string label;
        uint64 registeredAt;
        bool active;
    }

    mapping(bytes32 => PubKey) public keys; // id => key
    bytes32[] public keyIds;
    bytes32 public activeDilithium;
    bytes32 public activeKyber;

    event KeyRegistered(bytes32 indexed id, Alg alg, bytes32 keyHash, string label);
    event KeyActivated(bytes32 indexed id, Alg alg);
    event KeyRevoked(bytes32 indexed id);

    error Bad();
    error Unknown();

    constructor(address owner_) Ownable(owner_) {}

    function register(Alg alg, bytes32 keyHash, string calldata label) external onlyOwner returns (bytes32 id) {
        if (keyHash == bytes32(0)) revert Bad();
        id = keccak256(abi.encode(alg, keyHash, label, block.timestamp, keyIds.length));
        keys[id] = PubKey({alg: alg, keyHash: keyHash, label: label, registeredAt: uint64(block.timestamp), active: false});
        keyIds.push(id);
        emit KeyRegistered(id, alg, keyHash, label);
    }

    function activate(bytes32 id) external onlyOwner {
        PubKey storage k = keys[id];
        if (k.registeredAt == 0) revert Unknown();
        k.active = true;
        if (k.alg == Alg.Dilithium3) activeDilithium = id;
        else activeKyber = id;
        emit KeyActivated(id, k.alg);
    }

    function revoke(bytes32 id) external onlyOwner {
        PubKey storage k = keys[id];
        if (k.registeredAt == 0) revert Unknown();
        k.active = false;
        if (activeDilithium == id) activeDilithium = bytes32(0);
        if (activeKyber == id) activeKyber = bytes32(0);
        emit KeyRevoked(id);
    }

    function keyCount() external view returns (uint256) {
        return keyIds.length;
    }
}
