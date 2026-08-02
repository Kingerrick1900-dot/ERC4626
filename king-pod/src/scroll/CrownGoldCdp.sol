// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../core/Core.sol";

interface IOracleG {
    function price() external view returns (uint256);
}

interface IEusdG {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
}

/// @notice Scroll Elepan-native gold CDP — lock kXAU, mint eUSD under kingdom oracle.
/// @dev No Morpho. Elepan rules. King-only. Mint proceeds → Landing (cold-or-revert).
contract CrownGoldCdp is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant SAFETY = 1550000000000000000; // 155%

    IERC20 public immutable gold; // kXAU 8dp
    IEusdG public immutable eusd;
    IOracleG public immutable oracle;
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

    constructor(address gold_, address eusd_, address oracle_, address king_, address landing_, address owner_)
        Ownable(owner_)
    {
        require(gold_ != address(0) && eusd_ != address(0) && oracle_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ADDR");
        gold = IERC20(gold_);
        eusd = IEusdG(eusd_);
        oracle = IOracleG(oracle_);
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

    /// @notice Mint eUSD to Landing against kXAU @ oracle. Cold-or-revert.
    function mintToLanding(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        uint256 newDebt = debt + amt;
        uint256 hf = _hf(coll, newDebt);
        if (hf < SAFETY) revert Unsafe();
        debt = newDebt;
        uint256 before = _bal(landing);
        eusd.mint(landing, amt);
        if (_bal(landing) < before + amt) revert ColdMiss();
        emit Minted(amt, debt, hf);
    }

    function repay(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        if (amt > debt) amt = debt;
        eusd.burn(msg.sender, amt);
        debt -= amt;
        emit Repaid(amt, debt);
    }

    function _bal(address a) internal view returns (uint256) {
        return IERC20(address(eusd)).balanceOf(a);
    }

    function _collValue18(uint256 goldAmt) internal view returns (uint256) {
        // Morpho-style: value_USDC_6dp = gold_8dp * price / 1e36 → USD18 = * 1e12
        return (goldAmt * oracle.price()) / 1e24;
    }

    function _hf(uint256 goldAmt, uint256 debt18) internal view returns (uint256) {
        if (debt18 == 0) return type(uint256).max;
        return (_collValue18(goldAmt) * WAD) / debt18;
    }

    function _maxDebt(uint256 goldAmt) internal view returns (uint256) {
        return (_collValue18(goldAmt) * WAD) / SAFETY;
    }
}
