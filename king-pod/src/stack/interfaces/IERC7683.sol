// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice ERC-7683 cross-chain intent settlement surface (solver-network fills).
struct GaslessCrossChainOrder {
    address originSettler;
    address user;
    uint256 nonce;
    uint256 originChainId;
    uint32 openDeadline;
    uint32 fillDeadline;
    bytes32 orderDataType;
    bytes orderData;
}

struct ResolvedCrossChainOrder {
    address user;
    uint256 originChainId;
    uint32 openDeadline;
    uint32 fillDeadline;
    OutputToken[] maxSpent;
    OutputToken[] minReceived;
    FillInstruction[] fillInstructions;
}

struct OutputToken {
    bytes32 token;
    uint256 amount;
    bytes32 recipient;
}

struct FillInstruction {
    uint64 destinationChainId;
    bytes32 destinationSettler;
    bytes originData;
}

interface IOriginSettler {
    function open(GaslessCrossChainOrder calldata order, bytes calldata signature, bytes calldata originFillerData)
        external;
    function resolve(GaslessCrossChainOrder calldata order, bytes calldata originFillerData)
        external
        view
        returns (ResolvedCrossChainOrder memory);
}

interface IDestinationSettler {
    function fill(bytes32 orderId, bytes calldata originData, bytes calldata fillerData) external;
}

/// @notice Combined settlement contract for PSM queue + public solvers.
interface ISettlementContract is IOriginSettler, IDestinationSettler {
    function orderStatus(bytes32 orderId) external view returns (uint8);
}
