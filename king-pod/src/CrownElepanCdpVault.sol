// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {CrownElepanUsd} from "./CrownElepanUsd.sol";

interface IElepanPrice {
    /// @notice Morpho-style price: Elepan (8dp) vs USDC (6dp) scale → 1e34 soft $1.
    function price() external view returns (uint256);
}

interface IZkElepanGate {
    function isProven(address subject) external view returns (bool);
    function requireProven(address subject) external view;
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

/// @notice King-only Maker-style CDP: lock Elepan, mint eUSD, stability fee, partial withdraw.
/// @dev CRITICAL: No full lock. Partial Elepan withdrawal always allowed if post-HF ≥ safety floor.
///      Full Elepan unlock when debt+fee repaid to zero. Self-sufficient with zero outside users.
///      ZK layer: all mutations require live Elepan wallet-bind `gate.isProven(msg.sender)`.
///      Morpho V2 rails remain separate; this module is the native-token vault CDP track.
contract CrownElepanCdpVault is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    uint256 public constant ORACLE_PRICE_SCALE = 1e36;
    uint256 public constant YEAR = 365 days;

    IERC20 public immutable elepan; // 8 decimals
    CrownElepanUsd public immutable eusd;
    IElepanPrice public immutable oracle;
    IZkElepanGate public immutable zkGate;
    /// @notice Receives minted stability-fee eUSD on accrue.
    address public immutable feeRecipient;
    /// @notice ACCESS CLAUSE: loan proceeds land here immediately (Landing / Kingdom treasury).
    address public immutable treasury;

    /// @notice Min collateralization ratio (e.g. 1.5e18 = 150%). Fixed at launch.
    uint256 public immutable liquidationRatio;
    /// @notice Partial-withdraw / mint safety floor (≥ liquidationRatio). Fixed at launch.
    uint256 public immutable safetyFloor;
    /// @notice Per-second stability fee in RAY (e.g. 5%/yr ≈ RAY * 5% / YEAR). Fixed at launch.
    uint256 public immutable stabilityFeePerSecond;

    uint256 public coll; // Elepan raw (8dp) locked for King
    uint256 public debt; // eUSD principal (18dp), excludes accrued fee
    uint256 public rateAccumulator = RAY; // grows with stability fee
    uint256 public lastAccrual;
    /// @notice Emergency path: King may mutate CDP via direct on-chain collateral locks if ZK fails.
    bool public zkFallbackEnabled;

    event Deposited(uint256 elepanAmt, uint256 collTotal);
    event Withdrawn(uint256 elepanAmt, uint256 collRemaining, uint256 hfWad);
    event Minted(uint256 eusdAmt, uint256 debtTotal, uint256 hfWad);
    event Repaid(uint256 eusdAmt, uint256 debtRemaining);
    event Accrued(uint256 rateAccumulator, uint256 feeMinted);
    event ZkFallbackSet(bool enabled);
    event ZkFallbackUsed(address indexed who, bytes4 indexed selector);

    error BadAmt();
    error UnsafeHf();
    error DebtOutstanding();
    error InsufficientColl();
    error NotZkProven();

    modifier onlyZkProven() {
        if (zkGate.isProven(msg.sender)) {
            _;
            return;
        }
        if (!zkFallbackEnabled) {
            zkGate.requireProven(msg.sender);
            revert NotZkProven();
        }
        emit ZkFallbackUsed(msg.sender, msg.sig);
        _;
    }

    function zkMintAllowed(address who) external view returns (bool) {
        return zkGate.isProven(who);
    }

    function setZkFallback(bool enabled) external onlyOwner {
        zkFallbackEnabled = enabled;
        emit ZkFallbackSet(enabled);
    }

    function mutationAllowed(address who) external view returns (bool) {
        if (zkGate.isProven(who)) return true;
        return zkFallbackEnabled && who == owner;
    }

