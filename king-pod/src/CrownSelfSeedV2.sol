// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoElephant {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

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

interface IVaultV2Elephant {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice War elephant ATTACK — fully atomic inside Morpho flash.
/// @dev If anything fails, the whole flash reverts: no debt, no vault shares, no stuck RSS.
///      RSS is pulled + posted INSIDE the callback (not before). King must Morpho-authorize this.
contract CrownSelfSeedV2 is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 9_000_000e6;
    uint256 public constant MAX_LTV_BPS = 7000;

    IMorphoElephant public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IVaultV2Elephant public immutable vault;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoElephant.MarketParams public mp;

    bool private _locking;

    event AttackSeeded(uint256 rssColl, uint256 usdcToVault, uint256 borrowUsdc, uint256 vaultShares);

    error OnlyMorpho();
    error BadAmt();
    error Ltv();
    error NoLiquidity();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address vault_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoElephant(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        vault = IVaultV2Elephant(vault_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoElephant.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param rssAmount RSS to post (0 = full king balance)
    /// @param borrowUsdc USDC size (0 = ASK_USDC $9M). Min $1 for tests; live plan uses $9M.
    function attack(uint256 rssAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = ASK_USDC;
        if (borrowUsdc == 0) revert BadAmt();

        if (rssAmount == 0) rssAmount = rss.balanceOf(king);
        if (borrowUsdc * 1e18 > (rssAmount * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        // ONLY flash — collateral + deposit + borrow all happen inside callback (all-or-nothing)
        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(rssAmount, borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 rssAmount, uint256 borrowUsdc) = abi.decode(data, (uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        // 1) Pull RSS + post as king's collateral (reverts => whole flash reverts, RSS stays on king)
        rss.safeTransferFrom(king, address(this), rssAmount);
        rss.approve(address(morpho), rssAmount);
        morpho.supplyCollateral(mp, rssAmount, king, "");

        // 2) Seed Vault V2 — shares to king
        usdc.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, king);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoLiquidity();

        // 3) Borrow against king's RSS to repay flash
        morpho.borrow(mp, assets, 0, king, address(this));
        usdc.approve(address(morpho), assets);

        emit AttackSeeded(rssAmount, assets, assets, shares);
    }
}

/// @notice Emergency recovery if King ever has Morpho debt/coll or needs to free RSS.
/// @dev Authorized by king via Morpho setAuthorization. Owner = hot.
contract CrownRecoverElephant is Ownable {
    using SafeTransfer for IERC20;

    IMorphoElephant public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoElephant.MarketParams public mp;

    event Recovered(uint256 debtRepaid, uint256 rssFreed);

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoElephant(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
        marketId = marketId_;
        mp = IMorphoElephant.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Repay king's Morpho debt (pull USDC from king) and return all RSS collateral to king.
    function repayAndFree() external onlyOwner {
        (, uint128 borrowShares, uint128 coll) = morpho.position(marketId, king);

        uint256 repaid;
        if (borrowShares > 0) {
            // Repay max by shares; USDC pulled from this contract — king must transfer/approve USDC first
            uint256 usdcBal = usdc.balanceOf(address(this));
            if (usdcBal == 0) {
                usdcBal = usdc.balanceOf(king);
                usdc.safeTransferFrom(king, address(this), usdcBal);
            }
            usdc.approve(address(morpho), usdcBal);
            (repaid,) = morpho.repay(mp, 0, borrowShares, king, "");
        }

        (, , uint128 collLeft) = morpho.position(marketId, king);
        if (collLeft > 0) {
            morpho.withdrawCollateral(mp, uint256(collLeft), king, king);
        }

        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.safeTransfer(king, dust);

        emit Recovered(repaid, uint256(coll));
    }

    /// @notice If debt is already 0 but RSS still posted, free it.
    function freeCollateralOnly() external onlyOwner {
        (, uint128 borrowShares, uint128 coll) = morpho.position(marketId, king);
        require(borrowShares == 0, "debt open");
        if (coll > 0) morpho.withdrawCollateral(mp, uint256(coll), king, king);
        emit Recovered(0, uint256(coll));
    }
}
