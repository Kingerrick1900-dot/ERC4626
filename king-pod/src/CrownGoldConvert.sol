// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface ISwapRouter02G {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title CrownGoldConvert — Route B
/// @notice Controlled gold-rail → USDC via limit asks + TWAMM fills. Proceeds to HOT only.
/// @dev King Morpho gold borrow = NONE. No flash. Fillers pay USDC; tokens leave escrow.
contract CrownGoldConvert is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    address public immutable hot;
    ISwapRouter02G public router; // optional Uni path

    mapping(address => bool) public sellable; // kXAU, yRSS, …
    mapping(address => uint8) public tokenDecimals;

    uint256 public targetUsdc; // scoreboard target (informational)
    uint256 public filledUsdc; // cumulative USDC delivered to HOT
    uint256 public maxFillUsdc = 150_000_000000; // $150k per fill

    struct Ask {
        address token;
        uint256 amountIn;
        uint256 minUsdcOut;
        uint64 deadline;
        bool open;
    }

    struct Twamm {
        address token;
        uint256 totalIn;
        uint256 soldIn;
        uint256 minUsdcPerFull; // USDC-6dp per 1 full token (10**decimals)
        uint64 start;
        uint64 end;
        bool open;
    }

    Ask[] public asks;
    Twamm[] public twamms;

    event SellableSet(address indexed token, bool on, uint8 decimals);
    event RouterSet(address indexed router);
    event TargetSet(uint256 usdcTarget);
    event MaxFillSet(uint256 maxUsdc);
    event AskPosted(uint256 indexed id, address token, uint256 amountIn, uint256 minUsdcOut, uint64 deadline);
    event AskFilled(uint256 indexed id, address filler, uint256 usdcPaid, uint256 tokenOut);
    event AskCancelled(uint256 indexed id);
    event TwammPosted(
        uint256 indexed id, address token, uint256 totalIn, uint256 minUsdcPerFull, uint64 start, uint64 end
    );
    event TwammFilled(uint256 indexed id, address filler, uint256 tokenIn, uint256 usdcPaid);
    event UniSold(address indexed token, uint256 amountIn, uint256 usdcOut);

    error BadToken();
    error BadAmt();
    error Closed();
    error Expired();
    error Early();
    error MaxFill();
    error TargetHit();

    constructor(address usdc_, address hot_, address router_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && hot_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        hot = hot_;
        if (router_ != address(0)) router = ISwapRouter02G(router_);
    }

    function setSellable(address token, bool on, uint8 decimals_) external onlyOwner {
        if (token == address(0)) revert BadToken();
        sellable[token] = on;
        tokenDecimals[token] = decimals_;
        emit SellableSet(token, on, decimals_);
    }

    function setRouter(address router_) external onlyOwner {
        router = ISwapRouter02G(router_);
        emit RouterSet(router_);
    }

    function setTargetUsdc(uint256 t) external onlyOwner {
        targetUsdc = t;
        emit TargetSet(t);
    }

    function setMaxFillUsdc(uint256 m) external onlyOwner {
        maxFillUsdc = m;
        emit MaxFillSet(m);
    }

    /// @notice Escrow `amountIn` sellable tokens as a limit ask. Filler pays ≥ minUsdcOut to HOT.
    function postAsk(address token, uint256 amountIn, uint256 minUsdcOut, uint64 deadline)
        external
        onlyOwner
        nonReentrant
        returns (uint256 id)
    {
        if (!sellable[token]) revert BadToken();
        if (amountIn == 0 || minUsdcOut == 0) revert BadAmt();
        if (deadline <= block.timestamp) revert Expired();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        id = asks.length;
        asks.push(Ask({token: token, amountIn: amountIn, minUsdcOut: minUsdcOut, deadline: deadline, open: true}));
        emit AskPosted(id, token, amountIn, minUsdcOut, deadline);
    }

    function fillAsk(uint256 id) external nonReentrant {
        if (id >= asks.length) revert BadAmt();
        Ask storage a = asks[id];
        if (!a.open) revert Closed();
        if (block.timestamp > a.deadline) revert Expired();
        if (a.minUsdcOut > maxFillUsdc) revert MaxFill();
        if (targetUsdc > 0 && filledUsdc >= targetUsdc) revert TargetHit();

        a.open = false;
        usdc.safeTransferFrom(msg.sender, hot, a.minUsdcOut);
        IERC20(a.token).safeTransfer(msg.sender, a.amountIn);
        filledUsdc += a.minUsdcOut;
        emit AskFilled(id, msg.sender, a.minUsdcOut, a.amountIn);
    }

    function cancelAsk(uint256 id) external onlyOwner nonReentrant {
        if (id >= asks.length) revert BadAmt();
        Ask storage a = asks[id];
        if (!a.open) revert Closed();
        a.open = false;
        IERC20(a.token).safeTransfer(owner, a.amountIn);
        emit AskCancelled(id);
    }

    /// @notice Post TWAMM window. Fills vest linearly by time; price floor = minUsdcPerFull.
    function postTwamm(address token, uint256 totalIn, uint256 minUsdcPerFull, uint64 start, uint64 end)
        external
        onlyOwner
        nonReentrant
        returns (uint256 id)
    {
        if (!sellable[token]) revert BadToken();
        if (totalIn == 0 || minUsdcPerFull == 0) revert BadAmt();
        if (end <= start || end <= block.timestamp) revert Expired();
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalIn);
        id = twamms.length;
        twamms.push(
            Twamm({
                token: token,
                totalIn: totalIn,
                soldIn: 0,
                minUsdcPerFull: minUsdcPerFull,
                start: start,
                end: end,
                open: true
            })
        );
        emit TwammPosted(id, token, totalIn, minUsdcPerFull, start, end);
    }

    /// @notice How many tokens are vested and still unsold.
    function twammAvailable(uint256 id) public view returns (uint256) {
        if (id >= twamms.length) return 0;
        Twamm storage t = twamms[id];
        if (!t.open) return 0;
        if (block.timestamp < t.start) return 0;
        uint256 elapsed = block.timestamp >= t.end ? (t.end - t.start) : (block.timestamp - t.start);
        uint256 vested = (t.totalIn * elapsed) / (t.end - t.start);
        if (vested <= t.soldIn) return 0;
        return vested - t.soldIn;
    }

    function fillTwamm(uint256 id, uint256 amountIn) external nonReentrant {
        if (id >= twamms.length) revert BadAmt();
        Twamm storage t = twamms[id];
        if (!t.open) revert Closed();
        if (block.timestamp < t.start) revert Early();
        if (amountIn == 0) revert BadAmt();
        uint256 avail = twammAvailable(id);
        if (amountIn > avail) amountIn = avail;
        if (amountIn == 0) revert BadAmt();

        uint8 dec = tokenDecimals[t.token];
        if (dec == 0) dec = 18;
        uint256 usdcDue = (amountIn * t.minUsdcPerFull) / (10 ** uint256(dec));
        if (usdcDue == 0) revert BadAmt();
        if (usdcDue > maxFillUsdc) revert MaxFill();
        if (targetUsdc > 0 && filledUsdc + usdcDue > targetUsdc) {
            // clip to remaining target
            uint256 remain = targetUsdc - filledUsdc;
            if (remain == 0) revert TargetHit();
            amountIn = (remain * (10 ** uint256(dec))) / t.minUsdcPerFull;
            if (amountIn == 0 || amountIn > avail) revert BadAmt();
            usdcDue = (amountIn * t.minUsdcPerFull) / (10 ** uint256(dec));
        }

        t.soldIn += amountIn;
        if (t.soldIn >= t.totalIn || (targetUsdc > 0 && filledUsdc + usdcDue >= targetUsdc)) {
            t.open = false;
        }

        usdc.safeTransferFrom(msg.sender, hot, usdcDue);
        IERC20(t.token).safeTransfer(msg.sender, amountIn);
        filledUsdc += usdcDue;
        emit TwammFilled(id, msg.sender, amountIn, usdcDue);
    }

    function cancelTwamm(uint256 id) external onlyOwner nonReentrant {
        if (id >= twamms.length) revert BadAmt();
        Twamm storage t = twamms[id];
        if (!t.open) revert Closed();
        t.open = false;
        uint256 left = t.totalIn - t.soldIn;
        if (left > 0) IERC20(t.token).safeTransfer(owner, left);
    }

    /// @notice Optional Uni V3 market sell when pool depth exists. Proceeds → HOT.
    function uniSell(address token, uint256 amountIn, uint256 minUsdcOut, uint24 fee)
        external
        onlyOwner
        nonReentrant
        returns (uint256 out)
    {
        if (!sellable[token]) revert BadToken();
        if (amountIn == 0) revert BadAmt();
        if (address(router) == address(0)) revert BadToken();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(token).safeApprove(address(router), 0);
        IERC20(token).safeApprove(address(router), amountIn);
        out = router.exactInputSingle(
            ISwapRouter02G.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: address(usdc),
                fee: fee,
                recipient: hot,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut,
                sqrtPriceLimitX96: 0
            })
        );
        filledUsdc += out;
        emit UniSold(token, amountIn, out);
    }

    function book()
        external
        view
        returns (uint256 target, uint256 filled, uint256 askCount, uint256 twammCount, uint256 maxFill)
    {
        return (targetUsdc, filledUsdc, asks.length, twamms.length, maxFillUsdc);
    }
}
