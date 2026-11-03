// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IOceanRouter {
    /// @notice Execute a rotation that should return ≥ usdcIn + edge. Router pulls USDC from OceanArb.
    function rotate(uint256 usdcIn, uint256 minUsdcOut, bytes calldata routeData) external returns (uint256 usdcOut);
}

interface IColdBufferOcean {
    function receiveYield(uint256 amt, bytes32 tag) external;
}

interface IZkGateOcean {
    function isProven(address subject) external view returns (bool);
}

/// @notice Cross-chain Ocean arb sleeve — same bytecode Base / Polygon / Scroll.
/// @dev Capital = real USDC POL (pool operating liquidity). Keeper calls rotate when edge ≥ minEdgeBps.
///      Package: 3M USDC/chain × 3 = 9M; 0.2% edge × rotations → ColdBuffer.
contract OceanArb is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant TAG_OCEAN = bytes32("OCEAN_ARB");

    IERC20 public immutable usdc;
    address public immutable king;
    uint256 public immutable chainBudget; // soft budget label (e.g. 3M)

    IOceanRouter public router;
    IColdBufferOcean public coldBuffer;
    IZkGateOcean public gate;

    uint256 public minEdgeBps; // default 20 = 0.2%
    uint256 public maxRotate; // per-tx USDC cap
    uint256 public totalSeeded;
    uint256 public totalProfit;
    uint256 public rotations;
    bool public armed;

    event Armed(bool ok);
    event RouterSet(address router);
    event ColdBufferSet(address buffer);
    event GateSet(address gate);
    event EdgeBps(uint256 bps);
    event Seeded(uint256 amt);
    event Rotated(uint256 usdcIn, uint256 usdcOut, uint256 profit);
    event ProfitPushed(uint256 amt);

    error Bad();
    error NotArmed();
    error NotProven();
    error NoEdge();
    error Empty();

    constructor(address usdc_, address king_, address owner_, uint256 chainBudget_) Ownable(owner_) {
        if (usdc_ == address(0) || king_ == address(0) || chainBudget_ == 0) revert Bad();
        usdc = IERC20(usdc_);
        king = king_;
        chainBudget = chainBudget_;
        minEdgeBps = 20;
        maxRotate = chainBudget_;
    }

    function setArmed(bool ok) external onlyOwner {
        armed = ok;
        emit Armed(ok);
    }

    function setRouter(address r) external onlyOwner {
        if (r == address(0)) revert Bad();
        router = IOceanRouter(r);
        emit RouterSet(r);
    }

    function setColdBuffer(address b) external onlyOwner {
        if (b == address(0)) revert Bad();
        coldBuffer = IColdBufferOcean(b);
        emit ColdBufferSet(b);
    }

    function setGate(address g) external onlyOwner {
        gate = IZkGateOcean(g);
        emit GateSet(g);
    }

    function setMinEdgeBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps > 500) revert Bad();
        minEdgeBps = bps;
        emit EdgeBps(bps);
    }

    function setMaxRotate(uint256 amt) external onlyOwner {
        if (amt == 0) revert Bad();
        maxRotate = amt;
    }

    function seed(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Bad();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        totalSeeded += amt;
        emit Seeded(amt);
    }

    function _requireFire() internal view {
        if (!armed) revert NotArmed();
        if (address(gate) != address(0) && !gate.isProven(king)) revert NotProven();
        if (address(router) == address(0)) revert Bad();
    }

    /// @notice Keeper entry — rotate `usdcIn` through router; profit stays here until pushProfit.
    function rotate(uint256 usdcIn, bytes calldata routeData) external onlyOwner nonReentrant returns (uint256 profit) {
        _requireFire();
        if (usdcIn == 0 || usdcIn > maxRotate) revert Bad();
        uint256 bal = usdc.balanceOf(address(this));
        if (bal < usdcIn) revert Empty();

        uint256 minOut = usdcIn + (usdcIn * minEdgeBps) / 10_000;
        usdc.safeApprove(address(router), 0);
        usdc.safeApprove(address(router), usdcIn);
        uint256 out = router.rotate(usdcIn, minOut, routeData);
        if (out < minOut) revert NoEdge();

        profit = out - usdcIn;
        totalProfit += profit;
        rotations += 1;
        emit Rotated(usdcIn, out, profit);
    }

    /// @notice Push accumulated profit (balance − seeded working capital floor) to ColdBuffer.
    function pushProfit(uint256 amt) external onlyOwner nonReentrant {
        if (address(coldBuffer) == address(0)) revert Bad();
        uint256 bal = usdc.balanceOf(address(this));
        // Keep working capital: push only excess over seeded principal
        uint256 excess = bal > totalSeeded ? bal - totalSeeded : 0;
        if (amt == 0) amt = excess;
        if (amt == 0 || amt > excess) revert Empty();

        usdc.safeApprove(address(coldBuffer), 0);
        usdc.safeApprove(address(coldBuffer), amt);
        coldBuffer.receiveYield(amt, TAG_OCEAN);
        emit ProfitPushed(amt);
    }

    function liquid() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}
