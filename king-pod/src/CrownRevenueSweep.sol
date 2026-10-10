// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IColdBufferFund {
    function fund(uint256 amount) external;
    function usdc() external view returns (IERC20);
}

/// @title CrownRevenueSweep — Route A
/// @notice Pull USDC from allowlisted fee sources; 30% → ColdBuffer, 70% → HOT.
/// @dev Maker/Aave-style protocol-owned revenue. No flash. No borrow.
contract CrownRevenueSweep is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IColdBufferFund public immutable cold;
    address public immutable hot;

    uint256 public coldBps = 3000; // 30% — sealed ColdBuffer law
    address public operator;
    mapping(address => bool) public feeSource;

    uint256 public totalSwept;
    uint256 public totalCold;
    uint256 public totalHot;

    event FeeSourceSet(address indexed source, bool on);
    event OperatorSet(address indexed op);
    event ColdBpsSet(uint256 bps);
    event Swept(address indexed source, uint256 amount, uint256 toCold, uint256 toHot);

    error BadSource();
    error BadAmt();
    error BadBps();
    error NotOp();

    modifier onlyOp() {
        if (msg.sender != operator && msg.sender != owner) revert NotOp();
        _;
    }

    constructor(address usdc_, address cold_, address hot_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && cold_ != address(0) && hot_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        cold = IColdBufferFund(cold_);
        hot = hot_;
        operator = owner_;
        require(address(IColdBufferFund(cold_).usdc()) == usdc_, "USDC_MISMATCH");
    }

    function setFeeSource(address source, bool on) external onlyOwner {
        if (source == address(0)) revert BadSource();
        feeSource[source] = on;
        emit FeeSourceSet(source, on);
    }

    function setOperator(address op) external onlyOwner {
        if (op == address(0)) revert BadSource();
        operator = op;
        emit OperatorSet(op);
    }

    function setColdBps(uint256 bps) external onlyOwner {
        if (bps > 10_000) revert BadBps();
        // Sealed floor: never below 30% without explicit King raise of kill switch off-chain.
        require(bps >= 3000, "COLD_FLOOR");
        coldBps = bps;
        emit ColdBpsSet(bps);
    }

    /// @notice Pull `amount` USDC from allowlisted `source` (0 = full balance).
    function sweep(address source, uint256 amount) external onlyOp nonReentrant returns (uint256 swept) {
        if (!feeSource[source]) revert BadSource();
        uint256 bal = usdc.balanceOf(source);
        if (amount == 0) amount = bal;
        if (amount == 0 || amount > bal) revert BadAmt();

        usdc.safeTransferFrom(source, address(this), amount);

        uint256 toCold = (amount * coldBps) / 10_000;
        uint256 toHot = amount - toCold;

        if (toCold > 0) {
            usdc.safeApprove(address(cold), 0);
            usdc.safeApprove(address(cold), toCold);
            cold.fund(toCold);
        }
        if (toHot > 0) {
            usdc.safeTransfer(hot, toHot);
        }

        totalSwept += amount;
        totalCold += toCold;
        totalHot += toHot;
        emit Swept(source, amount, toCold, toHot);
        return amount;
    }

    /// @notice Sweep many sources in one tx (amount 0 each = full).
    function sweepMany(address[] calldata sources, uint256[] calldata amounts)
        external
        onlyOp
        nonReentrant
        returns (uint256 total)
    {
        require(sources.length == amounts.length, "LEN");
        for (uint256 i; i < sources.length; i++) {
            address source = sources[i];
            if (!feeSource[source]) revert BadSource();
            uint256 amount = amounts[i];
            uint256 bal = usdc.balanceOf(source);
            if (amount == 0) amount = bal;
            if (amount == 0) continue;
            if (amount > bal) revert BadAmt();

            usdc.safeTransferFrom(source, address(this), amount);
            uint256 toCold = (amount * coldBps) / 10_000;
            uint256 toHotAmt = amount - toCold;
            if (toCold > 0) {
                usdc.safeApprove(address(cold), 0);
                usdc.safeApprove(address(cold), toCold);
                cold.fund(toCold);
            }
            if (toHotAmt > 0) usdc.safeTransfer(hot, toHotAmt);
            totalSwept += amount;
            totalCold += toCold;
            totalHot += toHotAmt;
            total += amount;
            emit Swept(source, amount, toCold, toHotAmt);
        }
    }

    function book() external view returns (uint256 swept, uint256 coldAmt, uint256 hotAmt, uint256 bps) {
        return (totalSwept, totalCold, totalHot, coldBps);
    }
}
