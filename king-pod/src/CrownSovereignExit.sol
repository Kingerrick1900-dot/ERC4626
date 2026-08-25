// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoExit {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

/// @title CrownSovereignExit
/// @notice Atomic sovereign AMO unwind: repay king debt → free RSS → recall Landing eUSD supply.
/// @dev King must approve eUSD for debt repay (borrowed eUSD on hot). Landing + king must authorize this on Morpho.
contract CrownSovereignExit is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoExit public immutable morpho;
    IERC20 public immutable eusd;
    IERC20 public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoExit.MarketParams public mp;

    uint256 public lastRepaid;
    uint256 public lastSupplyOut;
    uint256 public lastRssOut;

    event Exited(uint256 repaid, uint256 supplyToLanding, uint256 rssToKing);

    error OnlyKing();
    error RepayMiss();
    error SupplyMiss();
    error CollMiss();
    error OpenDebt();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert OnlyKing();
        _;
    }

    constructor(
        address morpho_,
        address eusd_,
        address rss_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoExit(morpho_);
        eusd = IERC20(eusd_);
        rss = IERC20(rss_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoExit.MarketParams({
            loanToken: eusd_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Full exit. Reverts if any leg leaves dust debt/coll/supply on book.
    function exitFull() external onlyKing nonReentrant {
        morpho.accrueInterest(mp);

        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        (uint256 supShares,,) = morpho.position(marketId, landing);

        uint256 repaid;
        if (borShares > 0) {
            uint256 kingBal = eusd.balanceOf(king);
            if (kingBal == 0) revert RepayMiss();
            eusd.safeTransferFrom(king, address(this), kingBal);
            eusd.approve(address(morpho), type(uint256).max);
            (repaid,) = morpho.repay(mp, 0, borShares, king, "");
            if (repaid == 0) revert RepayMiss();
            (, uint128 borAfter,) = morpho.position(marketId, king);
            if (borAfter > 0) revert OpenDebt();
        }

        uint256 rssBefore = rss.balanceOf(king);
        if (coll > 0) {
            morpho.withdrawCollateral(mp, coll, king, king);
            if (rss.balanceOf(king) < rssBefore + coll) revert CollMiss();
            lastRssOut = coll;
        }

        uint256 landBefore = eusd.balanceOf(landing);
        if (supShares > 0) {
            eusd.approve(address(morpho), type(uint256).max);
            morpho.withdraw(mp, 0, supShares, landing, landing);
            uint256 landDelta = eusd.balanceOf(landing) - landBefore;
            if (landDelta == 0) revert SupplyMiss();
            lastSupplyOut = landDelta;
        }

        uint256 dust = eusd.balanceOf(address(this));
        if (dust > 0) eusd.safeTransfer(king, dust);

        lastRepaid = repaid;
        emit Exited(repaid, lastSupplyOut, lastRssOut);
    }
}
