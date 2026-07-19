// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoZ {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYrssZ {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
}

/// @notice Zero Morpho dust: flash → repay all shares → free all coll to king → yRSS covers flash.
contract CrownZeroMorpho is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoZ public immutable morpho;
    IERC20 public immutable usdc;
    IYrssZ public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoZ.MarketParams public mp;
    bool private _locking;

    error OnlyMorpho();
    error Short();
    error NoDebt();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address yrss_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoZ(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssZ(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoZ.MarketParams(usdc_, rss_, oracle_, irm_, lltv_);
    }

    function zeroBooks() external onlyOwner nonReentrant {
        morpho.accrueInterest(mp);
        (, uint128 bor, uint128 coll) = morpho.position(marketId, king);
        if (bor == 0 && coll == 0) return;

        if (bor > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
            flashAmt += 10e6; // $10 buffer; yRSS ~$301 covers
            _locking = true;
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(bor), uint256(coll)));
            _locking = false;
        } else if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
        }

        // Sweep any leftover yRSS liquidity to king (no recycle into Morpho)
        uint256 maxR = yrss.maxRedeem(king);
        if (maxR > 0) {
            yrss.redeem(maxR, king, king);
        }
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho) || !_locking) revert OnlyMorpho();
        (uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);
        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) {
            uint256 need = assets - have;
            uint256 maxW = yrss.maxWithdraw(king);
            uint256 pull = maxW < need ? maxW : need;
            if (pull > 0) yrss.withdraw(pull, address(this), king);
            // also use king's wallet USDC if approved
            have = usdc.balanceOf(address(this));
            if (have < assets) {
                uint256 still = assets - have;
                uint256 kingBal = usdc.balanceOf(king);
                uint256 take = kingBal < still ? kingBal : still;
                if (take > 0) usdc.safeTransferFrom(king, address(this), take);
                have = usdc.balanceOf(address(this));
            }
        }
        if (have < assets) revert Short();
        usdc.approve(address(morpho), assets);
    }
}
