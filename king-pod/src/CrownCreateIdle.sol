// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoIdleFill {
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

interface IYrssIdleFill {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title CrownCreateIdle
/// @notice Rail real USDC → Morpho RSS market DIRECT (not yRSS). Unlocks yRSS withdraw → Landing.
/// @dev Law: idle only exists if unmatched USDC sits in Morpho. createIdle supplies the book.
///      pull100ToLanding redeems king yRSS shares to Landing once maxWithdraw opens.
///      Default ask = $2,000,000. No flash. No ZK fake balance.
contract CrownCreateIdle is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 2_000_000e6; // $2M default rail

    IMorphoIdleFill public immutable morpho;
    IERC20 public immutable usdc;
    IYrssIdleFill public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoIdleFill.MarketParams public mp;
    bytes32 public marketId;

    uint256 public totalCreated;
    uint256 public totalPulled;
    uint256 public lastCreate;
    uint256 public lastPull;

    bool public armed = true;

    event LandingSet(address landing);
    event MarketSet(bytes32 indexed id, address oracle, uint256 lltv);
    event Armed(bool on);
    event IdleCreated(uint256 amt, uint256 idleAfter, uint256 totalCreated);
    event PulledToLanding(uint256 amt, address landing, uint256 landingBal, uint256 totalPulled);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();

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
        morpho = IMorphoIdleFill(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssIdleFill(yrss_);
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

    /// @notice Wire the Morpho RSS/USDC market where yRSS liquidity must unlock (direct supply target).
    function setMarketRss(address rss, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (rss == address(0) || oracle == address(0) || irm == address(0) || lltv == 0 || id == bytes32(0)) {
            revert BadAmt();
        }
        mp = IMorphoIdleFill.MarketParams({
            loanToken: address(usdc),
            collateralToken: rss,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        marketId = id;
        emit MarketSet(id, oracle, lltv);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function maxPull() public view returns (uint256) {
        return yrss.maxWithdraw(king);
    }

    /// @notice King rails USDC into this contract (pre-fund). Or transfer USDC directly then createIdle.
    function fund(uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
    }

    /// @notice Create real Morpho idle: supply USDC DIRECT to RSS market (NOT into yRSS).
    /// @param amt USDC 6dp. 0 = ASK_USDC ($2M) if balance covers, else full contract balance.
    function createIdle(uint256 amt) external onlyKing nonReentrant returns (uint256 supplied) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0) || mp.collateralToken == address(0)) revert NoMarket();

        uint256 bal = usdc.balanceOf(address(this));
        if (amt == 0) {
            amt = bal >= ASK_USDC ? ASK_USDC : bal;
        }
        if (amt == 0) revert BadAmt();

        // Pull shortfall from king if contract underfunded
        if (bal < amt) {
            usdc.safeTransferFrom(msg.sender, address(this), amt - bal);
        }

        // DIRECT Morpho supply — creates unmatched USDC in the book
        morpho.supply(mp, amt, 0, address(this), "");
        supplied = amt;
        totalCreated += amt;
        lastCreate = amt;

        uint256 idleAfter = idle();
        if (idleAfter < amt) {
            // Allow interest/rounding dust; hard fail only if idle did not appear at all
            if (idleAfter == 0) revert IdleMiss();
        }
        emit IdleCreated(amt, idleAfter, totalCreated);
    }

    /// @notice Once Morpho idle exists, redeem king yRSS → Landing (100% peel of `amt`).
    /// @dev King must `yrss.approve(this, type(uint256).max)` first (ERC4626 operator allowance).
    /// @param amt USDC assets to pull. 0 = full maxWithdraw(king).
    function pull100ToLanding(uint256 amt) external onlyKing nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        pulled = amt == 0 || amt > maxW ? maxW : amt;
        if (pulled == 0) revert BadAmt();

        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(pulled, landing, king);
        if (got < pulled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + pulled) revert LandingMiss();

        totalPulled += pulled;
        lastPull = pulled;
        emit PulledToLanding(pulled, landing, usdc.balanceOf(landing), totalPulled);
    }

    /// @notice One-shot: createIdle then pull100 (same tx). Requires USDC + yRSS approval.
    function createIdleAndPull100(uint256 createAmt, uint256 pullAmt)
        external
        onlyKing
        nonReentrant
        returns (uint256 supplied, uint256 pulled)
    {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0) || mp.collateralToken == address(0)) revert NoMarket();

        uint256 bal = usdc.balanceOf(address(this));
        uint256 need = createAmt == 0 ? (bal >= ASK_USDC ? ASK_USDC : bal) : createAmt;
        if (need == 0) revert BadAmt();
        if (bal < need) usdc.safeTransferFrom(msg.sender, address(this), need - bal);

        morpho.supply(mp, need, 0, address(this), "");
        supplied = need;
        totalCreated += need;
        lastCreate = need;
        emit IdleCreated(need, idle(), totalCreated);

        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        pulled = pullAmt == 0 || pullAmt > maxW ? maxW : pullAmt;

        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(pulled, landing, king);
        if (got < pulled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + pulled) revert LandingMiss();

        totalPulled += pulled;
        lastPull = pulled;
        emit PulledToLanding(pulled, landing, usdc.balanceOf(landing), totalPulled);
    }

    /// @notice Rescue stray ERC20 to king (not for normal idle path).
    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
