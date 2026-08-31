// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface ILitePsmSell {
    function sellGem(uint256 usdcAmt, address to) external returns (uint256 eusdOut);
    function seedEusd(uint256 amt) external;
    function eusdReserve() external view returns (uint256);
}

interface IPrimeCreditSupply {
    function supply(uint256 amt) external;
}

/// @title CrownPrime7683Fill
/// @notice ERC-7683-style solver fill: front USDC → discounted eUSD; USDC lands as credit idle.
/// @dev Auction FUTURE fill: solvers compete on discountBps. Does not invent USDC — solvers bring it.
contract CrownPrime7683Fill is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant ORDER_TYPE =
        keccak256("CrownPrimeFill(address recipient,uint256 eusdOut,uint256 maxUsdcIn,uint32 fillDeadline,uint256 nonce)");

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    address public psm; // CrownLitePsm — optional; if set, fill may route via sellGem buffer
    address public credit; // CrownPrimeCredit
    address public feeSink; // SelfRepayingTreasury or Landing

    bool public publicFillEnabled = true;
    /// @notice Max discount solvers may take, in bps (100 = 1%).
    uint256 public maxDiscountBps = 100; // 1%
    /// @notice Protocol take on filled USDC in bps → feeSink (tax/sweep).
    uint256 public protocolFeeBps = 10; // 0.1%

    struct Order {
        address opener;
        address recipient;
        uint256 eusdOut;
        uint256 maxUsdcIn;
        uint32 fillDeadline;
        uint8 status; // 0 none, 1 open, 2 filled, 3 cancelled
        address filler;
        uint256 filledUsdc;
    }

    mapping(bytes32 => Order) public orders;
    mapping(address => uint256) public nonces;

    event OrderOpened(bytes32 indexed orderId, address indexed recipient, uint256 eusdOut, uint256 maxUsdcIn);
    event OrderFilled(bytes32 indexed orderId, address indexed filler, uint256 usdcIn, uint256 eusdOut, uint256 fee);
    event OrderCancelled(bytes32 indexed orderId);
    event ConfigSet(address psm, address credit, address feeSink);

    error BadOrder();
    error BadStatus();
    error Expired();
    error ShortFill();
    error NotPublic();
    error Dry();

    constructor(address eusd_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
    }

    function setConfig(address psm_, address credit_, address feeSink_) external onlyOwner {
        psm = psm_;
        credit = credit_;
        feeSink = feeSink_;
        emit ConfigSet(psm_, credit_, feeSink_);
    }

    function setPublicFillEnabled(bool v) external onlyOwner {
        publicFillEnabled = v;
    }

    function setFees(uint256 maxDiscountBps_, uint256 protocolFeeBps_) external onlyOwner {
        require(maxDiscountBps_ <= 1_000 && protocolFeeBps_ <= 500, "FEE");
        maxDiscountBps = maxDiscountBps_;
        protocolFeeBps = protocolFeeBps_;
    }

    /// @notice King/opener locks eUSD into this contract for solver fill inventory.
    function seedFillBuffer(uint256 eusdAmt) external onlyOwner nonReentrant {
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
    }

    function openOrder(address recipient, uint256 eusdOut, uint256 maxUsdcIn, uint32 fillDeadline)
        external
        nonReentrant
        returns (bytes32 orderId)
    {
        if (recipient == address(0) || eusdOut == 0 || maxUsdcIn == 0) revert BadOrder();
        if (fillDeadline <= block.timestamp) revert Expired();
        // Parity: maxUsdcIn should be ~ eusdOut/1e12 (allow discount up to maxDiscountBps)
        uint256 fairUsdc = eusdOut / 1e12;
        if (maxUsdcIn > fairUsdc) revert BadOrder();

        uint256 n = nonces[msg.sender]++;
        orderId = keccak256(abi.encode(ORDER_TYPE, msg.sender, recipient, eusdOut, maxUsdcIn, fillDeadline, n));
        orders[orderId] = Order({
            opener: msg.sender,
            recipient: recipient,
            eusdOut: eusdOut,
            maxUsdcIn: maxUsdcIn,
            fillDeadline: fillDeadline,
            status: 1,
            filler: address(0),
            filledUsdc: 0
        });
        emit OrderOpened(orderId, recipient, eusdOut, maxUsdcIn);
    }

    /// @notice Solver fronts `usdcIn` (≤ maxUsdcIn), receives `eusdOut` from buffer; USDC → credit + fee.
    function fill(bytes32 orderId, uint256 usdcIn) external nonReentrant {
        if (!publicFillEnabled) revert NotPublic();
        Order storage o = orders[orderId];
        if (o.status != 1) revert BadStatus();
        if (block.timestamp > o.fillDeadline) revert Expired();
        if (usdcIn == 0 || usdcIn > o.maxUsdcIn) revert ShortFill();
        if (eusd.balanceOf(address(this)) < o.eusdOut) revert Dry();

        // Discount check: usdcIn / fair >= (1 - maxDiscount)
        uint256 fair = o.eusdOut / 1e12;
        if (fair == 0) revert BadOrder();
        uint256 minUsdc = (fair * (10_000 - maxDiscountBps)) / 10_000;
        if (usdcIn < minUsdc) revert ShortFill();

        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);
        eusd.safeTransfer(o.recipient, o.eusdOut);

        uint256 fee = (usdcIn * protocolFeeBps) / 10_000;
        uint256 toCredit = usdcIn - fee;
        if (fee > 0 && feeSink != address(0)) {
            usdc.safeTransfer(feeSink, fee);
        }
        if (credit != address(0) && toCredit > 0) {
            usdc.safeApprove(credit, 0);
            usdc.safeApprove(credit, toCredit);
            IPrimeCreditSupply(credit).supply(toCredit);
        } else if (toCredit > 0 && psm != address(0)) {
            // Fallback: leave USDC in PSM via transfer to psm owner path — hold on this contract for owner sweep
            usdc.safeTransfer(psm, toCredit);
        }

        o.status = 2;
        o.filler = msg.sender;
        o.filledUsdc = usdcIn;
        emit OrderFilled(orderId, msg.sender, usdcIn, o.eusdOut, fee);
    }

    function cancel(bytes32 orderId) external nonReentrant {
        Order storage o = orders[orderId];
        if (o.status != 1) revert BadStatus();
        if (msg.sender != o.opener && msg.sender != owner) revert BadOrder();
        o.status = 3;
        emit OrderCancelled(orderId);
    }
}
