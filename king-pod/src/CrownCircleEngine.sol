// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashCb {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssC {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
}

interface IEusdC {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

/// @title CrownCircleEngine
/// @notice ENGINEERS spendable liquidity — does not wait for idle.
/// @dev 1) Flash-unwind HOT's PARK self-seed knot (supply≈$216M / borrow≈$217M):
///         repay debt → pull supply → peel yRSS → free RSS → repay flash (fee 0).
///      2) Mint eUSD payroll to Landing (sovereign USD — HOT is minter).
///      Idle is CREATED in-tx by clearing our own borrow, not begged from curators.
contract CrownCircleEngine is Ownable, ReentrancyGuard, IMorphoFlashCb {
    using SafeTransfer for IERC20;

    IMorphoC public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IYrssC public immutable yrss;
    IEusdC public immutable eusd;
    address public immutable king;
    address public landing;
    bytes32 public immutable parkId;
    IMorphoC.MarketParams public mpPark;

    bool public armed = true;
    bool private _locking;

    uint256 public lastDebtRepaid;
    uint256 public lastSupplyPulled;
    uint256 public lastYrssPulled;
    uint256 public lastRssFreed;
    uint256 public lastUsdcToLanding;
    uint256 public lastEusdMinted;

    event Armed(bool on);
    event LandingSet(address landing);
    event KnotUnwound(uint256 debt, uint256 supplyPulled, uint256 yrssPulled, uint256 rssFreed, uint256 usdcLanding);
    event PayrollMinted(uint256 eusdAmt, address to);

    error KingOnly();
    error NotArmed();
    error OnlyMorpho();
    error NoPos();
    error Short();
    error NotMinter();
    error BadAmt();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address eusd_,
        address king_,
        address landing_,
        bytes32 parkId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoC(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IYrssC(yrss_);
        eusd = IEusdC(eusd_);
        king = king_;
        landing = landing_;
        parkId = parkId_;
        mpPark = IMorphoC.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    /// @notice Preview flash size = king's park debt (assets up) + 1 wei.
    /// @dev Call after accrueInterest for tip-accurate debt.
    function previewFlash() public view returns (uint256 flashAmt, uint256 supplyShares, uint256 borShares, uint256 coll) {
        uint128 bor;
        uint128 c;
        (supplyShares, bor, c) = morpho.position(parkId, king);
        borShares = uint256(bor);
        coll = uint256(c);
        if (bor == 0) return (0, supplyShares, 0, coll);
        (,, uint128 tba, uint128 tbs,,) = morpho.market(parkId);
        flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        unchecked {
            flashAmt += 1;
        }
    }

    /// @notice ENGINEER: unwind self-seed knot → USDC dust to Landing + RSS free to king.
    ///         Creates idle by repaying OUR borrow — no curator wait.
    /// @dev Prefund this contract with shortfall USDC if debt > supply+yRSS (accrued IRM gap).
    function unwindKnot() external onlyKing nonReentrant {
        if (!armed) revert NotArmed();
        morpho.accrueInterest(mpPark);
        (uint256 flashAmt, uint256 supShares, uint256 borShares, uint256 coll) = previewFlash();
        if (borShares == 0 && coll == 0 && supShares == 0) revert NoPos();

        _locking = true;
        if (flashAmt > 0) {
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, borShares, coll));
        } else {
            if (supShares > 0) {
                morpho.withdraw(mpPark, 0, supShares, king, landing);
            }
            if (coll > 0) {
                morpho.withdrawCollateral(mpPark, coll, king, king);
            }
            emit KnotUnwound(0, 0, 0, coll, 0);
        }
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        (uint256 supShares, uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256, uint256));
        usdc.safeApprove(address(morpho), type(uint256).max);

        morpho.accrueInterest(mpPark);

        // 1) Kill debt → idle appears because WE were the borrower
        if (borShares > 0) {
            morpho.repay(mpPark, 0, borShares, king, "");
            lastDebtRepaid = assets; // approx; exact is share-based
        }

        // 2) Pull king's USDC supply (repay source #1)
        uint256 pulled;
        if (supShares > 0) {
            (pulled,) = morpho.withdraw(mpPark, 0, supShares, king, address(this));
            lastSupplyPulled = pulled;
        }

        // 3) Peel yRSS now that util is open (repay source #2 / surplus)
        uint256 yrssUsed;
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW > 0) {
            uint256 usdcBefore = usdc.balanceOf(address(this));
            yrss.withdraw(maxW, address(this), king);
            yrssUsed = usdc.balanceOf(address(this)) - usdcBefore;
            lastYrssPulled = yrssUsed;
        }

        // 4) Free RSS collateral → king
        if (coll > 0) {
            morpho.withdrawCollateral(mpPark, coll, king, king);
            lastRssFreed = coll;
        }

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) revert Short();

        // Morpho pulls `assets` after callback (flash fee = 0)
        usdc.safeApprove(address(morpho), assets);

        uint256 dust = have - assets;
        if (dust > 0) {
            usdc.safeTransfer(landing, dust);
            lastUsdcToLanding = dust;
        }

        emit KnotUnwound(borShares, pulled, yrssUsed, coll, dust);
    }

    /// @notice ENGINEER payroll: mint eUSD to Landing. No idle. No foreign book.
    function mintPayroll(uint256 eusdAmt) external onlyKing nonReentrant {
        if (!armed) revert NotArmed();
        if (eusdAmt == 0) revert BadAmt();
        if (!eusd.isMinter(address(this))) revert NotMinter();
        eusd.mint(landing, eusdAmt);
        lastEusdMinted = eusdAmt;
        emit PayrollMinted(eusdAmt, landing);
    }

    /// @notice One call: unwind knot then mint sovereign payroll.
    function engineer(uint256 eusdPayroll) external onlyKing nonReentrant {
        if (!armed) revert NotArmed();
        // inline unwind (nonReentrant already) — call internal path
        (uint256 flashAmt, uint256 supShares, uint256 borShares, uint256 coll) = previewFlash();
        if (borShares > 0 || coll > 0 || supShares > 0) {
            _locking = true;
            if (flashAmt > 0) {
                morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, borShares, coll));
            } else {
                if (supShares > 0) morpho.withdraw(mpPark, 0, supShares, king, landing);
                if (coll > 0) morpho.withdrawCollateral(mpPark, coll, king, king);
            }
            _locking = false;
        }
        if (eusdPayroll > 0) {
            if (!eusd.isMinter(address(this))) revert NotMinter();
            eusd.mint(landing, eusdPayroll);
            lastEusdMinted = eusdPayroll;
            emit PayrollMinted(eusdPayroll, landing);
        }
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
