// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice Kingdom Agent Runtime allowlist — default deny, steel allow.
/// @dev KAR must check allowed(target, selector) before any broadcast.
contract CrownAllowlist is Ownable {
    mapping(address => mapping(bytes4 => bool)) public allowed;
    mapping(address => bool) public targetAny; // rare: allow all selectors on target
    address public attest; // optional borders brake
    bool public requireBorders = true;

    event Allowed(address indexed target, bytes4 indexed selector, bool ok);
    event TargetAny(address indexed target, bool ok);
    event AttestSet(address indexed attest);
    event RequireBorders(bool on);

    error NotAllowed(address target, bytes4 selector);
    error BordersDown();

    constructor(address owner_) Ownable(owner_) {}

    function setAttest(address a) external onlyOwner {
        attest = a;
        emit AttestSet(a);
    }

    function setRequireBorders(bool on) external onlyOwner {
        requireBorders = on;
        emit RequireBorders(on);
    }

    function setAllowed(address target, bytes4 selector, bool ok) external onlyOwner {
        allowed[target][selector] = ok;
        emit Allowed(target, selector, ok);
    }

    function setAllowedBatch(address[] calldata targets, bytes4[] calldata selectors, bool ok)
        external
        onlyOwner
    {
        require(targets.length == selectors.length, "LEN");
        for (uint256 i; i < targets.length; i++) {
            allowed[targets[i]][selectors[i]] = ok;
            emit Allowed(targets[i], selectors[i], ok);
        }
    }

    function setTargetAny(address target, bool ok) external onlyOwner {
        targetAny[target] = ok;
        emit TargetAny(target, ok);
    }

    function isAllowed(address target, bytes4 selector) public view returns (bool) {
        if (targetAny[target]) return true;
        return allowed[target][selector];
    }

    /// @notice KAR entry: reverts unless allowlisted (+ optional bordersSecure).
    function check(address target, bytes4 selector) external view {
        if (requireBorders && attest != address(0)) {
            (bool ok, bytes memory data) =
                attest.staticcall(abi.encodeWithSignature("bordersSecure()"));
            if (!ok || data.length < 32 || !abi.decode(data, (bool))) revert BordersDown();
        }
        if (!isAllowed(target, selector)) revert NotAllowed(target, selector);
    }

    function checkCalldata(address target, bytes calldata data) external view {
        bytes4 sel = data.length < 4 ? bytes4(0) : bytes4(data[0:4]);
        if (requireBorders && attest != address(0)) {
            (bool ok, bytes memory ret) =
                attest.staticcall(abi.encodeWithSignature("bordersSecure()"));
            if (!ok || ret.length < 32 || !abi.decode(ret, (bool))) revert BordersDown();
        }
        if (!isAllowed(target, sel)) revert NotAllowed(target, sel);
    }
}
