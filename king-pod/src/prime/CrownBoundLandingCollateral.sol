// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

/// @title CrownBoundLandingCollateral
/// @notice Prime-brokerage float lock: eUSD/gUSD deposited as non-liquidatable collateral.
/// @dev No public liquidation path. Capacity = collUsd6 × LLTV − reservedDebtUsd6.
///      Ownership retained — King unlocks only when debt room allows. Does NOT create USDC.
contract CrownBoundLandingCollateral is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;

    IERC20 public immutable eusd;
    IERC20 public immutable gusd; // optional; address(0) = eUSD-only
    address public immutable king;

    /// @notice Conservative LLTV on locked float (e.g. 30e16 = 30%).
    uint256 public lltv = 30e16;
    /// @notice USD value per 1e18 float token, 8dp (default $1.00 = 1e8).
    uint256 public floatUsd8 = 1e8;

    uint256 public eusdLocked;
    uint256 public gusdLocked;
    /// @notice Debt reserved against this vault (USDC 6dp), set by credit/router.
    uint256 public reservedDebtUsd6;

    mapping(address => bool) public debtOperator; // credit / router may adjust reservedDebt

    event Locked(address indexed token, uint256 amt, uint256 collUsd6);
    event Unlocked(address indexed token, uint256 amt, address to);
    event LltvSet(uint256 lltv);
    event FloatUsd8Set(uint256 px);
    event DebtOperatorSet(address indexed op, bool on);
    event ReservedDebtSet(uint256 debtUsd6);

    error BadAmt();
    error KingOnly();
    error Unsafe();
    error NoLiq();
    error NotOp();

    constructor(address eusd_, address gusd_, address king_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && king_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        gusd = IERC20(gusd_);
        king = king_;
    }

    function setLltv(uint256 lltv_) external onlyOwner {
        if (lltv_ == 0 || lltv_ > WAD) revert BadAmt();
        lltv = lltv_;
        emit LltvSet(lltv_);
    }

    function setFloatUsd8(uint256 px) external onlyOwner {
        if (px == 0) revert BadAmt();
        floatUsd8 = px;
        emit FloatUsd8Set(px);
    }

    function setDebtOperator(address op, bool on) external onlyOwner {
        debtOperator[op] = on;
        emit DebtOperatorSet(op, on);
    }

    /// @notice Explicit: this vault has no liquidation function. Always true.
    function nonLiquidatable() external pure returns (bool) {
        return true;
    }

    /// @dev Reverts if anyone attempts a liquidate selector — belt and suspenders.
    function liquidate(address, uint256) external pure {
        revert NoLiq();
    }

    function lockEusd(uint256 amt) external nonReentrant returns (uint256 collUsd6) {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (amt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        eusdLocked += amt;
        collUsd6 = collUsd6View();
        emit Locked(address(eusd), amt, collUsd6);
    }

    function lockGusd(uint256 amt) external nonReentrant returns (uint256 collUsd6) {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (address(gusd) == address(0) || amt == 0) revert BadAmt();
        gusd.safeTransferFrom(msg.sender, address(this), amt);
        gusdLocked += amt;
        collUsd6 = collUsd6View();
        emit Locked(address(gusd), amt, collUsd6);
    }

    /// @notice Unlock float only when remaining capacity covers reserved debt.
    function unlockEusd(uint256 amt, address to) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (amt == 0 || amt > eusdLocked) revert BadAmt();
        if (to == address(0)) to = king;
        eusdLocked -= amt;
        // Post-unlock: coll × LLTV must still cover reserved debt
        if ((collUsd6View() * lltv) / WAD < reservedDebtUsd6) {
            eusdLocked += amt;
            revert Unsafe();
        }
        eusd.safeTransfer(to, amt);
        emit Unlocked(address(eusd), amt, to);
    }

    function unlockGusd(uint256 amt, address to) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (address(gusd) == address(0) || amt == 0 || amt > gusdLocked) revert BadAmt();
        if (to == address(0)) to = king;
        gusdLocked -= amt;
        if ((collUsd6View() * lltv) / WAD < reservedDebtUsd6) {
            gusdLocked += amt;
            revert Unsafe();
        }
        gusd.safeTransfer(to, amt);
        emit Unlocked(address(gusd), amt, to);
    }

    /// @notice Credit/router posts outstanding USDC debt against this vault.
    function setReservedDebtUsd6(uint256 debtUsd6) external {
        if (!debtOperator[msg.sender]) revert NotOp();
        if ((collUsd6View() * lltv) / WAD < debtUsd6) revert Unsafe();
        reservedDebtUsd6 = debtUsd6;
        emit ReservedDebtSet(debtUsd6);
    }

    function collUsd6View() public view returns (uint256) {
        uint256 float18 = eusdLocked + gusdLocked;
        // float18 * floatUsd8 / 1e8 / 1e12 = usd6  (18dp → 6dp with $1 @ 8dp)
        return (float18 * floatUsd8) / 1e20;
    }

    function maxDebtUsd6() public view returns (uint256) {
        return (collUsd6View() * lltv) / WAD;
    }

    function borrowCapacityUsd6() public view returns (uint256) {
        uint256 cap = maxDebtUsd6();
        if (reservedDebtUsd6 >= cap) return 0;
        return cap - reservedDebtUsd6;
    }
}
