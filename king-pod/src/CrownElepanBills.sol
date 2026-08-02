// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoBills {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IYeleBills {
    function maxRedeem(address owner) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Unwind ELE Morpho self-loop → free Elepan. yELE shares must be on king.
/// @dev Prefund ~$100 USDC on this for rounding. No vault recycle.
contract CrownElepanBills is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoBills public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    IYeleBills public immutable yele;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoBills.MarketParams public mp;

    bool private _locking;

    event Unwound(uint256 debtClosed, uint256 eleFreed, uint256 surplusToLanding);

    error OnlyMorpho();
    error NoYele();
    error Short();

    constructor(
        address morpho_,
        address usdc_,
        address elepan_,
        address yele_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoBills(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        yele = IYeleBills(yele_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoBills.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    function unwind() external onlyOwner nonReentrant {
        if (yele.balanceOf(king) == 0) revert NoYele();

        morpho.accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);

        uint256 flashAmt;
        if (borShares > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            flashAmt += 5e6;
        }

        _locking = true;
        if (flashAmt > 0) {
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(borShares), uint256(coll)));
        } else if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
        }
        _locking = false;

        uint256 surplus = usdc.balanceOf(address(this));
        if (surplus > 0) usdc.safeTransfer(landing, surplus);
        emit Unwound(borShares, coll, surplus);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        (uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);

        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);

        uint256 maxR = yele.maxRedeem(king);
        if (maxR > 0) {
            yele.redeem(maxR, address(this), king);
        }

        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.approve(address(morpho), assets);
    }
}
