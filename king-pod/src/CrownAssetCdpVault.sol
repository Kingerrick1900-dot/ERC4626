// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {CrownElepanUsd} from "./CrownElepanUsd.sol";

interface IMorphoPrice {
    /// @notice Morpho-style: (coll * price) / 1e36 = USDC raw (6dp).
    function price() external view returns (uint256);
}

interface IZkGate {
    function isProven(address subject) external view returns (bool);
    function requireProven(address subject) external view;
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

/// @notice King-only Maker-style CDP base: lock ERC20 coll, mint eUSD, fee, partial withdraw.
/// @dev Isolated per deployment. ZK-gated. No full lock — partial withdraw if HF ≥ safety floor.
abstract contract CrownAssetCdpVault is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    uint256 public constant YEAR = 365 days;

    IERC20 public immutable collateral;
    CrownElepanUsd public immutable eusd;
    IMorphoPrice public immutable oracle;
    IZkGate public immutable zkGate;
    /// @notice Stability-fee eUSD recipient (Kingdom Landing / treasury).
    address public immutable feeRecipient;
    /// @notice Receives minted loan proceeds immediately (Access Clause — no escrow).
    address public immutable treasury;

    uint256 public immutable liquidationRatio;
    uint256 public immutable safetyFloor;
    uint256 public immutable stabilityFeePerSecond;

    uint256 public coll;
    uint256 public debt;
    uint256 public rateAccumulator = RAY;
    uint256 public lastAccrual;
    /// @notice Emergency path: King may mutate CDP via direct on-chain collateral locks if ZK fails.
    /// @dev Does NOT weaken collateral/HF checks — only bypasses wallet-bind attestation.
    bool public zkFallbackEnabled;

    event Deposited(uint256 collAmt, uint256 collTotal);
    event Withdrawn(uint256 collAmt, uint256 collRemaining, uint256 hfWad);
    event Minted(uint256 eusdAmt, uint256 debtTotal, uint256 hfWad);
    event Repaid(uint256 eusdAmt, uint256 debtRemaining);
    event Accrued(uint256 rateAccumulator, uint256 feeMinted);
    event ZkFallbackSet(bool enabled);
    event ZkFallbackUsed(address indexed who, bytes4 indexed selector);
    event SelfLiquidated(uint256 debtRepaid, uint256 collReturned, uint256 hfWad);

    error BadAmt();
    error UnsafeHf();
    error NotZkProven();
    /// @notice Mint proceeds must credit immutable cold treasury (Landing) or full tx reverts.
    error ColdMiss();
    error NotLiquidatable();

    modifier onlyZkProven() {
        // Prefer live wallet-bind; if expired/compromised and fallback armed → direct coll lock path.
        if (zkGate.isProven(msg.sender)) {
            _;
            return;
        }
        if (!zkFallbackEnabled) {
            // Surface gate's Expired when available (TTL-aware), else NotZkProven.
            zkGate.requireProven(msg.sender);
            revert NotZkProven();
        }
        emit ZkFallbackUsed(msg.sender, msg.sig);
        _;
    }

    /// @notice True iff `who` holds a non-expired ZK wallet-bind attestation.
    function zkMintAllowed(address who) external view returns (bool) {
        return zkGate.isProven(who);
    }

    /// @notice Arm/disarm direct-collateral fallback when ZK attestation path is unavailable.
    function setZkFallback(bool enabled) external onlyOwner {
        zkFallbackEnabled = enabled;
        emit ZkFallbackSet(enabled);
    }

    /// @notice True if ZK proven OR (fallback armed and caller is King) — view for monitors.
    function mutationAllowed(address who) external view returns (bool) {
        if (zkGate.isProven(who)) return true;
        return zkFallbackEnabled && who == owner;
    }

    constructor(
        address collateral_,
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
        require(collateral_ != address(0) && eusd_ != address(0) && oracle_ != address(0), "ZERO");
        require(zkGate_ != address(0), "ZK");
        require(feeRecipient_ != address(0), "FEE_TO");
        require(treasury_ != address(0), "TREASURY");
        require(liquidationRatio_ >= WAD, "LR");
        require(safetyFloor_ >= liquidationRatio_, "FLOOR");
        collateral = IERC20(collateral_);
        eusd = CrownElepanUsd(eusd_);
        oracle = IMorphoPrice(oracle_);
        zkGate = IZkGate(zkGate_);
        feeRecipient = feeRecipient_;
        treasury = treasury_;
        liquidationRatio = liquidationRatio_;
        safetyFloor = safetyFloor_;
        stabilityFeePerSecond = (stabilityFeeBpsYear_ * RAY) / (10_000 * YEAR);
        lastAccrual = block.timestamp;
    }

    function accruedDebt() public view returns (uint256) {
        return _rmul(debt, _previewRate());
    }

    function healthFactor() public view returns (uint256) {
        return _hf(coll, accruedDebt());
    }

    function previewWithdrawHf(uint256 collAmt) public view returns (uint256) {
        if (collAmt > coll) return 0;
        return _hf(coll - collAmt, accruedDebt());
    }

    function previewMintHf(uint256 eusdAmt) public view returns (uint256) {
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
        while (maxW > 0 && _hf(coll - maxW, d) < safetyFloor) maxW--;
        return maxW;
    }

    function accrue() public {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return;
        if (stabilityFeePerSecond == 0 || debt == 0) {
            lastAccrual = block.timestamp;
            return;
        }
        uint256 before = _rmul(debt, rateAccumulator);
        rateAccumulator = _rmul(rateAccumulator, RAY + stabilityFeePerSecond * dt);
        lastAccrual = block.timestamp;
        uint256 fee = _rmul(debt, rateAccumulator) - before;
        if (fee > 0) eusd.mint(feeRecipient, fee);
        emit Accrued(rateAccumulator, fee);
    }

