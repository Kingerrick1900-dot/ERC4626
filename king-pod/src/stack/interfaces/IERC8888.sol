// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice ERC-8888 — Elephant intent: cross-chain fill + ZK proof in one call.
/// @dev Successor doctrine to ERC-7683 open/fill/settle split. Filler must be ZK-proven.
interface IERC8888 {
    struct ElephantIntent {
        bytes32 orderId;
        address originToken;
        address destToken;
        uint256 amount;
        uint64 originChain;
        uint64 destChain;
        address recipient;
        uint256 minOut;
        uint256 deadline;
    }

    function fillElephant(
        ElephantIntent calldata intent,
        bytes calldata originData,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata publicSignals
    ) external returns (bytes32 orderId);

    event ElephantFilled(bytes32 indexed orderId, address indexed filler, address recipient, uint256 amount);
}
