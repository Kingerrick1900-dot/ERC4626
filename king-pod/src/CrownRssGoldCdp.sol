// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IOracleRssG {
    function price() external view returns (uint256);
}

interface IEusdRssG {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
}

/// @notice Elepan CrownGoldCdp fork for RSS gold — lock kRSSG, mint eUSD to Landing.
/// @dev King-only. Cold-or-revert mint to Landing. No Morpho inside.
contract CrownRssGoldCdp is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant SAFETY = 1550000000000000000; // 155%

    IERC20 public immutable gold; // kRSSG 8dp
    IEusdRssG public immutable eusd;
    IOracleRssG public immutable oracle;
    address public immutable king;
    address public immutable landing;

    uint256 public coll;
    uint256 public debt;

    event Deposited(uint256 amt, uint256 collTotal);
    event Withdrawn(uint256 amt, uint256 collLeft);
    event Minted(uint256 amt, uint256 debtTotal, uint256 hf);
    event Repaid(uint256 amt, uint256 debtLeft);

    error BadAmt();
    error Unsafe();
    error ColdMiss();

    constructor(
        address gold_,
        address eusd_,
        address oracle_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        require(gold_ != address(0) && eusd_ != address(0) && oracle_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ADDR");
        gold = IERC20(gold_);
        eusd = IEusdRssG(eusd_);
        oracle = IOracleRssG(oracle_);
        king = king_;
        landing = landing_;
    }

    function healthFactor() public view returns (uint256) {
        return _hf(coll, debt);
    }

    function maxMintable() public view returns (uint256) {
        uint256 maxDebt = _maxDebt(coll);
        return debt >= maxDebt ? 0 : maxDebt - debt;
    }

    function deposit(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        gold.safeTransferFrom(msg.sender, address(this), amt);
        coll += amt;
        emit Deposited(amt, coll);
    }

    function withdraw(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0 || amt > coll) revert BadAmt();
        uint256 newColl = coll - amt;
        if (debt > 0 && _hf(newColl, debt) < SAFETY) revert Unsafe();
        coll = newColl;
        gold.safeTransfer(msg.sender, amt);
        emit Withdrawn(amt, coll);
    }

    /// @notice Mint eUSD to Landing against kRSSG @ oracle. Cold-or-revert.
    function mintToLanding(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        uint256 newDebt = debt + amt;
        if (_hf(coll, newDebt) < SAFETY) revert Unsafe();
        debt = newDebt;
        uint256 before = IERC20(address(eusd)).balanceOf(landing);
        eusd.mint(landing, amt);
        if (IERC20(address(eusd)).balanceOf(landing) < before + amt) revert ColdMiss();
        emit Minted(amt, debt, _hf(coll, debt));
    }

    function repay(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0 || amt > debt) revert BadAmt();
        eusd.burn(msg.sender, amt);
        unchecked {
            debt -= amt;
        }
        emit Repaid(amt, debt);
    }

    /// @dev kRSSG 8dp, eUSD 18dp. Oracle: Morpho-style loan units per coll-wei (eUSD/USDC-like 1e24 @ $1).
    function _maxDebt(uint256 collAmt) internal view returns (uint256) {
        if (collAmt == 0) return 0;
        uint256 px = oracle.price();
        // coll(8dp) * price / 1e36 * 1e18 / SAFETY → eUSD 18dp
        // For $1 oracle 1e24 (USDC 6dp style): adapt — kingdom gold CDP used 1e35 for 8dp/$10.
        // Use: valueWad = coll * px / 1e26  (8dp + 1e24 price → ~18dp at $1), then / SAFETY
        uint256 value = (collAmt * px) / 1e26;
        return (value * WAD) / SAFETY;
    }

    function _hf(uint256 collAmt, uint256 debtAmt) internal view returns (uint256) {
        if (debtAmt == 0) return type(uint256).max;
        uint256 maxD = _maxDebt(collAmt);
        if (maxD == 0) return 0;
        // hf = (collValue / debt) scaled; use maxDebt*SAFETY/debt ≈ collValue/debt
        return (maxD * SAFETY) / debtAmt;
    }
}
