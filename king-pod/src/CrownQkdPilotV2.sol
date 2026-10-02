// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @title CrownQkdPilotV2
/// @notice Shenzhen–Shanghai QKD pilot log. Stores packet/key **hashes only**. Attest is King-side.
/// @dev V1 logPacket could not call ZkAttest (onlyOwner). V2 returns root for King to attestLive.
contract CrownQkdPilotV2 is Ownable {
    string public corridor = "Shenzhen-Shanghai";
    string public partner = "Conflux+CN-telco";
    address public immutable v1; // prior pilot
    uint64 public t0;
    uint64 public loiAt;
    uint64 public pilotAt;

    struct Packet {
        bytes32 packetHash;
        bytes32 keyMaterialHash;
        uint64 at;
        string note;
    }

    Packet[] public packets;

    event T0Set(uint64 t0);
    event LoiRecorded(uint64 at, string ref);
    event PilotOpened(uint64 at);
    event PacketLogged(uint256 indexed idx, bytes32 packetHash, bytes32 root);

    error Bad();
    error TooEarly();

    constructor(address v1_, address owner_) Ownable(owner_) {
        v1 = v1_;
    }

    function markT0(uint64 ts) external onlyOwner {
        t0 = ts == 0 ? uint64(block.timestamp) : ts;
        emit T0Set(t0);
    }

    function recordLoi(string calldata ref) external onlyOwner {
        if (t0 == 0) revert TooEarly();
        loiAt = uint64(block.timestamp);
        emit LoiRecorded(loiAt, ref);
    }

    function openPilot() external onlyOwner {
        if (t0 == 0) revert TooEarly();
        pilotAt = uint64(block.timestamp);
        emit PilotOpened(pilotAt);
    }

    function logPacket(bytes32 packetHash, bytes32 keyMaterialHash, string calldata note)
        external
        onlyOwner
        returns (bytes32 root)
    {
        if (pilotAt == 0) revert TooEarly();
        if (packetHash == bytes32(0) || keyMaterialHash == bytes32(0)) revert Bad();
        packets.push(
            Packet({packetHash: packetHash, keyMaterialHash: keyMaterialHash, at: uint64(block.timestamp), note: note})
        );
        root = keccak256(abi.encode("QKD-V2", packetHash, keyMaterialHash, packets.length, corridor));
        emit PacketLogged(packets.length - 1, packetHash, root);
    }

    function packetCount() external view returns (uint256) {
        return packets.length;
    }
}
