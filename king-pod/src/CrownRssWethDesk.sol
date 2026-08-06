// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice GO-B step 1: loan WETH against RSS (loan, don't sell).
/// @dev Lender supplies WETH. King locks free RSS. King draws WETH.
///      Morpho RSS books are NOT touched. No DEX sale of RSS.

interface IERC20Desk {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoPriceDesk {
    function price() external view returns (uint256);
}

contract CrownRssWethDesk {
    IERC20Desk public immutable rss;
    IERC20Desk public immutable weth;
    IMorphoPriceDesk public immutable rssOracle; // Morpho-scale RSS→USDC
    IMorphoPriceDesk public immutable wethOracle; // Morpho-scale WETH→USDC

    address public king;
    address public lender;

    /// @notice Max LTV of WETH draw vs RSS collateral value (WAD).
    uint256 public ltvWad;
    uint256 public rssLocked;
    uint256 public wethDebt;

    event Funded(address indexed lender, uint256 wethIn);
    event Drawn(uint256 rssIn, uint256 wethOut, address indexed to);
    event Repaid(uint256 wethIn, uint256 rssOut);
    event LenderSet(address indexed lender);
    event Params(uint256 ltvWad);

    modifier onlyKing() {
        require(msg.sender == king, "KING");
        _;
    }

    constructor(
        address rss_,
        address weth_,
        address rssOracle_,
        address wethOracle_,
        address king_,
        uint256 ltvWad_
    ) {
        require(ltvWad_ > 0 && ltvWad_ <= 0.8e18, "LTV");
        rss = IERC20Desk(rss_);
        weth = IERC20Desk(weth_);
        rssOracle = IMorphoPriceDesk(rssOracle_);
        wethOracle = IMorphoPriceDesk(wethOracle_);
        king = king_;
        ltvWad = ltvWad_;
        emit Params(ltvWad_);
    }

    function rssValueUsd(uint256 amt) public view returns (uint256) {
        // Morpho: amt * price / 1e36 = USDC-6; bump to 18dp
        return amt * rssOracle.price() / 1e36 * 1e12;
    }

    function wethValueUsd(uint256 amt) public view returns (uint256) {
        return amt * wethOracle.price() / 1e36 * 1e12;
    }

    function maxDrawWeth() public view returns (uint256) {
        uint256 maxUsd = rssValueUsd(rssLocked) * ltvWad / 1e18;
        uint256 debtUsd = wethValueUsd(wethDebt);
        if (maxUsd <= debtUsd) return 0;
        uint256 roomUsd = maxUsd - debtUsd;
        // roomUsd (18dp) → WETH via oracle: weth = roomUsd_as_usdc6 * 1e36 / price / 1e12
        // usdc6 = roomUsd / 1e12; weth = usdc6 * 1e36 / price
        uint256 usdc6 = roomUsd / 1e12;
        uint256 px = wethOracle.price();
        if (px == 0) return 0;
        return usdc6 * 1e36 / px;
    }

    /// @notice Lender posts WETH inventory available to draw.
    function fund(uint256 wethIn) external {
        require(wethIn > 0, "AMT");
        if (lender == address(0)) lender = msg.sender;
        require(msg.sender == lender, "LENDER");
        require(weth.transferFrom(msg.sender, address(this), wethIn), "PULL");
        emit Funded(msg.sender, wethIn);
    }

    /// @notice King locks free RSS and draws WETH (loan, not sale).
    function draw(uint256 rssIn, uint256 wethOut, address to) external onlyKing {
        require(rssIn > 0 && wethOut > 0, "AMT");
        if (to == address(0)) to = king;
        require(rss.transferFrom(msg.sender, address(this), rssIn), "RSS");
        rssLocked += rssIn;
        wethDebt += wethOut;
        {
            uint256 maxUsd = rssValueUsd(rssLocked) * ltvWad / 1e18;
            require(wethValueUsd(wethDebt) <= maxUsd, "LTV");
        }
        require(weth.balanceOf(address(this)) >= wethOut, "INV");
        require(weth.transfer(to, wethOut), "PUSH");
        emit Drawn(rssIn, wethOut, to);
    }

    /// @notice Repay WETH debt; unlock RSS to king.
    function repay(uint256 wethIn, uint256 rssOut) external onlyKing {
        require(wethIn > 0 && wethIn <= wethDebt, "DEBT");
        require(rssOut <= rssLocked, "RSS");
        require(weth.transferFrom(msg.sender, address(this), wethIn), "PULL");
        wethDebt -= wethIn;
        rssLocked -= rssOut;
        if (rssLocked > 0) {
            uint256 maxUsd = rssValueUsd(rssLocked) * ltvWad / 1e18;
            require(wethValueUsd(wethDebt) <= maxUsd, "LTV");
        } else {
            require(wethDebt == 0, "DUST");
        }
        if (rssOut > 0) require(rss.transfer(king, rssOut), "PUSH");
        // repaid WETH accrues to lender inventory
        emit Repaid(wethIn, rssOut);
    }

    function lenderWithdraw(uint256 wethOut) external {
        require(msg.sender == lender, "LENDER");
        uint256 free = weth.balanceOf(address(this));
        require(wethOut <= free, "BAL");
        require(weth.transfer(lender, wethOut), "PUSH");
    }

    function setLtv(uint256 ltvWad_) external onlyKing {
        require(ltvWad_ > 0 && ltvWad_ <= 0.8e18, "LTV");
        ltvWad = ltvWad_;
        if (rssLocked > 0) {
            require(wethValueUsd(wethDebt) <= rssValueUsd(rssLocked) * ltvWad / 1e18, "LTV");
        }
        emit Params(ltvWad_);
    }
}
