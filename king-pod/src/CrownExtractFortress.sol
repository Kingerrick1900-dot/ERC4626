// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoExtract {
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

interface IMetaMorphoExtract {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @notice Unwind self-seed fortress → spendable USDC on Landing. No King debit.
/// @dev Flash repay Morpho debt → yRSS withdraw unlocks → flash repaid → surplus → Landing.
contract CrownExtractFortress is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoExtract public immutable morpho;
    IERC20 public immutable usdc;
    IMetaMorphoExtract public immutable yrss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoExtract.MarketParams public mp;

    bool private _locking;

    event Extracted(uint256 debtRepaid, uint256 yrssPulled, uint256 landingPaid);

    error OnlyMorpho();
    error NoDebt();
    error Short();

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address rss_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoExtract(morpho_);
        usdc = IERC20(usdc_);
        yrss = IMetaMorphoExtract(yrss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoExtract.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Extract fortress USDC to Landing in one tx.
    function extractToLanding() external onlyOwner nonReentrant {
        (, uint128 borShares,) = morpho.position(marketId, king);
        if (borShares == 0) revert NoDebt();

        morpho.accrueInterest(mp);
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
        flashAmt += 500e6; // +$500 buffer for interest / rounding

        _locking = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(borShares)));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();

        uint256 borShares = abi.decode(data, (uint256));
        usdc.approve(address(morpho), type(uint256).max);

        // 1) Kill debt — unlocks yRSS withdraw
        morpho.repay(mp, 0, borShares, king, "");

        // 2) Pull king's yRSS USDC (was locked in self-loop)
        uint256 maxW = yrss.maxWithdraw(king);
        uint256 pull = maxW;
        if (pull > 0) {
            yrss.withdraw(pull, address(this), king);
        }

        // 3) Repay flash
        if (usdc.balanceOf(address(this)) < assets) revert Short();
        usdc.approve(address(morpho), assets);

        // 4) Surplus → Landing cold
        uint256 surplus = usdc.balanceOf(address(this)) - assets;
        if (surplus > 0) {
            usdc.safeTransfer(landing, surplus);
        }

        emit Extracted(borShares, pull, surplus);
    }
}
