// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoAmo {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IBoundGateAmo {
    function isProven(address) external view returns (bool);
    function minThreshold() external view returns (uint256);
    function attestations(address) external view returns (uint256, uint256, bool);
}

/// @title CrownSovereignAmo
/// @notice Frax-style AMO: minted eUSD supply-only → unmatched idle; borrow eUSD vs RSS/$1200 oracle.
/// @dev Supply and borrow are separate txs. No USDC loop. Pack gate optional via `requireGate`.
contract CrownSovereignAmo is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoAmo public immutable morpho;
    IERC20 public immutable eusd;
    IERC20 public immutable rss;
    IBoundGateAmo public immutable gate;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoAmo.MarketParams public mp;

    bool public requireGate;
    uint256 public lastSupply;
    uint256 public lastColl;
    uint256 public lastBorrow;

    event AmoSupplied(uint256 eusdAmt, uint256 idleAfter);
    event CollPosted(uint256 rssAmt);
    event EusdBorrowed(uint256 amt, address receiver, uint256 idleAfter);
    event GateToggled(bool on);

    error OnlyKing();
    error BadAmt();
    error IdleMiss();
    error GateMiss();
    error Ltv();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert OnlyKing();
        _;
    }

    constructor(
        address morpho_,
        address eusd_,
        address rss_,
        address gate_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoAmo(morpho_);
        eusd = IERC20(eusd_);
        rss = IERC20(rss_);
        gate = IBoundGateAmo(gate_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoAmo.MarketParams({
            loanToken: eusd_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        requireGate = gate_ != address(0);
    }

    function setRequireGate(bool on) external onlyOwner {
        requireGate = on;
        emit GateToggled(on);
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function packReady() public view returns (bool) {
        if (!requireGate) return true;
        if (!gate.isProven(king)) return false;
        (uint256 v,, bool valid) = gate.attestations(king);
        return valid && v >= gate.minThreshold();
    }

    function book() external view returns (uint256 idleEusd, uint256 supply, uint256 borrow, bool proven) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        supply = s;
        borrow = b;
        idleEusd = idle();
        proven = packReady();
    }

    /// @notice Pull eUSD from `from` (Landing) → unmatched Morpho supply. No borrow in this path.
    function supplyAmo(address from, uint256 eusdAmt) external onlyKing nonReentrant {
        if (eusdAmt == 0) revert BadAmt();
        eusd.safeTransferFrom(from, address(this), eusdAmt);
        eusd.approve(address(morpho), eusdAmt);
        morpho.supply(mp, eusdAmt, 0, landing, "");
        lastSupply = eusdAmt;
        emit AmoSupplied(eusdAmt, idle());
    }

    /// @notice Post RSS collateral for king hot.
    function postCollateral(uint256 rssAmt) external onlyKing nonReentrant {
        if (rssAmt == 0) rssAmt = rss.balanceOf(king);
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(king, address(this), rssAmt);
        rss.approve(address(morpho), rssAmt);
        morpho.supplyCollateral(mp, rssAmt, king, "");
        lastColl = rssAmt;
        emit CollPosted(rssAmt);
    }

    /// @notice Borrow eUSD when idle ≥ ask. Proof-gated when `requireGate`.
    function borrowEusd(uint256 eusdAmt, address receiver) external onlyKing nonReentrant returns (uint256) {
        if (eusdAmt == 0) revert BadAmt();
        if (!packReady()) revert GateMiss();
        morpho.accrueInterest(mp);
        if (idle() < eusdAmt) revert IdleMiss();
        if (receiver == address(0)) receiver = king;
        morpho.borrow(mp, eusdAmt, 0, king, receiver);
        lastBorrow = eusdAmt;
        emit EusdBorrowed(eusdAmt, receiver, idle());
        return eusdAmt;
    }
}
