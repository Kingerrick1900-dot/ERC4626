// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice LI.FI free-first (King order):
/// Flash USDC → repay debt → withdraw excess freed RSS as equity →
/// supply as NEW position → borrow USDC → repay flash FROM THE BORROW.
/// Landing credit = borrowed − flash (0 when market idle == flash).

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IOracleL {
    function price() external view returns (uint256);
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
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

contract CrownLiFiFreeFirst {
    uint256 internal constant VIRTUAL = 1e6;

    IMorphoL public immutable morpho;
    IERC20L public immutable usdc;
    IERC20L public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoL.MarketParams public mp;

    uint256 public lastLandingCredit;
    uint256 public lastFlash;
    uint256 public lastBorrow;
    uint256 public lastRssEquity;
    uint256 public lastIdle;
    string public lastMode;

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_
    ) {
        morpho = IMorphoL(morpho_);
        usdc = IERC20L(usdc_);
        rss = IERC20L(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoL(morpho_).idToMarketParams(marketId_);
        mp = IMorphoL.MarketParams(loan, coll, oracle, irm, lltv);
    }

    /// @notice Free-first. `landingUsdc` = attempted residual after flash repay from borrow.
    function runFreeFirst(uint256 usdcFlash, uint256 extraRss, uint256 landingUsdc) external {
        require(msg.sender == king, "KING");
        if (extraRss > 0) require(rss.transferFrom(king, address(this), extraRss), "RSS");
        morpho.flashLoan(address(usdc), usdcFlash, abi.encode(landingUsdc));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        uint256 landingWant = abi.decode(data, (uint256));
        lastFlash = assets;

        // 1-2: repay debt → creates idle, raises freeable excess
        usdc.approve(address(morpho), assets);
        morpho.repay(mp, assets, 0, king, "");

        // 3: withdraw excess RSS only (full withdraw reverts under residual debt)
        uint256 excess = _excessCollateral(king);
        // leave buffer so Morpho LTV check passes after interest rounding
        if (excess > 1e18) excess -= 1e18;
        if (excess > 0) {
            morpho.withdrawCollateral(mp, excess, king, address(this));
        }

        // 4: freed RSS (+ optional hot RSS) = equity for NEW position
        uint256 rssEquity = rss.balanceOf(address(this));
        lastRssEquity = rssEquity;
        require(rssEquity > 0, "NO_RSS_EQUITY");
        rss.approve(address(morpho), rssEquity);
        morpho.supplyCollateral(mp, rssEquity, address(this), "");

        // Idle from repay. Flash repaid from BORROW against new equity — not supply withdraw.
        (uint128 supplyAssets,, uint128 borrowAssets,,,) = morpho.market(marketId);
        uint256 idle =
            uint256(supplyAssets) > uint256(borrowAssets) ? uint256(supplyAssets) - uint256(borrowAssets) : 0;
        lastIdle = idle;

        uint256 want = assets + landingWant;
        uint256 borrowAmt = want < idle ? want : idle;
        uint256 ltvCap = _maxBorrow(rssEquity);
        if (borrowAmt > ltvCap) borrowAmt = ltvCap;
        require(borrowAmt >= assets, "BORROW_LT_FLASH");

        morpho.borrow(mp, borrowAmt, 0, address(this), address(this));
        lastBorrow = borrowAmt;

        // 5-6: repay flash from borrow; residual → Landing
        uint256 credit = borrowAmt - assets;
        if (credit > 0) require(usdc.transfer(landing, credit), "PUSH");
        lastLandingCredit = credit;
        lastMode = "FREE_FIRST";
        usdc.approve(address(morpho), assets);
    }

    function _excessCollateral(address user) internal view returns (uint256) {
        (, uint128 borrowShares, uint128 coll) = morpho.position(marketId, user);
        if (coll == 0) return 0;
        if (borrowShares == 0) return uint256(coll);

        (,, uint128 borrowAssets, uint128 totalBorrowShares,,) = morpho.market(marketId);
        // Morpho SharesMath mulDivUp with VIRTUAL assets/shares
        uint256 debtUp = (
            uint256(borrowShares) * (uint256(borrowAssets) + VIRTUAL) + (uint256(totalBorrowShares) + VIRTUAL) - 1
        ) / (uint256(totalBorrowShares) + VIRTUAL);

        uint256 price = IOracleL(mp.oracle).price();
        // coll >= debt * 1e36 * 1e18 / (price * lltv)  (ceil)
        uint256 minColl = (debtUp * 1e36 * 1e18 + (price * mp.lltv) - 1) / (price * mp.lltv);
        if (uint256(coll) <= minColl) return 0;
        return uint256(coll) - minColl;
    }

    function _maxBorrow(uint256 collAmt) internal view returns (uint256) {
        uint256 price = IOracleL(mp.oracle).price();
        uint256 collValue = collAmt * price / 1e36;
        return collValue * mp.lltv / 1e18;
    }
}
