// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownPermissionlessWethSeed
/// @notice Engineer WETH equity the open-market way (Kamino/Venus seed law):
///         anyone brings WETH, receives RSS from escrow (+ sweetener). WETH goes to raid sink.
/// @dev No desk-wait. No Morpho rematch. Loan ≠ dump: filler buys RSS inventory, kingdom gets WETH coll.

interface IERC20W {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IOracleW {
    function price() external view returns (uint256);
}

contract CrownPermissionlessWethSeed {
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;
    uint256 internal constant BPS = 10_000;
    address internal constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    IERC20W public immutable rss;
    IERC20W public immutable weth;
    IOracleW public immutable rssOracle; // Morpho RSS→USDC 1e36
    IOracleW public immutable wethOracle; // Morpho WETH→USDC 1e36
    address public immutable king;
    address public wethSink; // raid chassis or hot — receives filled WETH

    uint256 public sweetenerBps; // max 2000 = +20%
    uint256 public rssEscrow;
    uint256 public wethRaised;
    uint256 public rssSold;
    bool public paused;

    event EscrowDeposited(uint256 amt);
    event EscrowWithdrawn(uint256 amt);
    event SinkSet(address indexed sink);
    event Params(uint256 sweetenerBps);
    event Paused(bool paused);
    event Filled(address indexed filler, uint256 wethIn, uint256 rssOut, address sink);

    error KingOnly();
    error Zero();
    error PausedErr();
    error Escrow();
    error SinkMiss();
    error Elepan();

    modifier onlyKing() {
        if (msg.sender != king) revert KingOnly();
        _;
    }

    constructor(
        address rss_,
        address weth_,
        address rssOracle_,
        address wethOracle_,
        address king_,
        address wethSink_,
        uint256 sweetenerBps_
    ) {
        if (rss_ == ELEPAN) revert Elepan();
        require(rss_ != address(0) && weth_ != address(0), "TOK");
        require(rssOracle_ != address(0) && wethOracle_ != address(0), "OR");
        require(king_ != address(0) && wethSink_ != address(0), "ADDR");
        require(sweetenerBps_ <= 2_000, "SWEET");
        rss = IERC20W(rss_);
        weth = IERC20W(weth_);
        rssOracle = IOracleW(rssOracle_);
        wethOracle = IOracleW(wethOracle_);
        king = king_;
        wethSink = wethSink_;
        sweetenerBps = sweetenerBps_;
        emit SinkSet(wethSink_);
        emit Params(sweetenerBps_);
    }

    function setSink(address sink_) external onlyKing {
        if (sink_ == address(0)) revert Zero();
        wethSink = sink_;
        emit SinkSet(sink_);
    }

    function setSweetener(uint256 sweetenerBps_) external onlyKing {
        require(sweetenerBps_ <= 2_000, "SWEET");
        sweetenerBps = sweetenerBps_;
        emit Params(sweetenerBps_);
    }

    function setPaused(bool p) external onlyKing {
        paused = p;
        emit Paused(p);
    }

    function depositRss(uint256 amt) external onlyKing {
        if (amt == 0) revert Zero();
        require(rss.transferFrom(msg.sender, address(this), amt), "RSS");
        rssEscrow += amt;
        emit EscrowDeposited(amt);
    }

    function withdrawRss(uint256 amt) external onlyKing {
        if (amt == 0 || amt > rssEscrow) revert Escrow();
        rssEscrow -= amt;
        require(rss.transfer(king, amt), "PUSH");
        emit EscrowWithdrawn(amt);
    }

    /// @notice Fair RSS out for `wethIn` at oracle par, plus sweetener.
    function quoteRssOut(uint256 wethIn) public view returns (uint256) {
        if (wethIn == 0) return 0;
        uint256 wethUsd6 = wethIn * wethOracle.price() / ORACLE_PRICE_SCALE;
        uint256 rssPx = rssOracle.price();
        if (rssPx == 0) return 0;
        uint256 baseRss = wethUsd6 * ORACLE_PRICE_SCALE / rssPx;
        return baseRss + (baseRss * sweetenerBps) / BPS;
    }

    /// @notice ANYONE: pay WETH → sink, receive RSS from escrow (+ sweetener).
    function fill(uint256 wethIn) external returns (uint256 rssOut) {
        if (paused) revert PausedErr();
        if (wethIn == 0) revert Zero();
        rssOut = quoteRssOut(wethIn);
        if (rssOut == 0 || rssOut > rssEscrow) revert Escrow();

        address sink = wethSink;
        if (sink == address(0)) revert SinkMiss();

        uint256 before = weth.balanceOf(sink);
        require(weth.transferFrom(msg.sender, sink, wethIn), "WETH");
        if (weth.balanceOf(sink) < before + wethIn) revert SinkMiss();

        rssEscrow -= rssOut;
        rssSold += rssOut;
        wethRaised += wethIn;
        require(rss.transfer(msg.sender, rssOut), "RSS");
        emit Filled(msg.sender, wethIn, rssOut, sink);
    }
}
