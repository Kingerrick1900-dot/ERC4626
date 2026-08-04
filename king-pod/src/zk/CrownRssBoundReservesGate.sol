// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable} from "../lib/Core.sol";

/// @notice Elepan BoundReservesGate fork — on-chain RSS balanceOf binding (no free witness).
/// @dev attestLive: authorized attestor + IERC20(rss).balanceOf(subject) >= threshold.
contract CrownRssBoundReservesGate is Ownable {
    IERC20 public immutable rss;
    uint256 public minThreshold = 1_000_000 ether; // 1M RSS raw (18dp)
    uint256 public proofTtl = 7 days;

    struct Attestation {
        uint256 threshold;
        uint256 provenAt;
        bool valid;
    }

    mapping(address => Attestation) public attestations;
    mapping(address => bool) public attestors;

    event Proven(address indexed subject, uint256 threshold, uint256 provenAt);
    event MinThreshold(uint256 minThreshold);
    event Ttl(uint256 proofTtl);
    event Attestor(address indexed who, bool ok);

    error BadThreshold();
    error BadSubject();
    error NotAttestor();
    error ShortBalance();
    error Expired();

    constructor(address rss_, address owner_) Ownable(owner_) {
        require(rss_ != address(0), "ZERO");
        rss = IERC20(rss_);
    }

    function setMinThreshold(uint256 t) external onlyOwner {
        if (t == 0) revert BadThreshold();
        minThreshold = t;
        emit MinThreshold(t);
    }

    function setTtl(uint256 ttl) external onlyOwner {
        proofTtl = ttl;
        emit Ttl(ttl);
    }

    function setAttestor(address who, bool ok) external onlyOwner {
        attestors[who] = ok;
        emit Attestor(who, ok);
    }

    /// @notice Live attest — subject must hold ≥ threshold RSS on-chain now.
    function attestLive(address subject, uint256 threshold) external {
        if (!attestors[msg.sender] && msg.sender != owner) revert NotAttestor();
        if (subject == address(0)) revert BadSubject();
        if (threshold < minThreshold) revert BadThreshold();
        if (rss.balanceOf(subject) < threshold) revert ShortBalance();

        attestations[subject] =
            Attestation({threshold: threshold, provenAt: block.timestamp, valid: true});
        emit Proven(subject, threshold, block.timestamp);
    }

    function isProven(address subject) public view returns (bool) {
        Attestation memory a = attestations[subject];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        return true;
    }

    function requireProven(address subject) external view {
        if (!isProven(subject)) revert Expired();
    }
}
