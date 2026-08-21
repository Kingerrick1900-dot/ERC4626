// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Parallel rail: loan WETH against RSS (loan, don't sell). Lender funds WETH; king draws.
/// @dev Same shape as GO-B CrownRssWethDesk — engineer 351 WETH inventory without DEX dump.

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
    IMorphoPriceDesk public immutable rssOracle;
    IMorphoPriceDesk public immutable wethOracle;

    address public king;
    address public lender;

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
        uint256 usdc6 = roomUsd / 1e12;
        uint256 px = wethOracle.price();
        if (px == 0) return 0;
        return usdc6 * 1e36 / px;
    }

    function fund(uint256 wethIn) external {
        require(wethIn > 0, "AMT");
        if (lender == address(0)) {
            lender = msg.sender;
            emit LenderSet(msg.sender);
        }
        require(msg.sender == lender, "LENDER");
        require(weth.transferFrom(msg.sender, address(this), wethIn), "PULL");
        emit Funded(msg.sender, wethIn);
    }

    function draw(uint256 rssIn, uint256 wethOut, address to) external onlyKing {
        require(rssIn > 0 && wethOut > 0, "AMT");
        if (to == address(0)) to = king;
        require(rss.transferFrom(msg.sender, address(this), rssIn), "RSS");
        rssLocked += rssIn;
        wethDebt += wethOut;
        require(wethValueUsd(wethDebt) <= rssValueUsd(rssLocked) * ltvWad / 1e18, "LTV");
        require(weth.balanceOf(address(this)) >= wethOut, "INV");
        require(weth.transfer(to, wethOut), "PUSH");
        emit Drawn(rssIn, wethOut, to);
    }

    function repay(uint256 wethIn, uint256 rssOut) external onlyKing {
        require(wethIn > 0 && wethIn <= wethDebt, "DEBT");
        require(rssOut <= rssLocked, "RSS");
        require(weth.transferFrom(msg.sender, address(this), wethIn), "PULL");
        wethDebt -= wethIn;
        rssLocked -= rssOut;
        if (rssLocked > 0) {
            require(wethValueUsd(wethDebt) <= rssValueUsd(rssLocked) * ltvWad / 1e18, "LTV");
        } else {
            require(wethDebt == 0, "DUST");
        }
        if (rssOut > 0) require(rss.transfer(king, rssOut), "PUSH");
        emit Repaid(wethIn, rssOut);
    }

    function lenderWithdraw(uint256 wethOut) external {
        require(msg.sender == lender, "LENDER");
        require(wethOut <= weth.balanceOf(address(this)), "BAL");
        require(weth.transfer(lender, wethOut), "PUSH");
    }
}