    /// @param liquidationRatio_ WAD (min 1e18). Example 1.5e18 = 150%.
    /// @param safetyFloor_ WAD ≥ liquidationRatio_ (partial withdraw / mint gate). Example 1.55e18.
    /// @param stabilityFeeBpsYear_ bps per year (500 = 5%/yr). Converted to per-second RAY at deploy.
    constructor(
        address elepan_,
        address eusd_,
        address oracle_,
        address zkGate_,
        address king_,
        address feeRecipient_,
        address treasury_,
        uint256 liquidationRatio_,
        uint256 safetyFloor_,
        uint256 stabilityFeeBpsYear_
    ) Ownable(king_) {
        require(elepan_ != address(0) && eusd_ != address(0) && oracle_ != address(0), "ZERO");
        require(zkGate_ != address(0), "ZK");
        require(feeRecipient_ != address(0), "FEE_TO");
        require(treasury_ != address(0), "TREASURY");
        require(liquidationRatio_ >= WAD, "LR");
        require(safetyFloor_ >= liquidationRatio_, "FLOOR");
        elepan = IERC20(elepan_);
        eusd = CrownElepanUsd(eusd_);
        oracle = IElepanPrice(oracle_);
        zkGate = IZkElepanGate(zkGate_);
        feeRecipient = feeRecipient_;
        treasury = treasury_;
        liquidationRatio = liquidationRatio_;
        safetyFloor = safetyFloor_;
        // per-second ≈ (bps/10000) * RAY / YEAR  (linear approx; fine for CDP fee)
        stabilityFeePerSecond = (stabilityFeeBpsYear_ * RAY) / (10_000 * YEAR);
        lastAccrual = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function accruedDebt() public view returns (uint256) {
        uint256 rate = _previewRate();
        return _rmul(debt, rate);
    }

    function healthFactor() public view returns (uint256 hfWad) {
        return _hf(coll, accruedDebt());
    }

    /// @notice Simulate HF after withdrawing `elepanAmt` collateral (no state change).
    function previewWithdrawHf(uint256 elepanAmt) public view returns (uint256 hfWad) {
        if (elepanAmt > coll) return 0;
        return _hf(coll - elepanAmt, accruedDebt());
    }

    /// @notice Simulate HF after minting `eusdAmt` more stablecoin.
    function previewMintHf(uint256 eusdAmt) public view returns (uint256 hfWad) {
        return _hf(coll, accruedDebt() + eusdAmt);
    }

    function maxMintable() external view returns (uint256) {
        uint256 maxDebt = _maxDebt(coll, safetyFloor);
        uint256 d = accruedDebt();
        return d >= maxDebt ? 0 : maxDebt - d;
    }

    function maxWithdrawable() external view returns (uint256) {
        uint256 d = accruedDebt();
        if (d == 0) return coll;
        uint256 minColl = _minCollForDebt(d, safetyFloor);
        uint256 maxW = coll > minColl ? coll - minColl : 0;
        // Tighten for rounding so withdraw(maxW) never reverts UnsafeHf
        while (maxW > 0 && _hf(coll - maxW, d) < safetyFloor) maxW--;
        return maxW;
    }

    // -------------------------------------------------------------------------
    // Mutations (King only)
    // -------------------------------------------------------------------------

    function accrue() public {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return;
        if (stabilityFeePerSecond == 0 || debt == 0) {
            lastAccrual = block.timestamp;
            return;
        }
        // rateAccumulator *= (1 + feePerSecond)^dt ≈ 1 + feePerSecond*dt for small fees
        uint256 before = _rmul(debt, rateAccumulator);
        uint256 growth = stabilityFeePerSecond * dt;
        rateAccumulator = _rmul(rateAccumulator, RAY + growth);
        lastAccrual = block.timestamp;
        uint256 after_ = _rmul(debt, rateAccumulator);
        uint256 fee = after_ - before;
        // Mint fee eUSD so debt and token supply stay matched (King can repay+close).
        if (fee > 0) eusd.mint(feeRecipient, fee);
        emit Accrued(rateAccumulator, fee);
    }

    function deposit(uint256 elepanAmt) external onlyOwner onlyZkProven nonReentrant {
        if (elepanAmt == 0) revert BadAmt();
        accrue();
        elepan.safeTransferFrom(msg.sender, address(this), elepanAmt);
        coll += elepanAmt;
        emit Deposited(elepanAmt, coll);
    }

    /// @notice CRITICAL: partial withdraw anytime if remaining HF ≥ safetyFloor. No cooldown.
    function withdraw(uint256 elepanAmt) external onlyOwner onlyZkProven nonReentrant {
        if (elepanAmt == 0 || elepanAmt > coll) revert BadAmt();
        accrue();
        uint256 newColl = coll - elepanAmt;
        uint256 d = accruedDebt();
        if (d > 0) {
            uint256 hf = _hf(newColl, d);
            if (hf < safetyFloor) revert UnsafeHf();
            emit Withdrawn(elepanAmt, newColl, hf);
        } else {
            emit Withdrawn(elepanAmt, newColl, type(uint256).max);
        }
        coll = newColl;
        elepan.safeTransfer(msg.sender, elepanAmt);
    }

    /// @notice ACCESS CLAUSE: eUSD lands in `treasury` immediately — vault never escrows proceeds.
    function mint(uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        _mintTo(treasury, eusdAmt);
    }

    function mintTo(address to, uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        if (to == address(0)) revert BadAmt();
        _mintTo(to, eusdAmt);
    }

    /// @notice Repay eUSD (burns from treasury). Full repay → debt=0 → 100% Elepan withdrawable.
    function repay(uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        if (eusdAmt == 0) revert BadAmt();
        accrue();
        uint256 d = accruedDebt();
        if (eusdAmt > d) eusdAmt = d;
        eusd.burn(treasury, eusdAmt);
        uint256 remaining = d - eusdAmt;
        debt = remaining == 0 ? 0 : _rdiv(remaining, rateAccumulator);
        emit Repaid(eusdAmt, remaining);
    }

    /// @notice Convenience: repay all debt+fee then withdraw all collateral.
    function close() external onlyOwner onlyZkProven nonReentrant {
        _repayWithdrawCollateral();
    }

    /// @notice ACCESS CLAUSE: atomic full exit (repay + unlock collateral).
    function repayWithdrawCollateral() external onlyOwner onlyZkProven nonReentrant {
        _repayWithdrawCollateral();
    }

    function _mintTo(address to, uint256 eusdAmt) internal {
        if (eusdAmt == 0) revert BadAmt();
        accrue();
        uint256 newDebt = accruedDebt() + eusdAmt;
        uint256 hf = _hf(coll, newDebt);
        if (hf < safetyFloor) revert UnsafeHf();
        debt = _rdiv(newDebt, rateAccumulator);
        eusd.mint(to, eusdAmt);
        emit Minted(eusdAmt, newDebt, hf);
    }

    function _repayWithdrawCollateral() internal {
        accrue();
        uint256 d = accruedDebt();
        if (d > 0) {
            eusd.burn(treasury, d);
            debt = 0;
            emit Repaid(d, 0);
        }
        uint256 c = coll;
        if (c == 0) return;
        coll = 0;
        elepan.safeTransfer(msg.sender, c);
        emit Withdrawn(c, 0, type(uint256).max);
    }

    // -------------------------------------------------------------------------
    // Internal math
    // -------------------------------------------------------------------------

    function _previewRate() internal view returns (uint256) {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0 || stabilityFeePerSecond == 0) return rateAccumulator;
        return _rmul(rateAccumulator, RAY + stabilityFeePerSecond * dt);
    }

