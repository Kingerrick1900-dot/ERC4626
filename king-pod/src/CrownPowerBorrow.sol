// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoPower {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

/// @notice LOANS + TOKENS: seed Morpho loan float, post RSS, borrow USDC to vault, HOLD debt.
/// @dev Not elite-close. Not flash arb. Debt stays. RSS stays posted.
contract CrownPowerBorrow is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoPower public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;
    address public immutable vault;
    IMorphoPower.MarketParams public marketParams;

    event PowerBorrowed(uint256 seedUsdc, uint256 rssCollateral, uint256 borrowUsdc, address vault);

    error Zero();
    error BadVault();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        address vault_,
        IMorphoPower.MarketParams memory params_,
        address owner_
    ) Ownable(owner_) {
        if (king_ == address(0) || vault_ == address(0)) revert Zero();
        morpho = IMorphoPower(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
        vault = vault_;
        marketParams = params_;
    }

    /// @notice Seed S USDC into Morpho, post RSS collateral, borrow B USDC to vault. Debt held.
    /// @param seedUsdc Loan float pulled from King (must be approved).
    /// @param rssCollateral RSS pulled from King (must be approved).
    /// @param borrowUsdc USDC sent to vault (must be <= seedUsdc and within LLTV).
    function powerBorrow(uint256 seedUsdc, uint256 rssCollateral, uint256 borrowUsdc)
        external
        onlyOwner
        nonReentrant
    {
        if (seedUsdc == 0 || rssCollateral == 0 || borrowUsdc == 0) revert Zero();
        if (borrowUsdc > seedUsdc) revert Zero();

        usdc.safeTransferFrom(king, address(this), seedUsdc);
        rss.safeTransferFrom(king, address(this), rssCollateral);

        usdc.safeApprove(address(morpho), seedUsdc);
        rss.safeApprove(address(morpho), rssCollateral);

        morpho.supply(marketParams, seedUsdc, 0, king, bytes(""));
        morpho.supplyCollateral(marketParams, rssCollateral, king, bytes(""));
        morpho.borrow(marketParams, borrowUsdc, 0, king, vault);

        emit PowerBorrowed(seedUsdc, rssCollateral, borrowUsdc, vault);
    }
}
