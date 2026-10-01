// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkAttestQkd {
    function attestLive(bytes32 payloadHash) external;
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function epoch() external view returns (uint256);
}

/// @title CrownQkdPilot
/// @notice China corridor QKD pilot log — partner packets bump attest epoch. Not a telco stack.
/// @dev Partner: Conflux + CN telco. Timeline: T0=first USDC fill, +30d LOI, +90d pilot packets.
contract CrownQkdPilot is Ownable {
    IZkAttestQkd public attest;
    string public corridor = "Shenzhen-Shanghai";
    string public partner = "Conflux+CN-telco";
    uint64 public t0; // set when first USDC fill confirmed
    uint64 public loiAt;
    uint64 public pilotAt;

    struct Packet {
        bytes32 packetHash;
        bytes32 keyMaterialHash; // never raw keys — hash only
        uint64 at;
        string note;
    }

    Packet[] public packets;

    event T0Set(uint64 t0);
    event LoiRecorded(uint64 at, string ref);
    event PilotOpened(uint64 at);
    event PacketLogged(uint256 indexed idx, bytes32 packetHash, uint256 epoch);

    error Bad();
    error TooEarly();

    constructor(address attest_, address owner_) Ownable(owner_) {
        attest = IZkAttestQkd(attest_);
    }

    function setAttest(address a) external onlyOwner {
        attest = IZkAttestQkd(a);
    }

    /// @notice King marks first USDC fill — starts QKD clock.
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

    /// @notice Log QKD packet and refresh borders via attest.
    function logPacket(bytes32 packetHash, bytes32 keyMaterialHash, string calldata note) external onlyOwner {
        if (pilotAt == 0) revert TooEarly();
        if (packetHash == bytes32(0)) revert Bad();
        packets.push(
            Packet({packetHash: packetHash, keyMaterialHash: keyMaterialHash, at: uint64(block.timestamp), note: note})
        );
        bytes32 root = keccak256(abi.encode("QKD", packetHash, keyMaterialHash, packets.length));
        attest.commitPayrollRoot(root, true);
        attest.attestLive(root);
        emit PacketLogged(packets.length - 1, packetHash, attest.epoch());
    }

    function packetCount() external view returns (uint256) {
        return packets.length;
    }

    function timeline() external view returns (uint64 t0_, uint64 loi, uint64 pilot, uint256 dueLoi, uint256 duePilot) {
        t0_ = t0;
        loi = loiAt;
        pilot = pilotAt;
        dueLoi = t0 == 0 ? 0 : uint256(t0) + 30 days;
        duePilot = t0 == 0 ? 0 : uint256(t0) + 90 days;
    }
}
