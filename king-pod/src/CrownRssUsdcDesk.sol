// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Track 1: loan USDC against free RSS → Landing. No Morpho idle. No RSS sale.

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IOracleU {
    function price() external view returns (uint256);
}

contract CrownRssUsdcDesk {
    IERC20U public immutable rss;
    IERC20U public immutable usdc;
    IOracleU public immutable oracle; // Morpho RSS→USDC 1e36

    address public king;
    address public lender;
    address public landing;

    uint256 public ltvWad;
    uint256 public rssLocked;
    uint256 public usdcDebt;

    event Funded(address indexed lender, uint256 usdcIn);
    event Drawn(uint256 rssIn, uint256 usdcOut, address indexed to);
    event Repaid(uint256 usdcIn, uint256 rssOut);

    modifier onlyKing() {
        require(msg.sender == king, "KING");
        _;
    }

    constructor(address rss_, address usdc_, address oracle_, address king_, address landing_, uint256 ltvWad_) {
        require(ltvWad_ > 0 && ltvWad_ <= 0.77e18, "LTV");
        rss = IERC20U(rss_);
        usdc = IERC20U(usdc_);
        oracle = IOracleU(oracle_);
        king = king_;
        landing = landing_;
        ltvWad = ltvWad_;
    }

    function rssValueUsdc6(uint256 rssAmt) public view returns (uint256) {
        return rssAmt * oracle.price() / 1e36;
    }

    function maxDrawUsdc6() public view returns (uint256) {
        uint256 maxDebt = rssValueUsdc6(rssLocked) * ltvWad / 1e18;
        if (maxDebt <= usdcDebt) return 0;
        return maxDebt - usdcDebt;
    }

    function fund(uint256 usdcIn) external {
        require(usdcIn > 0, "AMT");
        if (lender == address(0)) lender = msg.sender;
        require(msg.sender == lender, "LENDER");
        require(usdc.transferFrom(msg.sender, address(this), usdcIn), "PULL");
        emit Funded(msg.sender, usdcIn);
    }

    /// @notice Lock RSS, send USDC to Landing (or `to`).
    function draw(uint256 rssIn, uint256 usdcOut, address to) external onlyKing {
        require(rssIn > 0 && usdcOut > 0, "AMT");
        if (to == address(0)) to = landing;
        require(rss.transferFrom(msg.sender, address(this), rssIn), "RSS");
        rssLocked += rssIn;
        usdcDebt += usdcOut;
        require(usdcDebt <= rssValueUsdc6(rssLocked) * ltvWad / 1e18, "LTV");
        require(usdc.balanceOf(address(this)) >= usdcOut, "INV");
        require(usdc.transfer(to, usdcOut), "PUSH");
        emit Drawn(rssIn, usdcOut, to);
    }

    function repay(uint256 usdcIn, uint256 rssOut) external onlyKing {
        require(usdcIn > 0 && usdcIn <= usdcDebt, "DEBT");
        require(rssOut <= rssLocked, "RSS");
        require(usdc.transferFrom(msg.sender, address(this), usdcIn), "PULL");
        usdcDebt -= usdcIn;
        rssLocked -= rssOut;
        if (rssLocked > 0) {
            require(usdcDebt <= rssValueUsdc6(rssLocked) * ltvWad / 1e18, "LTV");
        } else {
            require(usdcDebt == 0, "DUST");
        }
        if (rssOut > 0) require(rss.transfer(king, rssOut), "PUSH");
        emit Repaid(usdcIn, rssOut);
    }

    function lenderWithdraw(uint256 usdcOut) external {
        require(msg.sender == lender, "LENDER");
        require(usdcOut <= usdc.balanceOf(address(this)), "BAL");
        require(usdc.transfer(lender, usdcOut), "PUSH");
    }
}
