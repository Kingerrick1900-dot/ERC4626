// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {IERC8888} from "../stack/interfaces/IERC8888.sol";

interface ISettlementGate8888 {
    function canFill(bytes32 orderId, address filler, uint256 minUsdc) external view returns (bool);
    function submitProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata publicSignals
    ) external;
}

/// @title CrownElephantIntent8888
/// @notice One-call elephant intent: submit ZK settlement proof + transfer destToken to recipient.
/// @dev Replaces 7683 open/fill/settle split for kingdom fillers. Proof-gated.
contract CrownElephantIntent8888 is IERC8888, Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    ISettlementGate8888 public immutable settleGate;
    mapping(bytes32 => bool) public filled;

    error BadProof();
    error AlreadyFilled();
    error Expired();
    error BadAmt();

    constructor(address settleGate_, address owner_) Ownable(owner_) {
        require(settleGate_ != address(0), "ZERO");
        settleGate = ISettlementGate8888(settleGate_);
    }

    function fillElephant(
        ElephantIntent calldata intent,
        bytes calldata /* originData */,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata publicSignals
    ) external nonReentrant returns (bytes32 orderId) {
        if (block.timestamp > intent.deadline) revert Expired();
        if (intent.amount == 0 || intent.minOut == 0) revert BadAmt();
        orderId = intent.orderId;
        if (orderId == bytes32(0)) orderId = bytes32(publicSignals[2]);
        if (filled[orderId]) revert AlreadyFilled();

        // Submit / refresh settlement attestation then require canFill
        settleGate.submitProof(a, b, c, publicSignals);
        if (!settleGate.canFill(orderId, msg.sender, intent.minOut)) revert BadProof();

        filled[orderId] = true;
        IERC20(intent.destToken).safeTransferFrom(msg.sender, intent.recipient, intent.amount);
        emit ElephantFilled(orderId, msg.sender, intent.recipient, intent.amount);
    }
}
