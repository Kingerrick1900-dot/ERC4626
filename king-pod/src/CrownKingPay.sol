// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMetaMorphoPay {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoUtil {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice King pay rail — harvest throne benefits without blind principal drains.
/// @dev Sources (in order):
///      1) Loose USDC held here
///      2) yRSS fee shares minted to this contract (setFeeRecipient → here)
///      3) Optional king yRSS principal (approve shares; util floor enforced)
contract CrownKingPay is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant MONTH = 30 days;

    IERC20 public immutable usdc;
    IMetaMorphoPay public immutable yrss;
    IMorphoUtil public immutable morpho;
    bytes32 public immutable rssMarketId;
    address public immutable king;

    uint256 public monthlyCapUsdc;
    uint256 public minIdleUsdc;
    uint256 public paidThisPeriod;
    uint256 public periodStart;

    event CapsSet(uint256 monthlyCapUsdc, uint256 minIdleUsdc);
    event Paid(address to, uint256 amount, uint256 fromLoose, uint256 fromFeeShares, uint256 fromKingYrss);
    event PeriodRolled(uint256 periodStart);

    error Cap();
    error IdleFloor();
    error Zero();

    constructor(
        address usdc_,
        address yrss_,
        address morpho_,
        bytes32 rssMarketId_,
        address king_,
        uint256 monthlyCapUsdc_,
        uint256 minIdleUsdc_,
        address owner_
    ) Ownable(owner_) {
        usdc = IERC20(usdc_);
        yrss = IMetaMorphoPay(yrss_);
        morpho = IMorphoUtil(morpho_);
        rssMarketId = rssMarketId_;
        king = king_;
        monthlyCapUsdc = monthlyCapUsdc_;
        minIdleUsdc = minIdleUsdc_;
        periodStart = block.timestamp;
    }

    function setCaps(uint256 monthlyCapUsdc_, uint256 minIdleUsdc_) external onlyOwner {
        monthlyCapUsdc = monthlyCapUsdc_;
        minIdleUsdc = minIdleUsdc_;
        emit CapsSet(monthlyCapUsdc_, minIdleUsdc_);
    }

    function _roll() internal {
        if (block.timestamp >= periodStart + MONTH) {
            periodStart = block.timestamp;
            paidThisPeriod = 0;
            emit PeriodRolled(periodStart);
        }
    }

    function remainingCap() public view returns (uint256) {
        if (block.timestamp >= periodStart + MONTH) return monthlyCapUsdc;
        if (paidThisPeriod >= monthlyCapUsdc) return 0;
        return monthlyCapUsdc - paidThisPeriod;
    }

    function marketIdle() public view returns (uint256) {
        (uint128 supply,, uint128 borrow,,,) = morpho.market(rssMarketId);
        return uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
    }

    function _pullIdleBounded(uint256 want, address shareOwner) internal returns (uint256 got) {
        if (want == 0) return 0;
        uint256 idle = marketIdle();
        if (idle <= minIdleUsdc) revert IdleFloor();
        uint256 room = idle - minIdleUsdc;
        if (want > room) want = room;
        uint256 maxW = yrss.maxWithdraw(shareOwner);
        if (want > maxW) want = maxW;
        if (want == 0) return 0;
        yrss.withdraw(want, address(this), shareOwner);
        return want;
    }

    /// @param wantUsdc Max to send (0 = remaining monthly cap)
    /// @param maxFromKingYrss Cap on king's vault principal (0 = fees/loose only)
    function pay(uint256 wantUsdc, uint256 maxFromKingYrss) external onlyOwner nonReentrant {
        _roll();
        uint256 capLeft = remainingCap();
        if (capLeft == 0) revert Cap();
        if (wantUsdc == 0) wantUsdc = capLeft;
        if (wantUsdc > capLeft) wantUsdc = capLeft;

        uint256 fromLoose;
        uint256 fromFeeShares;
        uint256 fromKingYrss;

        uint256 feeBal = usdc.balanceOf(address(this));
        fromLoose = feeBal >= wantUsdc ? wantUsdc : feeBal;
        uint256 need = wantUsdc - fromLoose;

        if (need > 0 && yrss.balanceOf(address(this)) > 0) {
            fromFeeShares = _pullIdleBounded(need, address(this));
            need = wantUsdc - fromLoose - fromFeeShares;
        }

        if (need > 0 && maxFromKingYrss > 0) {
            uint256 pull = need > maxFromKingYrss ? maxFromKingYrss : need;
            fromKingYrss = _pullIdleBounded(pull, king);
        }

        uint256 total = fromLoose + fromFeeShares + fromKingYrss;
        if (total == 0) revert Zero();

        paidThisPeriod += total;
        usdc.safeTransfer(king, total);
        emit Paid(king, total, fromLoose, fromFeeShares, fromKingYrss);
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
