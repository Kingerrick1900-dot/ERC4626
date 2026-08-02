// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {CrownKusd} from "./CrownKusd.sol";

/// @notice ENGINEER 1 — Crown CDP. RSS in → mint kUSD @ Fixed $1. No Morpho idle.
/// @dev priceUsdcPerRss = 1e6 ($1). LLTV default 70%. King engineers credit from RSS.
contract CrownCdp is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    CrownKusd public immutable kusd;
    address public immutable king;

    uint256 public priceUsdcPerRss = 1e6; // Fixed $1
    uint256 public lltv = 700000000000000000; // 70%
    uint256 public totalColl;
    uint256 public totalDebt;

    mapping(address => uint256) public collOf;
    mapping(address => uint256) public debtOf;

    event Opened(address indexed user, uint256 coll, uint256 debt);
    event Deposited(address indexed user, uint256 coll);
    event Minted(address indexed user, uint256 debt);
    event Repaid(address indexed user, uint256 debt);
    event Withdrawn(address indexed user, uint256 coll);
    event Params(uint256 priceUsdcPerRss, uint256 lltv);

    error BadAmt();
    error Unsafe();
    error NotKing();

    constructor(address rss_, address kusd_, address king_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        kusd = CrownKusd(kusd_);
        king = king_;
    }

    function setParams(uint256 priceUsdcPerRss_, uint256 lltv_) external onlyOwner {
        if (priceUsdcPerRss_ == 0 || priceUsdcPerRss_ > 1e6) revert BadAmt();
        if (lltv_ == 0 || lltv_ > 1e18) revert BadAmt();
        priceUsdcPerRss = priceUsdcPerRss_;
        lltv = lltv_;
        emit Params(priceUsdcPerRss_, lltv_);
    }

    /// @notice Deposit RSS + mint kUSD in one shot (engineer open).
    function open(uint256 collAmt, uint256 mintAmt) external nonReentrant {
        if (collAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), collAmt);
        collOf[msg.sender] += collAmt;
        totalColl += collAmt;
        if (mintAmt > 0) _mint(msg.sender, mintAmt);
        if (!_safe(msg.sender)) revert Unsafe();
        emit Opened(msg.sender, collAmt, mintAmt);
    }

    function deposit(uint256 collAmt) external nonReentrant {
        if (collAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), collAmt);
        collOf[msg.sender] += collAmt;
        totalColl += collAmt;
        emit Deposited(msg.sender, collAmt);
    }

    function mint(uint256 mintAmt) external nonReentrant {
        _mint(msg.sender, mintAmt);
        if (!_safe(msg.sender)) revert Unsafe();
    }

    function repay(uint256 repayAmt) external nonReentrant {
        if (repayAmt == 0 || repayAmt > debtOf[msg.sender]) revert BadAmt();
        kusd.burn(msg.sender, repayAmt);
        debtOf[msg.sender] -= repayAmt;
        totalDebt -= repayAmt;
        emit Repaid(msg.sender, repayAmt);
    }

    function withdraw(uint256 collAmt) external nonReentrant {
        if (collAmt == 0 || collAmt > collOf[msg.sender]) revert BadAmt();
        collOf[msg.sender] -= collAmt;
        totalColl -= collAmt;
        if (!_safe(msg.sender)) revert Unsafe();
        rss.safeTransfer(msg.sender, collAmt);
        emit Withdrawn(msg.sender, collAmt);
    }

    /// @notice Max kUSD mintable for `user` at current Fixed $1 + LLTV.
    function maxMint(address user) public view returns (uint256) {
        uint256 maxDebt = _maxDebt(collOf[user]);
        uint256 d = debtOf[user];
        if (d >= maxDebt) return 0;
        return maxDebt - d;
    }

    function _maxDebt(uint256 coll) internal view returns (uint256) {
        // coll(1e18) * price(1e6) / 1e18 * lltv / 1e18
        return (coll * priceUsdcPerRss / 1e18) * lltv / 1e18;
    }

    function _safe(address user) internal view returns (bool) {
        return debtOf[user] <= _maxDebt(collOf[user]);
    }

    function _mint(address user, uint256 mintAmt) internal {
        if (mintAmt == 0) revert BadAmt();
        debtOf[user] += mintAmt;
        totalDebt += mintAmt;
        kusd.mint(user, mintAmt);
        emit Minted(user, mintAmt);
    }
}