    function _collValueUsd18(uint256 elepanAmt) internal view returns (uint256) {
        // Morpho price 1e34: value_USDC_6dp = elepan_8dp * price / 1e36
        // → USD 18dp = value_6dp * 1e12 = elepan * price * 1e12 / 1e36 = elepan * price / 1e24
        uint256 px = oracle.price();
        return (elepanAmt * px) / 1e24;
    }

    function _hf(uint256 elepanAmt, uint256 debtUsd18) internal view returns (uint256) {
        if (debtUsd18 == 0) return type(uint256).max;
        uint256 value = _collValueUsd18(elepanAmt);
        return (value * WAD) / debtUsd18;
    }

    function _maxDebt(uint256 elepanAmt, uint256 floorWad) internal view returns (uint256) {
        uint256 value = _collValueUsd18(elepanAmt);
        return (value * WAD) / floorWad;
    }

    function _minCollForDebt(uint256 debtUsd18, uint256 floorWad) internal view returns (uint256) {
        // debt = coll * price / 1e24 * WAD / floor → coll = debt * floor * 1e24 / (price * WAD)
        uint256 px = oracle.price();
        return (debtUsd18 * floorWad * 1e24) / (px * WAD);
    }

    function _rmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / RAY;
    }

    function _rdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * RAY) / y;
    }
}
