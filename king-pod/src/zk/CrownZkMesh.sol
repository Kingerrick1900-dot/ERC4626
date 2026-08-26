// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";

interface IGateMesh {
    function isProven(address subject) external view returns (bool);
}

/// @title CrownZkMesh
/// @notice Multi-chain ZK mesh: register bound/elepan/settlement gates per chainId.
/// @dev Prove once on any registered gate → mesh considers subject proven for that role.
contract CrownZkMesh is Ownable {
    enum Role {
        Bound,
        Elepan,
        Settlement
    }

    struct ChainGates {
        address bound;
        address elepan;
        address settlement;
        bool active;
    }

    mapping(uint64 => ChainGates) public chains;
    uint64[] public chainList;

    event ChainWired(uint64 indexed chainId, address bound, address elepan, address settlement);
    event ChainActive(uint64 indexed chainId, bool active);

    error BadChain();

    constructor(address owner_) Ownable(owner_) {}

    function wire(uint64 chainId, address bound, address elepan, address settlement) external onlyOwner {
        if (chainId == 0) revert BadChain();
        ChainGates storage g = chains[chainId];
        if (!g.active && g.bound == address(0)) chainList.push(chainId);
        g.bound = bound;
        g.elepan = elepan;
        g.settlement = settlement;
        g.active = true;
        emit ChainWired(chainId, bound, elepan, settlement);
    }

    function setActive(uint64 chainId, bool on) external onlyOwner {
        chains[chainId].active = on;
        emit ChainActive(chainId, on);
    }

    function chainCount() external view returns (uint256) {
        return chainList.length;
    }

    /// @notice Subject proven on this chain for Bound role (pack depth).
    function isProvenHere(address subject) public view returns (bool) {
        ChainGates memory g = chains[uint64(block.chainid)];
        if (!g.active || g.bound == address(0)) return false;
        return IGateMesh(g.bound).isProven(subject);
    }

    /// @notice Subject proven on ANY wired chain for Bound — mesh view (local calls only; cross-chain is attested off-domain).
    function isProvenAny(address subject) external view returns (bool) {
        uint256 n = chainList.length;
        for (uint256 i; i < n; ++i) {
            ChainGates memory g = chains[chainList[i]];
            if (!g.active || g.bound == address(0)) continue;
            // Only same-chain gates are callable; foreign addresses may revert — skip via extcodesize
            if (chainList[i] != uint64(block.chainid)) continue;
            if (IGateMesh(g.bound).isProven(subject)) return true;
        }
        return false;
    }

    function isElepanProven(address subject) external view returns (bool) {
        ChainGates memory g = chains[uint64(block.chainid)];
        if (!g.active || g.elepan == address(0)) return false;
        return IGateMesh(g.elepan).isProven(subject);
    }
}
