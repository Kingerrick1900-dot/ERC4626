// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice RSS leverage LOOP — no ETH. Equity = free RSS. Flash USDC = temporary loop capital.
/// Legs:
///   1) Pull free RSS → supplyCollateral (loop equity, raises LTV room)
///   2) Flash USDC → supply (creates idle for the loop borrow)
///   3) Borrow USDC against RSS equity → repay flash; residual → Landing
/// Idle after supply == flash, so residual is 0 unless market already had idle.
/// This is the Venus/Peapods loop shape with RSS instead of WETH.

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
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

contract CrownRssUsdcLoop {
    IMorphoL public immutable morpho;
    IERC20L public immutable usdc;
    IERC20L public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoL.MarketParams public mp;

    uint256 public lastLandingCredit;
    uint256 public lastFlash;
    uint256 public lastRssLooped;
    uint256 public lastBorrow;
    uint256 public lastIdle;

    constructor(address morpho_, address usdc_, address rss_, address king_, address landing_, bytes32 marketId_) {
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

    /// @param rssIn   Free RSS to loop in as equity (no ETH)
    /// @param flashUsdc USDC flash size (loop working capital)
    /// @param landingWant Attempted residual after flash repay
    function loop(uint256 rssIn, uint256 flashUsdc, uint256 landingWant) external {
        require(msg.sender == king, "KING");
        require(rssIn > 0 && flashUsdc > 0, "AMT");
        require(rss.transferFrom(king, address(this), rssIn), "RSS");
        lastRssLooped = rssIn;
        // Leg 1: RSS equity on Morpho (on this contract)
        rss.approve(address(morpho), rssIn);
        morpho.supplyCollateral(mp, rssIn, address(this), "");
        morpho.flashLoan(address(usdc), flashUsdc, abi.encode(landingWant));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        uint256 landingWant = abi.decode(data, (uint256));
        lastFlash = assets;

        // Leg 2: supply flashed USDC → creates idle for the loop
        usdc.approve(address(morpho), assets);
        morpho.supply(mp, assets, 0, address(this), "");

        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        uint256 idle = uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
        lastIdle = idle;

        // Leg 3: borrow against RSS equity — flash repay from borrow, residual → Landing
        uint256 want = assets + landingWant;
        uint256 borrowAmt = want < idle ? want : idle;
        require(borrowAmt >= assets, "LOOP_UNDERWATER");
        morpho.borrow(mp, borrowAmt, 0, address(this), address(this));
        lastBorrow = borrowAmt;

        uint256 credit = borrowAmt - assets;
        if (credit > 0) require(usdc.transfer(landing, credit), "PUSH");
        lastLandingCredit = credit;

        usdc.approve(address(morpho), assets);
    }
}
