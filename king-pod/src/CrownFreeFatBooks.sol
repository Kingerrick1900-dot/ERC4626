// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoFreeFat {
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

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice COMPLETE free of fat self-borrow books → RSS (+ any leftover loan) to king.
/// @dev Requires king hold ≥1 wei of loan token to cover Morpho share rounding.
contract CrownFreeFatBooks is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoFreeFat public immutable morpho;
    IERC20 public immutable rss;
    address public immutable king;

    bool private _locking;
    IMorphoFreeFat.MarketParams private _mp;
    bytes32 private _marketId;

    event BookFreed(address loan, uint256 flashAmt, uint256 supplyPulled, uint256 rssFreed);

    error OnlyMorpho();
    error Short();
    error NoPos();
    error NotClear();

    constructor(address morpho_, address rss_, address king_, address owner_) Ownable(owner_) {
        morpho = IMorphoFreeFat(morpho_);
        rss = IERC20(rss_);
        king = king_;
    }

    /// @notice Fully close one book. Reverts if any borrow/collateral remains.
    function freeBook(address loan, address oracle, address irm, uint256 lltv, bytes32 marketId)
        external
        onlyOwner
        nonReentrant
    {
        _mp = IMorphoFreeFat.MarketParams({
            loanToken: loan, collateralToken: address(rss), oracle: oracle, irm: irm, lltv: lltv
        });
        _marketId = marketId;

        morpho.accrueInterest(_mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares == 0 && coll == 0 && supShares == 0) revert NoPos();

        if (borShares > 0) {
            require(IERC20(loan).balanceOf(king) > 0, "need-loan-dust");
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);

            _locking = true;
            morpho.flashLoan(loan, flashAmt, abi.encode(supShares, uint256(borShares)));
            _locking = false;
        } else if (supShares > 0) {
            morpho.withdraw(_mp, 0, supShares, king, king);
        }

        morpho.accrueInterest(_mp);
        (, uint128 borLeft, uint128 collLeft) = morpho.position(marketId, king);
        if (collLeft > 0) {
            morpho.withdrawCollateral(_mp, collLeft, king, king);
            emit BookFreed(loan, 0, 0, collLeft);
        }

        (, borLeft, collLeft) = morpho.position(marketId, king);
        (uint256 supLeft,,) = morpho.position(marketId, king);
        if (borLeft != 0 || collLeft != 0 || supLeft != 0) revert NotClear();

        uint256 leftover = IERC20(loan).balanceOf(address(this));
        if (leftover > 0) IERC20(loan).safeTransfer(king, leftover);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint256 supShares, uint256 borShares) = abi.decode(data, (uint256, uint256));

        IERC20 loanTok = IERC20(_mp.loanToken);
        loanTok.safeApprove(address(morpho), type(uint256).max);

        morpho.repay(_mp, 0, borShares, king, "");

        uint256 pulled;
        if (supShares > 0) {
            (pulled,) = morpho.withdraw(_mp, 0, supShares, king, address(this));
        }

        uint256 have = loanTok.balanceOf(address(this));
        if (have < assets) {
            uint256 need = assets - have;
            uint256 kingBal = loanTok.balanceOf(king);
            uint256 take = kingBal < need ? kingBal : need;
            if (take > 0) loanTok.safeTransferFrom(king, address(this), take);
            have = loanTok.balanceOf(address(this));
        }
        if (have < assets) revert Short();

        loanTok.safeApprove(address(morpho), assets);
        uint256 dust = have - assets;
        if (dust > 0) loanTok.safeTransfer(king, dust);

        emit BookFreed(_mp.loanToken, assets, pulled, 0);
    }
}
