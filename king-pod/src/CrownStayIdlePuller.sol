// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoStay {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYrssStay {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title CrownStayIdlePuller
/// @notice SUPPLY-ONLY idle engineer. USDC → Morpho direct. Never borrows. Keeps util buffer.
/// @dev Replaces gasPark payroll path. Idle that STAYS → yRSS maxWithdraw opens → pull Landing.
///      maxUtilBps default 9000 (90%). Supply capped so util never hits 100% against ourselves.
contract CrownStayIdlePuller is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant ASK_USDC = 2_000_000e6;

    IMorphoStay public immutable morpho;
    IERC20 public immutable usdc;
    IYrssStay public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoStay.MarketParams public mp;
    bytes32 public marketId;

    /// @notice Max utilization after supply (default 90%). Remainder is the stay-idle buffer.
    uint256 public maxUtilBps = 9_000;
    bool public armed = true;

    uint256 public totalSupplied;
    uint256 public totalPulled;
    uint256 public lastSupply;
    uint256 public lastPull;

    event LandingSet(address landing);
    event MarketSet(bytes32 indexed id, address oracle, uint256 lltv);
    event MaxUtilBpsSet(uint256 bps);
    event Armed(bool on);
    event StayIdleSupplied(uint256 amt, uint256 idleAfter, uint256 utilBps);
    event PulledToLanding(uint256 amt, uint256 landingBal);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error UtilCap();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();
    error NoBorrow(); // belt: this contract must never borrow

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        require(morpho_ != address(0) && usdc_ != address(0) && yrss_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ZERO");
        morpho = IMorphoStay(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssStay(yrss_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(morpho_, type(uint256).max);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setMaxUtilBps(uint256 bps) external onlyOwner {
        if (bps == 0 || bps >= BPS) revert BadAmt(); // never allow 100%
        maxUtilBps = bps;
        emit MaxUtilBpsSet(bps);
    }

    function setMarketRss(address rss, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (rss == address(0) || oracle == address(0) || irm == address(0) || id == bytes32(0)) revert BadAmt();
        mp = IMorphoStay.MarketParams(address(usdc), rss, oracle, irm, lltv);
        marketId = id;
        emit MarketSet(id, oracle, lltv);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function utilBps() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        if (s == 0) return 0;
        return (uint256(b) * BPS) / uint256(s);
    }

    /// @notice Max USDC this puller may supply without breaching maxUtilBps.
    function maxSupplyForBuffer() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        // After supply x: util' = b / (s+x) <= maxUtil/BPS
        // b * BPS <= maxUtil * (s+x) => x >= (b*BPS)/maxUtil - s
        // Max x is unbounded upward for lowering util; any supply helps.
        // Cap only matters if we had a borrow path — for supply-only, always ok.
        // Still return a suggested ASK-sized chunk for ops.
        if (s == 0) return ASK_USDC;
        // Room until we would need negative supply — always can supply.
        // Suggested: enough to bring util to maxUtilBps if currently above, else ASK.
        uint256 targetS = (uint256(b) * BPS + maxUtilBps - 1) / maxUtilBps; // ceil
        if (targetS > uint256(s)) return targetS - uint256(s);
        return ASK_USDC;
    }

    function shareClaim() external view returns (uint256) {
        return yrss.convertToAssets(yrss.balanceOf(king));
    }

    function maxPull() public view returns (uint256) {
        return yrss.maxWithdraw(king);
    }

    function fund(uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
    }

    /// @notice SUPPLY ONLY — Morpho direct. No yRSS deposit. No borrow. Idle stays.
    function stayIdle(uint256 amt) external onlyKing nonReentrant returns (uint256 supplied) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();

        uint256 bal = usdc.balanceOf(address(this));
        if (amt == 0) amt = bal >= ASK_USDC ? ASK_USDC : bal;
        if (amt == 0) revert BadAmt();
        if (bal < amt) usdc.safeTransferFrom(msg.sender, address(this), amt - bal);

        // Explicit: this contract has no borrow function. Refuse any sneak path.
        morpho.supply(mp, amt, 0, address(this), "");
        supplied = amt;
        totalSupplied += amt;
        lastSupply = amt;

        uint256 u = utilBps();
        // After unmatched supply, util must be strictly below 100%
        if (u >= BPS) revert UtilCap();
        emit StayIdleSupplied(amt, idle(), u);
    }

    /// @notice Use king yRSS shares → Landing once stay-idle opened maxWithdraw.
    function pullSharesToLanding(uint256 amt) external onlyKing nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        pulled = amt == 0 || amt > maxW ? maxW : amt;

        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(pulled, landing, king);
        if (got < pulled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + pulled) revert LandingMiss();

        totalPulled += pulled;
        lastPull = pulled;
        emit PulledToLanding(pulled, usdc.balanceOf(landing));
    }

    /// @notice Permissionless: if idle buffer exists and shares unlock, pull all to Landing.
    function pokePull() external nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        if (idle() == 0) revert IdleMiss();
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        pulled = maxW;
        uint256 before = usdc.balanceOf(landing);
        // King must have approved this puller on yRSS beforehand
        uint256 got = yrss.withdraw(pulled, landing, king);
        if (got < pulled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + pulled) revert LandingMiss();
        totalPulled += pulled;
        lastPull = pulled;
        emit PulledToLanding(pulled, usdc.balanceOf(landing));
    }

    /// @dev Hard refuse borrow selectors if someone expects gasPark behavior.
    function borrow(uint256) external pure {
        revert NoBorrow();
    }

    function gasPark(uint256, uint256) external pure {
        revert NoBorrow();
    }
}
