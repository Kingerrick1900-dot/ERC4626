// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingPair} from "./KingPair.sol";
import {KingOracle} from "./KingOracle.sol";

/// @notice Isolated money market: supply USDC via sUSDC; borrow USDC against KingPair LP.
contract KingMoneyMarket is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    KingSusdc public immutable sUsdc;
    KingPair public immutable pair;
    KingOracle public oracle;
    address public operator; // primary (legacy)
    mapping(address => bool) public isOperator;

    uint256 public lltvBps = 7000; // 70%
    uint256 public constant BPS = 10_000;

    mapping(address => uint256) public collateralLp;
    mapping(address => uint256) public debtUsdc;

    uint256 public totalDebtUsdc;
    bool public paused;

    error NotOperator();
    modifier onlyOperator() {
        if (msg.sender != operator && !isOperator[msg.sender]) revert NotOperator();
        _;
    }

    event CollateralPosted(address indexed user, uint256 lpAmount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event CollateralPulled(address indexed user, uint256 lpAmount);

    error Paused();
    error Unhealthy();

    constructor(address usdc_, address sUsdc_, address pair_, address oracle_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        sUsdc = KingSusdc(sUsdc_);
        pair = KingPair(pair_);
        oracle = KingOracle(oracle_);
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
    }

    function setLltvBps(uint256 bps) external onlyOwner {
        require(bps > 0 && bps <= 9000, "LLTV");
        lltvBps = bps;
    }

    function setOracle(address o) external onlyOwner {
        oracle = KingOracle(o);
    }

    function setOperator(address op) external onlyOwner {
        operator = op;
        isOperator[op] = true;
    }

    function setOperatorAuth(address op, bool allowed) external onlyOwner {
        isOperator[op] = allowed;
        if (allowed && operator == address(0)) operator = op;
    }

    function maxBorrow(address user) public view returns (uint256) {
        uint256 collUsd = oracle.lpValueUsd(collateralLp[user]); // 1e18
        uint256 maxUsd = (collUsd * lltvBps) / BPS;
        // USDC 6 decimals
        uint256 maxUsdc = maxUsd / 1e12;
        uint256 debt = debtUsdc[user];
        if (maxUsdc <= debt) return 0;
        return maxUsdc - debt;
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 debt = debtUsdc[user];
        if (debt == 0) return type(uint256).max;
        uint256 collUsd = oracle.lpValueUsd(collateralLp[user]);
        uint256 maxUsd = (collUsd * lltvBps) / BPS;
        uint256 debtUsd = debt * 1e12;
        return (maxUsd * 1e18) / debtUsd;
    }

    function postCollateral(uint256 lpAmount) external nonReentrant whenNotPaused {
        require(lpAmount > 0, "ZERO");
        require(pair.transferFrom(msg.sender, address(this), lpAmount) || _pairPush(msg.sender, lpAmount), "LP");
        // KingPair has transfer but not transferFrom — handle via approve pattern fallback
        collateralLp[msg.sender] += lpAmount;
        emit CollateralPosted(msg.sender, lpAmount);
    }

    /// @dev Pod transfers LP to market then credits the King position.
    function creditCollateral(address user, uint256 lpAmount) external onlyOperator {
        collateralLp[user] += lpAmount;
        emit CollateralPosted(user, lpAmount);
    }

    function _pairPush(address from, uint256 amt) private returns (bool) {
        from;
        amt;
        return false;
    }

    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        _borrow(msg.sender, amount, msg.sender);
    }

    function borrowTo(address user, uint256 amount, address receiver) external onlyOperator nonReentrant whenNotPaused {
        _borrow(user, amount, receiver);
    }

    function _borrow(address user, uint256 amount, address receiver) private {
        require(amount > 0, "ZERO");
        debtUsdc[user] += amount;
        totalDebtUsdc += amount;
        if (healthFactor(user) < 1e18) revert Unhealthy();
        sUsdc.pullAssets(receiver, amount);
        emit Borrowed(user, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        _repay(msg.sender, amount);
    }

    function repayFor(address user, uint256 amount) external onlyOwner nonReentrant {
        _repay(user, amount);
    }

    function _repay(address user, uint256 amount) private {
        uint256 debt = debtUsdc[user];
        if (amount > debt) amount = debt;
        usdc.safeTransferFrom(msg.sender, address(sUsdc), amount);
        debtUsdc[user] = debt - amount;
        totalDebtUsdc -= amount;
        emit Repaid(user, amount);
    }
}