    function deposit(uint256 collAmt) external onlyOwner onlyZkProven nonReentrant {
        if (collAmt == 0) revert BadAmt();
        accrue();
        collateral.safeTransferFrom(msg.sender, address(this), collAmt);
        coll += collAmt;
        emit Deposited(collAmt, coll);
    }

    function withdraw(uint256 collAmt) external onlyOwner onlyZkProven nonReentrant {
        if (collAmt == 0 || collAmt > coll) revert BadAmt();
        accrue();
        uint256 newColl = coll - collAmt;
        uint256 d = accruedDebt();
        if (d > 0) {
            uint256 hf = _hf(newColl, d);
            if (hf < safetyFloor) revert UnsafeHf();
            emit Withdrawn(collAmt, newColl, hf);
        } else {
            emit Withdrawn(collAmt, newColl, type(uint256).max);
        }
        coll = newColl;
        collateral.safeTransfer(msg.sender, collAmt);
    }

    /// @notice ACCESS CLAUSE: mint eUSD straight to cold `treasury` — no escrow.
    /// @dev If cold wallet does not receive the full mint, entire tx reverts (debt does not open).
    function mint(uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        _mintToCold(eusdAmt);
    }

    /// @notice Same as `mint` — `to` MUST be cold treasury or reverts `ColdMiss`.
    function mintTo(address to, uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        if (to != treasury) revert ColdMiss();
        _mintToCold(eusdAmt);
    }

    function repay(uint256 eusdAmt) external onlyOwner onlyZkProven nonReentrant {
        if (eusdAmt == 0) revert BadAmt();
        accrue();
        uint256 d = accruedDebt();
        if (eusdAmt > d) eusdAmt = d;
        // Burn from treasury (holds principal + any fee mint routed there).
        eusd.burn(treasury, eusdAmt);
        uint256 remaining = d - eusdAmt;
        debt = remaining == 0 ? 0 : _rdiv(remaining, rateAccumulator);
        emit Repaid(eusdAmt, remaining);
    }

    /// @notice Atomic full exit: repay all debt+fee from treasury, unlock all collateral to King.
    function close() external onlyOwner onlyZkProven nonReentrant {
        _repayWithdrawCollateral();
    }

    /// @notice Alias for Maker/Morpho-style atomic exit (Access Clause full exit).
    function repayWithdrawCollateral() external onlyOwner onlyZkProven nonReentrant {
        _repayWithdrawCollateral();
    }

    /// @notice True when HF &lt; liquidation ratio — King may `selfLiquidate`.
    function liquidatable() public view returns (bool) {
        uint256 d = accruedDebt();
        if (d == 0) return false;
        return _hf(coll, d) < liquidationRatio;
    }

    /// @notice King self-liquidation when underwater vs LR: burn debt from cold treasury, free all coll.
    function selfLiquidate() external onlyOwner onlyZkProven nonReentrant {
        accrue();
        uint256 d = accruedDebt();
        if (d == 0) revert BadAmt();
        uint256 hf = _hf(coll, d);
        if (hf >= liquidationRatio) revert NotLiquidatable();
        eusd.burn(treasury, d);
        debt = 0;
        emit Repaid(d, 0);
        uint256 c = coll;
        coll = 0;
        if (c > 0) {
            collateral.safeTransfer(msg.sender, c);
            emit Withdrawn(c, 0, type(uint256).max);
        }
        emit SelfLiquidated(d, c, hf);
    }

    function _mintToCold(uint256 eusdAmt) internal {
        if (eusdAmt == 0) revert BadAmt();
        address cold = treasury;
        if (cold == address(0) || cold == address(this)) revert ColdMiss();
        accrue();
        uint256 newDebt = accruedDebt() + eusdAmt;
        uint256 hf = _hf(coll, newDebt);
        if (hf < safetyFloor) revert UnsafeHf();
        uint256 before = eusd.balanceOf(cold);
        debt = _rdiv(newDebt, rateAccumulator);
        eusd.mint(cold, eusdAmt);
        if (eusd.balanceOf(cold) < before + eusdAmt) revert ColdMiss();
        if (eusd.balanceOf(address(this)) != 0) revert ColdMiss();
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
        collateral.safeTransfer(msg.sender, c);
        emit Withdrawn(c, 0, type(uint256).max);
    }

    function _previewRate() internal view returns (uint256) {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0 || stabilityFeePerSecond == 0) return rateAccumulator;
        return _rmul(rateAccumulator, RAY + stabilityFeePerSecond * dt);
    }

    function _collValueUsd18(uint256 collAmt) internal view returns (uint256) {
        // (coll * morphoPrice) / 1e36 = USDC 6dp → * 1e12 = USD 18dp
        return (collAmt * oracle.price()) / 1e24;
    }

    function _hf(uint256 collAmt, uint256 debtUsd18) internal view returns (uint256) {
        if (debtUsd18 == 0) return type(uint256).max;
        return (_collValueUsd18(collAmt) * WAD) / debtUsd18;
    }

    function _maxDebt(uint256 collAmt, uint256 floorWad) internal view returns (uint256) {
        return (_collValueUsd18(collAmt) * WAD) / floorWad;
    }

    function _minCollForDebt(uint256 debtUsd18, uint256 floorWad) internal view returns (uint256) {
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
