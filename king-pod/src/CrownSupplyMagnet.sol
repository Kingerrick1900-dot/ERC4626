// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice ENGINEER 3 — King book. USDC suppliers chase RSS rebate. King borrows vs RSS @ Fixed $1.
/// @dev Creates the loan book with token-as-capital incentive. No Morpho idle wait.
contract CrownSupplyMagnet is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable king;

    uint256 public priceUsdcPerRss = 1e6; // Fixed $1
    uint256 public lltv = 700000000000000000; // 70%
    /// @notice RSS paid per 1e6 USDC deposited (rebate bait). e.g. 0.05e18 = 0.05 RSS per $1
    uint256 public rebateRssPerUsdc;

    uint256 public totalSupplyUsdc;
    uint256 public totalCollRss;
    uint256 public kingDebtUsdc;
    uint256 public rebateBudgetRss;

    mapping(address => uint256) public supplyOf;

    event Armed(uint256 rebateRssPerUsdc, uint256 lltv);
    event StockedRebate(uint256 rssAmt);
    event Supplied(address indexed user, uint256 usdcIn, uint256 rssRebate);
    event WithdrawnSupply(address indexed user, uint256 usdcOut);
    event KingPosted(uint256 rssColl);
    event KingBorrowed(uint256 usdcOut);
    event KingRepaid(uint256 usdcIn);
    event KingUnposted(uint256 rssOut);

    error BadAmt();
    error Unsafe();
    error NotKing();
    error Insolvent();

    constructor(address usdc_, address rss_, address king_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
    }

    function arm(uint256 rebateRssPerUsdc_, uint256 lltv_) external onlyOwner {
        if (lltv_ == 0 || lltv_ > 1e18) revert BadAmt();
        rebateRssPerUsdc = rebateRssPerUsdc_;
        lltv = lltv_;
        emit Armed(rebateRssPerUsdc_, lltv_);
    }

    function stockRebate(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        rebateBudgetRss += rssAmt;
        emit StockedRebate(rssAmt);
    }

    /// @notice Deposit USDC → earn upfront RSS rebate (opportunity King created).
    function supply(uint256 usdcAmt) external nonReentrant {
        if (usdcAmt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        supplyOf[msg.sender] += usdcAmt;
        totalSupplyUsdc += usdcAmt;

        uint256 rebate = (usdcAmt * rebateRssPerUsdc) / 1e6;
        if (rebate > 0) {
            if (rebate > rebateBudgetRss) revert BadAmt();
            rebateBudgetRss -= rebate;
            rss.safeTransfer(msg.sender, rebate);
        }
        emit Supplied(msg.sender, usdcAmt, rebate);
    }

    function withdrawSupply(uint256 usdcAmt) external nonReentrant {
        if (usdcAmt == 0 || usdcAmt > supplyOf[msg.sender]) revert BadAmt();
        uint256 free = totalSupplyUsdc - kingDebtUsdc;
        if (usdcAmt > free) revert Insolvent();
        supplyOf[msg.sender] -= usdcAmt;
        totalSupplyUsdc -= usdcAmt;
        usdc.safeTransfer(msg.sender, usdcAmt);
        emit WithdrawnSupply(msg.sender, usdcAmt);
    }

    function postColl(uint256 rssAmt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        totalCollRss += rssAmt;
        emit KingPosted(rssAmt);
    }

    function borrow(uint256 usdcAmt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (usdcAmt == 0) revert BadAmt();
        kingDebtUsdc += usdcAmt;
        if (!_kingSafe()) revert Unsafe();
        if (usdcAmt > usdc.balanceOf(address(this))) revert Insolvent();
        usdc.safeTransfer(king, usdcAmt);
        emit KingBorrowed(usdcAmt);
    }

    function repay(uint256 usdcAmt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (usdcAmt == 0 || usdcAmt > kingDebtUsdc) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        kingDebtUsdc -= usdcAmt;
        emit KingRepaid(usdcAmt);
    }

    function unpostColl(uint256 rssAmt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (rssAmt == 0 || rssAmt > totalCollRss) revert BadAmt();
        totalCollRss -= rssAmt;
        if (!_kingSafe()) revert Unsafe();
        rss.safeTransfer(king, rssAmt);
        emit KingUnposted(rssAmt);
    }

    function maxBorrow() public view returns (uint256) {
        uint256 cap = (totalCollRss * priceUsdcPerRss / 1e18) * lltv / 1e18;
        if (kingDebtUsdc >= cap) return 0;
        uint256 room = cap - kingDebtUsdc;
        uint256 bal = usdc.balanceOf(address(this));
        // idle = bal is all USDC in vault; available to borrow = min(room, bal)
        // suppliers' claims = totalSupplyUsdc; already counted as liquidity
        return room < bal ? room : bal;
    }

    function _kingSafe() internal view returns (bool) {
        uint256 cap = (totalCollRss * priceUsdcPerRss / 1e18) * lltv / 1e18;
        return kingDebtUsdc <= cap;
    }
}
