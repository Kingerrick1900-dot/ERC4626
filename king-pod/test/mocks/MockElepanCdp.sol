// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Test double: 8dp Elepan-like ERC20.
contract MockElepan8 {
    string public name = "elephanToken";
    string public symbol = "RSS";
    uint8 public constant decimals = 8;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        totalSupply += amt;
        balanceOf[to] += amt;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        if (a != type(uint256).max) allowance[f][msg.sender] = a - amt;
        balanceOf[f] -= amt;
        balanceOf[t] += amt;
        return true;
    }
}

contract MockElepanOracle {
    uint256 public price = 1e34; // soft $1

    function setPrice(uint256 p) external {
        price = p;
    }
}

/// @dev Test double for Elepan ZK wallet-bind gate.
contract MockZkElepanGate {
    mapping(address => bool) public proven;
    mapping(address => uint256) public thresholdOf;
    mapping(address => uint256) public provenAtOf;
    uint256 public proofTtl = 7 days;

    error Expired();

    function setProofTtl(uint256 ttl) external {
        proofTtl = ttl;
    }

    function setProven(address subject, bool v) external {
        proven[subject] = v;
        if (v) {
            thresholdOf[subject] = 700_000e6;
            provenAtOf[subject] = block.timestamp;
        }
    }

    function isProven(address subject) public view returns (bool) {
        if (!proven[subject]) return false;
        if (proofTtl > 0 && block.timestamp > provenAtOf[subject] + proofTtl) return false;
        return true;
    }

    function requireProven(address subject) external view {
        if (!isProven(subject)) revert Expired();
    }

    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid) {
        return (thresholdOf[subject], provenAtOf[subject], proven[subject]);
    }
}
