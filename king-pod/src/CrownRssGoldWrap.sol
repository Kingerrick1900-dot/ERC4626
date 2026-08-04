// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {CrownRssGold} from "./CrownRssGold.sol";

/// @notice Lock RSS → mint kRSSG (Elepan gold-receipt fork for RSS).
/// @dev Scale: 1e18 RSS → 1e8 kRSSG (18dp → 8dp). Burn kRSSG → unlock RSS 1:1 reverse.
contract CrownRssGoldWrap is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    CrownRssGold public immutable gold;

    event Wrapped(address indexed user, uint256 rssIn, uint256 goldOut);
    event Unwrapped(address indexed user, uint256 goldIn, uint256 rssOut);

    error BadAmt();

    constructor(address rss_, address gold_, address owner_) Ownable(owner_) {
        require(rss_ != address(0) && gold_ != address(0), "ZERO");
        rss = IERC20(rss_);
        gold = CrownRssGold(gold_);
    }

    /// @notice Lock `rssAmt` (18dp) → mint kRSSG to `to` (8dp).
    function wrap(uint256 rssAmt, address to) external nonReentrant {
        if (rssAmt < 1e10 || to == address(0)) revert BadAmt(); // dust floor for 18→8
        uint256 goldOut = rssAmt / 1e10; // 1e18 → 1e8
        if (goldOut == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        gold.mint(to, goldOut);
        emit Wrapped(msg.sender, rssAmt, goldOut);
    }

    /// @notice Burn caller's kRSSG → return RSS.
    function unwrap(uint256 goldAmt, address to) external nonReentrant {
        if (goldAmt == 0 || to == address(0)) revert BadAmt();
        uint256 rssOut = goldAmt * 1e10;
        gold.burnFrom(msg.sender, goldAmt);
        rss.safeTransfer(to, rssOut);
        emit Unwrapped(msg.sender, goldAmt, rssOut);
    }
}
