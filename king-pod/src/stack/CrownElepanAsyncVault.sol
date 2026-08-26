// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {ICrownGoldParityPsm} from "./interfaces/ICrownGoldParityPsm.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540.sol";

/// @notice ERC-7540 async redemption vault wrapping Scroll Gold Parity PSM (0x064489…75dA).
/// @dev Users `requestRedeem` eUSD → queued. Operator/solver `fulfillRedeem` calls PSM.redeemUsdc
///      in batch-safe steps. Users `claimRedeem` for USDC. Decouples request from instant fill.
contract CrownElepanAsyncVault is Ownable, ReentrancyGuard, IERC7540Redeem {
    using SafeTransfer for IERC20;

    enum Status {
        None,
        Pending,
        Claimable,
        Claimed,
        Cancelled
    }

    struct Request {
        address controller;
        address owner;
        uint256 eusdAssets; // 18dp
        uint256 claimableUsdc; // 6dp once fulfilled
        Status status;
    }

    ICrownGoldParityPsm public immutable psm;
    IERC20 public immutable asset; // Scroll eUSD
    IERC20 public immutable usdc;

    uint256 public nextRequestId = 1;
    mapping(uint256 => Request) public requests;
    mapping(address => mapping(address => bool)) internal _operators;

    /// @notice Max eUSD that can be fulfilled in one batch (race / liquidity guard).
    uint256 public maxBatchEusd = 1_000_000e18;

    event OperatorSet(address indexed controller, address indexed operator, bool approved);
    event Fulfilled(uint256 indexed requestId, uint256 eusdIn, uint256 usdcOut);
    event BatchFulfilled(uint256 count, uint256 eusdTotal, uint256 usdcTotal);
    event MaxBatchSet(uint256 maxBatchEusd);

    error BadAmt();
    error BadStatus();
    error NotController();
    error NotOperator();
    error BatchCap();

    constructor(address psm_, address owner_) Ownable(owner_) {
        require(psm_ != address(0), "PSM");
        psm = ICrownGoldParityPsm(psm_);
        asset = IERC20(psm.eusd());
        usdc = IERC20(psm.usdc());
    }

    function setMaxBatchEusd(uint256 v) external onlyOwner {
        maxBatchEusd = v;
        emit MaxBatchSet(v);
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    function isOperator(address controller, address operator) public view returns (bool) {
        return controller == operator || _operators[controller][operator];
    }

    /// @notice Lock eUSD into the async redeem queue. No PSM call yet.
    function requestRedeem(uint256 assets, address controller, address owner_)
        external
        nonReentrant
        returns (uint256 requestId)
    {
        if (assets == 0) revert BadAmt();
        if (controller == address(0)) controller = msg.sender;
        if (owner_ == address(0)) owner_ = msg.sender;
        if (msg.sender != owner_ && !isOperator(owner_, msg.sender)) revert NotOperator();

        asset.safeTransferFrom(owner_, address(this), assets);

        requestId = nextRequestId++;
        requests[requestId] = Request({
            controller: controller,
            owner: owner_,
            eusdAssets: assets,
            claimableUsdc: 0,
            status: Status.Pending
        });

        emit RedeemRequest(controller, owner_, requestId, msg.sender, assets);
    }

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256) {
        Request memory r = requests[requestId];
        if (r.controller != controller || r.status != Status.Pending) return 0;
        return r.eusdAssets;
    }

    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256) {
        Request memory r = requests[requestId];
        if (r.controller != controller || r.status != Status.Claimable) return 0;
        return r.eusdAssets;
    }

    /// @notice Operator fulfills one pending request against PSM USDC reserves.
    function fulfillRedeem(uint256 requestId) external nonReentrant returns (uint256 usdcOut) {
        Request storage r = requests[requestId];
        if (r.status != Status.Pending) revert BadStatus();
        if (!isOperator(r.controller, msg.sender) && msg.sender != owner) revert NotOperator();
        if (r.eusdAssets > maxBatchEusd) revert BatchCap();

        usdcOut = _fulfill(requestId, r);
    }

    /// @notice Batch fulfill — eliminates per-user execution races.
    function fulfillRedeemBatch(uint256[] calldata ids)
        external
        nonReentrant
        returns (uint256 eusdTotal, uint256 usdcTotal)
    {
        uint256 n = ids.length;
        for (uint256 i; i < n; ++i) {
            Request storage r = requests[ids[i]];
            if (r.status != Status.Pending) continue;
            if (!isOperator(r.controller, msg.sender) && msg.sender != owner) revert NotOperator();
            eusdTotal += r.eusdAssets;
            if (eusdTotal > maxBatchEusd) revert BatchCap();
            usdcTotal += _fulfill(ids[i], r);
        }
        emit BatchFulfilled(n, eusdTotal, usdcTotal);
    }

    function claimRedeem(uint256 requestId, address receiver) external nonReentrant returns (uint256 outAmt) {
        Request storage r = requests[requestId];
        if (r.status != Status.Claimable) revert BadStatus();
        if (msg.sender != r.controller && !isOperator(r.controller, msg.sender)) revert NotController();
        if (receiver == address(0)) receiver = r.controller;

        outAmt = r.claimableUsdc;
        r.status = Status.Claimed;
        r.claimableUsdc = 0;

        usdc.safeTransfer(receiver, outAmt);
        emit RedeemClaimed(requestId, receiver, outAmt);
    }

    /// @notice Cancel pending request — return eUSD to owner (pre-fulfill only).
    function cancelRedeem(uint256 requestId) external nonReentrant {
        Request storage r = requests[requestId];
        if (r.status != Status.Pending) revert BadStatus();
        if (msg.sender != r.controller && !isOperator(r.controller, msg.sender)) revert NotController();
        uint256 amt = r.eusdAssets;
        r.status = Status.Cancelled;
        r.eusdAssets = 0;
        asset.safeTransfer(r.owner, amt);
    }

    function _fulfill(uint256 requestId, Request storage r) internal returns (uint256 usdcOut) {
        uint256 eusdAmt = r.eusdAssets;
        asset.safeApprove(address(psm), eusdAmt);
        usdcOut = psm.redeemUsdc(eusdAmt, address(this));

        r.claimableUsdc = usdcOut;
        r.status = Status.Claimable;

        emit Fulfilled(requestId, eusdAmt, usdcOut);
        emit RedeemClaimable(requestId, eusdAmt, usdcOut);
    }
}
