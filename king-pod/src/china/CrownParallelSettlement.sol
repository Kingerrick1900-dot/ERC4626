// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title CrownParallelSettlement
/// @notice CN parallel settlement layer — multi-rail clear ledger (not an L1 fork).
/// @dev Rails: Base=8453, Polygon=137, Scroll=534352. KAR posts clears; settle in payToken.
contract CrownParallelSettlement is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable payToken; // eUSD
    address public attest;
    address public kar; // KAR runner / agent

    struct Clear {
        uint64 srcChain;
        uint64 dstChain;
        address payer;
        address payee;
        uint256 amount;
        bytes32 ref; // SoftPOS / invoice / NFC receipt
        uint8 status; // 0 none, 1 posted, 2 settled, 3 canceled
        uint64 postedAt;
    }

    mapping(bytes32 => Clear) public clears; // clearId
    mapping(uint64 => bool) public railOk;

    event RailSet(uint64 indexed chainId, bool ok);
    event Posted(bytes32 indexed clearId, uint64 srcChain, uint64 dstChain, address payer, address payee, uint256 amount);
    event Settled(bytes32 indexed clearId, address payee, uint256 amount);
    event Canceled(bytes32 indexed clearId);
    event ModulesSet(address attest, address kar);

    error Auth();
    error BadRail();
    error BadClear();
    error Borders();
    error Exists();

    modifier onlyKarOrOwner() {
        if (msg.sender != owner && msg.sender != kar) revert Auth();
        _;
    }

    constructor(address payToken_, address owner_) Ownable(owner_) {
        require(payToken_ != address(0), "ZERO");
        payToken = IERC20(payToken_);
        railOk[8453] = true;
        railOk[137] = true;
        railOk[534352] = true;
    }

    function setModules(address attest_, address kar_) external onlyOwner {
        attest = attest_;
        kar = kar_;
        emit ModulesSet(attest_, kar_);
    }

    function setRail(uint64 chainId, bool ok) external onlyOwner {
        railOk[chainId] = ok;
        emit RailSet(chainId, ok);
    }

    /// @notice KAR posts a cross-rail clear intent (payer must approve this contract).
    function postClear(
        bytes32 clearId,
        uint64 srcChain,
        uint64 dstChain,
        address payer,
        address payee,
        uint256 amount,
        bytes32 ref
    ) external onlyKarOrOwner {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        if (!railOk[srcChain] || !railOk[dstChain]) revert BadRail();
        if (clearId == bytes32(0) || amount == 0 || payer == address(0) || payee == address(0)) revert BadClear();
        if (clears[clearId].status != 0) revert Exists();
        clears[clearId] = Clear({
            srcChain: srcChain,
            dstChain: dstChain,
            payer: payer,
            payee: payee,
            amount: amount,
            ref: ref,
            status: 1,
            postedAt: uint64(block.timestamp)
        });
        emit Posted(clearId, srcChain, dstChain, payer, payee, amount);
    }

    /// @notice Settle on this chain — pull payToken from payer → payee (CN desk clear).
    function settle(bytes32 clearId) external nonReentrant onlyKarOrOwner {
        Clear storage c = clears[clearId];
        if (c.status != 1) revert BadClear();
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        c.status = 2;
        payToken.safeTransferFrom(c.payer, c.payee, c.amount);
        emit Settled(clearId, c.payee, c.amount);
    }

    function cancel(bytes32 clearId) external onlyKarOrOwner {
        Clear storage c = clears[clearId];
        if (c.status != 1) revert BadClear();
        c.status = 3;
        emit Canceled(clearId);
    }
}
