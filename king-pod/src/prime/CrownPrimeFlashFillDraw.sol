// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownPrime7683Fill} from "./CrownPrime7683Fill.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";
import {SelfRepayingTreasury} from "./SelfRepayingTreasury.sol";

interface IMorphoFlash {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoYrss {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @title CrownPrimeFlashFillDraw
/// @notice Morpho flash → 7683 fill → optional draw to Landing → repay flash from supplier withdraw + top-up.
/// @dev Fill posts USDC via `credit.supply()` as the Fill contract (not this engine). Flash repay
///      pulls idle via `operatorBorrowTo(engine)` unless `repayTopUp` covers principal. Persistent
///      idle + Landing draw requires repayTopUp ≥ flash principal (solver fill is simpler).
contract CrownPrimeFlashFillDraw is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFlash public immutable morpho;
    IERC20 public immutable usdc;
    CrownPrime7683Fill public immutable fill;
    CrownPrimeCredit public immutable credit;
    SelfRepayingTreasury public immutable treasury;
    address public immutable landing;
    address public immutable king;

    /// @notice Optional named repay rails (Morpho supply / yRSS) — same pattern as CrownFlashFreeRss.
    address public yrss;
    address public morphoSupplyKing;
    bytes32 public morphoMarketId;

    bool private _locking;

    event FlashFilledDrawn(
        bytes32 indexed orderId,
        uint256 flashAmt,
        uint256 filledUsdc,
        uint256 drawn,
        uint256 idleLeft,
        uint256 creditBorrowed,
        uint256 topUpUsed
    );
    event RepayRailsSet(address yrss, address morphoSupplyKing, bytes32 marketId);

    error MorphoOnly();
    error BadAmt();
    error RepayMiss();
    error KingOnly();
    error LockMiss();

    constructor(
        address morpho_,
        address usdc_,
        address fill_,
        address credit_,
        address treasury_,
        address landing_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        require(morpho_ != address(0) && usdc_ != address(0) && fill_ != address(0) && credit_ != address(0), "ZERO");
        morpho = IMorphoFlash(morpho_);
        usdc = IERC20(usdc_);
        fill = CrownPrime7683Fill(fill_);
        credit = CrownPrimeCredit(credit_);
        treasury = SelfRepayingTreasury(treasury_);
        landing = landing_;
        king = king_;
    }

    function setRepayRails(address yrss_, address morphoSupplyKing_, bytes32 marketId_) external onlyOwner {
        yrss = yrss_;
        morphoSupplyKing = morphoSupplyKing_;
        morphoMarketId = marketId_;
        emit RepayRailsSet(yrss_, morphoSupplyKing_, marketId_);
    }

    /// @notice Flash USDC → fill open 7683 order → draw remaining idle to `to` → repay flash.
    /// @param repayTopUp USDC pulled from caller to cover flash repay without draining all credit idle.
    /// @param drawTo Landing/recipient for idle draw; `address(0)` = skip draw (keep credit idle).
    function flashFillAndDraw(bytes32 orderId, uint256 usdcIn, address drawTo, uint256 repayTopUp) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (usdcIn == 0) revert BadAmt();
        if (repayTopUp > 0) usdc.safeTransferFrom(msg.sender, address(this), repayTopUp);
        _locking = true;
        morpho.flashLoan(address(usdc), usdcIn, abi.encode(orderId, usdcIn, drawTo, repayTopUp));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert MorphoOnly();
        if (!_locking) revert LockMiss();

        (bytes32 orderId, uint256 usdcIn, address drawTo, uint256 repayTopUp) =
            abi.decode(data, (bytes32, uint256, address, uint256));
        require(assets == usdcIn, "AMT");

        usdc.safeApprove(address(fill), usdcIn);
        fill.fill(orderId, usdcIn);

        uint256 have = usdc.balanceOf(address(this));
        have += _pullFeeFromTreasury();
        have += _pullExternalRepay(assets > have ? assets - have : 0);

        uint256 idleAfterFill = credit.freeUsdc();
        uint256 drawn;
        uint256 borrowedForRepay;

        // Draw to Landing first when topUp (or external) will cover flash repay separately.
        if (drawTo != address(0) && idleAfterFill > 0 && have >= assets) {
            drawn = idleAfterFill;
            credit.operatorBorrowTo(drawTo, drawn);
        }

        idleAfterFill = credit.freeUsdc();
        if (have < assets) {
            borrowedForRepay = assets - have;
            if (borrowedForRepay > idleAfterFill) revert RepayMiss();
            credit.operatorBorrowTo(address(this), borrowedForRepay);
            have += borrowedForRepay;
        }

        uint256 idleLeft = credit.freeUsdc();
        if (usdc.balanceOf(address(this)) < assets) revert RepayMiss();
        usdc.safeApprove(address(morpho), assets);

        emit FlashFilledDrawn(orderId, assets, usdcIn, drawn, idleLeft, borrowedForRepay, repayTopUp);
    }

    function _pullFeeFromTreasury() internal returns (uint256 pulled) {
        if (address(treasury) == address(0)) return 0;
        pulled = usdc.balanceOf(address(treasury));
        if (pulled == 0) return 0;
        // Fee sink is owner-controlled; engine is wired as operator path via direct transfer attempt.
        // Fill sends fee via transfer; pull only what treasury owner pre-approved to this contract.
        uint256 allow = usdc.allowance(address(treasury), address(this));
        if (allow < pulled) pulled = allow;
        if (pulled > 0) {
            usdc.safeTransferFrom(address(treasury), address(this), pulled);
        }
    }

    function _pullExternalRepay(uint256 need) internal returns (uint256 pulled) {
        if (need == 0) return 0;
        // yRSS vault pull (king shares)
        if (yrss != address(0)) {
            uint256 maxW = IMetaMorphoYrss(yrss).maxWithdraw(morphoSupplyKing != address(0) ? morphoSupplyKing : king);
            uint256 take = maxW < need ? maxW : need;
            if (take > 0) {
                IMetaMorphoYrss(yrss).withdraw(take, address(this), morphoSupplyKing != address(0) ? morphoSupplyKing : king);
                pulled += take;
                need -= take;
            }
        }
        // Morpho supply withdraw is market-specific — wired off-chain via repayTopUp when supplyShares=0.
    }
}
