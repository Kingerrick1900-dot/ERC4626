// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";

/// @title SelfRepayingTreasury
/// @notice Fee/tax sink: auto-repays prime credit debt, then holds surplus for King.
/// @dev Protocol fees (7683 fill, PSM, ops tax) land here → repay → free collateral capacity.
contract SelfRepayingTreasury is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    CrownPrimeCredit public credit;
    address public immutable king;

    uint256 public totalSwept;
    uint256 public totalRepaid;
    bool public autoRepay = true;
    /// @notice Once true, `setCredit` is frozen (Phase-1 hard lock — no silent rewire).
    bool public creditFrozen;
    /// @notice When true, `sweep` / `pokeRepay` no-op on inbound (owner pause).
    bool public paused;

    event CreditSet(address credit);
    event CreditFrozen();
    event AutoRepaySet(bool on);
    event Paused(bool on);
    event Swept(address indexed from, uint256 amt);
    event Repaid(uint256 amt);
    event SurplusPulled(address indexed to, uint256 amt);

    error BadAmt();
    error CreditLocked();
    error PausedErr();

    constructor(address usdc_, address king_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && king_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        king = king_;
    }

    function setCredit(address credit_) external onlyOwner {
        if (creditFrozen) revert CreditLocked();
        credit = CrownPrimeCredit(credit_);
        emit CreditSet(credit_);
    }

    /// @notice Irreversible: credit pointer can no longer be swapped.
    function freezeCredit() external onlyOwner {
        creditFrozen = true;
        emit CreditFrozen();
    }

    function setAutoRepay(bool on) external onlyOwner {
        autoRepay = on;
        emit AutoRepaySet(on);
    }

    function setPaused(bool on) external onlyOwner {
        paused = on;
        emit Paused(on);
    }

    /// @notice Anyone may push USDC fees here; optionally auto-repays king debt.
    function sweep(uint256 amt) external nonReentrant {
        if (paused) revert PausedErr();
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        totalSwept += amt;
        emit Swept(msg.sender, amt);
        if (autoRepay) _repayAvailable();
    }

    /// @notice Native receive path when fee contracts transfer without sweep().
    function pokeRepay() external nonReentrant {
        if (paused) revert PausedErr();
        _repayAvailable();
    }

    function _repayAvailable() internal {
        if (address(credit) == address(0)) return;
        uint256 debt = credit.debtOf(king);
        if (debt == 0) return;
        uint256 bal = usdc.balanceOf(address(this));
        if (bal == 0) return;
        uint256 pay = bal < debt ? bal : debt;
        usdc.safeApprove(address(credit), 0);
        usdc.safeApprove(address(credit), pay);
        credit.repay(pay);
        totalRepaid += pay;
        emit Repaid(pay);
    }

    function surplus() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice Surplus only to King (hard lock — no arbitrary sink).
    function pullSurplus(uint256 amt, address to) external onlyOwner nonReentrant {
        to = king; // ignore caller-chosen sink
        if (amt == 0 || amt > usdc.balanceOf(address(this))) revert BadAmt();
        usdc.safeTransfer(to, amt);
        emit SurplusPulled(to, amt);
    }
}
