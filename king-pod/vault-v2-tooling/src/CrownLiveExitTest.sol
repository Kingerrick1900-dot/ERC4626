// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IVaultV2L {
    function deposit(uint256 assets, address onBehalf) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address onBehalf) external returns (uint256);
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Gas-only live forceDeallocate proof (Morpho flash fee 0). No USDC prefund.
/// @dev Requires forceDeallocatePenalty(adapter)==0 for clean close. Single flash of 2x assets.
///      End: vault shares 0, Morpho flat, RSS back to king. Exit path proven on-chain.
contract CrownLiveExitTest {
    address public immutable morpho;
    address public immutable usdc;
    address public immutable rss;
    address public immutable vault;
    address public immutable adapter;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoL.MarketParams public mp;

    bool public done;
    uint256 public provenAssets;

    error OnlyMorpho();
    error OnlyKing();
    error Already();
    error SharesLeft();
    error MorphoLeft();

    event LiveExitProven(uint256 assets);

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address vault_,
        address adapter_,
        address king_,
        bytes32 marketId_,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) {
        morpho = morpho_;
        usdc = usdc_;
        rss = rss_;
        vault = vault_;
        adapter = adapter_;
        king = king_;
        marketId = marketId_;
        mp = IMorphoL.MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @param assets USDC raw test size (e.g. 100e6). Flashes 2*assets.
    function run(uint256 assets) external {
        if (msg.sender != king) revert OnlyKing();
        if (done) revert Already();

        IMorphoL(morpho).flashLoan(usdc, assets * 2, abi.encode(assets));

        if (IVaultV2L(vault).balanceOf(address(this)) != 0) revert SharesLeft();
        (uint256 ss, uint128 bor, uint128 coll) = IMorphoL(morpho).position(marketId, address(this));
        if (ss != 0 || bor != 0 || coll != 0) revert MorphoLeft();

        provenAssets = assets;
        done = true;
        emit LiveExitProven(assets);
    }

    function onMorphoFlashLoan(uint256 flashAssets, bytes calldata data) external {
        if (msg.sender != morpho) revert OnlyMorpho();
        uint256 assets = abi.decode(data, (uint256));
        require(flashAssets == assets * 2, "flash");

        // 1) Seed vault with `assets` (liquidityAdapter auto-allocates to RSS/USDC market)
        IERC20L(usdc).approve(vault, assets);
        IVaultV2L(vault).deposit(assets, address(this));

        // 2) Drain market util: post RSS, borrow `assets`
        uint256 collAmt = assets * 2 * 1e12;
        require(IERC20L(rss).transferFrom(king, address(this), collAmt), "rss");
        IERC20L(rss).approve(morpho, collAmt);
        IMorphoL(morpho).supplyCollateral(mp, collAmt, address(this), hex"");
        IMorphoL(morpho).borrow(mp, assets, 0, address(this), address(this));

        // 3) IKR liquidity + forceDeallocate + withdraw (penalty must be 0)
        IERC20L(usdc).approve(morpho, assets);
        IMorphoL(morpho).supply(mp, assets, 0, address(this), hex"");
        IVaultV2L(vault).forceDeallocate(adapter, abi.encode(mp), assets, address(this));
        IVaultV2L(vault).withdraw(assets, address(this), address(this));

        // 4) Close Morpho legs, return RSS
        IERC20L(usdc).approve(morpho, assets);
        IMorphoL(morpho).repay(mp, assets, 0, address(this), hex"");
        IMorphoL(morpho).withdraw(mp, assets, 0, address(this), address(this));
        (,, uint128 collLeft) = IMorphoL(morpho).position(marketId, address(this));
        if (collLeft > 0) {
            IMorphoL(morpho).withdrawCollateral(mp, uint256(collLeft), address(this), king);
        }

        uint256 rb = IERC20L(rss).balanceOf(address(this));
        if (rb > 0) require(IERC20L(rss).transfer(king, rb), "rss back");

        // 5) Repay flash 2*assets (fee 0)
        IERC20L(usdc).approve(morpho, flashAssets);
    }
}
