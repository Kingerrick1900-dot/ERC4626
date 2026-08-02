// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../core/Core.sol";

/// @notice Elepan-native credit attestation gate (Scroll dominion).
/// @dev Same surface as ZK wallet-bind: isProven + attestations + minThreshold.
///      On Scroll, Elepan IS the ruleset — King posts attested capacity; completer honors it.
///      Upgrade path: replace owner attest with Groth16 verifier without changing credit ABI.
contract CrownSovereignGate is Ownable {
    uint256 public minThreshold = 700_000e6; // $700k (6dp)
    uint256 public proofTtl = 30 days;

    struct Attestation {
        uint256 threshold; // USD 6dp capacity
        uint256 provenAt;
        bool valid;
    }

    mapping(address => Attestation) private _att;

    event Proven(address indexed subject, uint256 threshold, uint256 provenAt);
    event MinThresholdSet(uint256 minThreshold);
    event TtlSet(uint256 proofTtl);
    event Revoked(address indexed subject);

    error BadThreshold();
    error BadSubject();

    constructor(address owner_) Ownable(owner_) {}

    function setMinThreshold(uint256 t) external onlyOwner {
        if (t == 0) revert BadThreshold();
        minThreshold = t;
        emit MinThresholdSet(t);
    }

    function setTtl(uint256 ttl) external onlyOwner {
        proofTtl = ttl;
        emit TtlSet(ttl);
    }

    /// @notice King posts sovereign credit capacity for subject (Elepan ruleset).
    function attest(address subject, uint256 threshold) external onlyOwner {
        if (subject == address(0)) revert BadSubject();
        if (threshold < minThreshold) revert BadThreshold();
        _att[subject] = Attestation({threshold: threshold, provenAt: block.timestamp, valid: true});
        emit Proven(subject, threshold, block.timestamp);
    }

    function revoke(address subject) external onlyOwner {
        delete _att[subject];
        emit Revoked(subject);
    }

    function isProven(address subject) public view returns (bool) {
        Attestation memory a = _att[subject];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        return true;
    }

    /// @notice Compatible with CrownZkCredit / completer ABI.
    function attestations(address subject)
        external
        view
        returns (uint256 threshold, uint256 provenAt, bool valid)
    {
        Attestation memory a = _att[subject];
        return (a.threshold, a.provenAt, a.valid && isProven(subject));
    }
}
