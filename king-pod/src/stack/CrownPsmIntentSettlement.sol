// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownElepanAsyncVault} from "./CrownElepanAsyncVault.sol";
import {
    ISettlementContract,
    GaslessCrossChainOrder,
    ResolvedCrossChainOrder,
    OutputToken,
    FillInstruction
} from "./interfaces/IERC7683.sol";

/// @notice ERC-7683 settlement contract plugged into the ERC-7540 PSM queue.
/// @dev Solvers (Across / UniswapX / LI.FI style) `fill` on Base (front USDC),
///      then reclaim underlying via Scroll async vault fulfill + claim.
contract CrownPsmIntentSettlement is Ownable, ReentrancyGuard, ISettlementContract {
    using SafeTransfer for IERC20;

    bytes32 public constant ORDER_TYPE_PSM_REDEEM =
        keccak256("CrownPsmRedeem(address user,uint256 eusdAmt,address baseRecipient,uint256 minUsdc)");

    uint8 public constant STATUS_NONE = 0;
    uint8 public constant STATUS_OPEN = 1;
    uint8 public constant STATUS_FILLED = 2;
    uint8 public constant STATUS_SETTLED = 3;
    uint8 public constant STATUS_CANCELLED = 4;

    struct OrderRecord {
        address user;
        uint256 eusdAmt;
        address baseRecipient;
        uint256 minUsdc;
        address filler;
        uint256 filledUsdc;
        uint256 vaultRequestId;
        uint8 status;
        uint32 fillDeadline;
    }

    CrownElepanAsyncVault public immutable vault;
    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    uint64 public immutable scrollChainId;
    uint64 public immutable baseChainId;

    mapping(bytes32 => OrderRecord) public orders;
    mapping(address => uint256) public nonces;

    /// @notice Optional Base-side filler registry (public solvers welcome when open).
    bool public publicFillEnabled = true;

    event OrderOpened(bytes32 indexed orderId, address indexed user, uint256 eusdAmt, uint256 minUsdc);
    event OrderFilled(bytes32 indexed orderId, address indexed filler, uint256 usdcPaid);
    event OrderSettled(bytes32 indexed orderId, uint256 vaultRequestId, uint256 usdcReclaimed);
    event PublicFillSet(bool enabled);

    error BadOrder();
    error BadStatus();
    error Expired();
    error ShortFill();
    error NotFiller();

    constructor(
        address vault_,
        address usdc_,
        uint64 scrollChainId_,
        uint64 baseChainId_,
        address owner_
    ) Ownable(owner_) {
        require(vault_ != address(0) && usdc_ != address(0), "ZERO");
        vault = CrownElepanAsyncVault(vault_);
        eusd = vault.asset();
        usdc = IERC20(usdc_);
        scrollChainId = scrollChainId_;
        baseChainId = baseChainId_;
    }

    function setPublicFillEnabled(bool v) external onlyOwner {
        publicFillEnabled = v;
        emit PublicFillSet(v);
    }

    function orderStatus(bytes32 orderId) external view returns (uint8) {
        return orders[orderId].status;
    }

    function orderIdOf(GaslessCrossChainOrder calldata order) public pure returns (bytes32) {
        return keccak256(abi.encode(order));
    }

    /// @notice Open a redeem intent. User's eUSD is queued into ERC-7540 vault immediately.
    function open(GaslessCrossChainOrder calldata order, bytes calldata, /* signature */ bytes calldata originFillerData)
        external
        nonReentrant
    {
        if (block.timestamp > order.openDeadline) revert Expired();
        if (order.originSettler != address(this)) revert BadOrder();
        if (order.originChainId != scrollChainId && order.originChainId != block.chainid) revert BadOrder();

        (address user, uint256 eusdAmt, address baseRecipient, uint256 minUsdc) =
            abi.decode(order.orderData, (address, uint256, address, uint256));
        if (user == address(0) || eusdAmt == 0 || baseRecipient == address(0)) revert BadOrder();
        // silence unused; signature path reserved for EIP-712 gasless open
        originFillerData;

        bytes32 id = orderIdOf(order);
        if (orders[id].status != STATUS_NONE) revert BadStatus();

        // Pull eUSD from user (or operator) into vault via this contract as operator path:
        // User must approve this settlement for eUSD; we requestRedeem with controller=this.
        eusd.safeTransferFrom(user, address(this), eusdAmt);
        eusd.safeApprove(address(vault), eusdAmt);

        // Ensure vault recognizes this contract as operator for itself
        if (!vault.isOperator(address(this), address(this))) {
            vault.setOperator(address(this), true);
        }

        uint256 reqId = vault.requestRedeem(eusdAmt, address(this), address(this));

        orders[id] = OrderRecord({
            user: user,
            eusdAmt: eusdAmt,
            baseRecipient: baseRecipient,
            minUsdc: minUsdc,
            filler: address(0),
            filledUsdc: 0,
            vaultRequestId: reqId,
            status: STATUS_OPEN,
            fillDeadline: order.fillDeadline
        });
        nonces[user] = order.nonce + 1;

        emit OrderOpened(id, user, eusdAmt, minUsdc);
    }

    function resolve(GaslessCrossChainOrder calldata order, bytes calldata)
        external
        view
        returns (ResolvedCrossChainOrder memory resolved)
    {
        (address user, uint256 eusdAmt, address baseRecipient, uint256 minUsdc) =
            abi.decode(order.orderData, (address, uint256, address, uint256));

        resolved.user = user;
        resolved.originChainId = order.originChainId;
        resolved.openDeadline = order.openDeadline;
        resolved.fillDeadline = order.fillDeadline;

        resolved.maxSpent = new OutputToken[](1);
        resolved.maxSpent[0] = OutputToken({
            token: bytes32(uint256(uint160(address(eusd)))),
            amount: eusdAmt,
            recipient: bytes32(uint256(uint160(address(this))))
        });

        resolved.minReceived = new OutputToken[](1);
        resolved.minReceived[0] = OutputToken({
            token: bytes32(uint256(uint160(address(usdc)))),
            amount: minUsdc,
            recipient: bytes32(uint256(uint160(baseRecipient)))
        });

        resolved.fillInstructions = new FillInstruction[](1);
        resolved.fillInstructions[0] = FillInstruction({
            destinationChainId: uint64(baseChainId),
            destinationSettler: bytes32(uint256(uint160(address(this)))),
            originData: abi.encode(orderIdOf(order))
        });
    }

    /// @notice Solver fronts USDC on the fill chain to the user recipient.
    function fill(bytes32 orderId, bytes calldata originData, bytes calldata fillerData) external nonReentrant {
        if (!publicFillEnabled && msg.sender != owner) revert NotFiller();
        if (orders[orderId].status == STATUS_NONE && originData.length >= 32) {
            orderId = abi.decode(originData, (bytes32));
        }
        OrderRecord storage o = orders[orderId];
        if (o.status != STATUS_OPEN) revert BadStatus();
        if (block.timestamp > o.fillDeadline) revert Expired();

        uint256 pay = o.minUsdc;
        if (fillerData.length >= 32) {
            uint256 offer = abi.decode(fillerData, (uint256));
            if (offer > pay) pay = offer;
        }
        if (pay < o.minUsdc) revert ShortFill();

        usdc.safeTransferFrom(msg.sender, o.baseRecipient, pay);
        o.filler = msg.sender;
        o.filledUsdc = pay;
        o.status = STATUS_FILLED;

        emit OrderFilled(orderId, msg.sender, pay);
    }

    /// @notice After fill, reclaim PSM USDC on Scroll via vault fulfill + claim → filler.
    function settle(bytes32 orderId) external nonReentrant returns (uint256 usdcOut) {
        OrderRecord storage o = orders[orderId];
        if (o.status != STATUS_FILLED && o.status != STATUS_OPEN) revert BadStatus();
        // Allow settle without Base fill when solver wants atomic Scroll reclaim only
        address claimant = o.filler != address(0) ? o.filler : msg.sender;

        if (vault.pendingRedeemRequest(o.vaultRequestId, address(this)) > 0) {
            vault.fulfillRedeem(o.vaultRequestId);
        }
        usdcOut = vault.claimRedeem(o.vaultRequestId, claimant);
        o.status = STATUS_SETTLED;

        emit OrderSettled(orderId, o.vaultRequestId, usdcOut);
    }
}
