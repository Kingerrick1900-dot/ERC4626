// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownCircuitBreaker — real on-chain kill switch
/// @notice Replaces HuntRouter theater. Auto-pauses all AMOs on trigger.
/// Trigger: eUSD < $0.98 OR yRSS collateral drop > 5%
/// Action: pause all AMOs, route capital to Aave safe venue.

interface IAMOPausable {
    function emergencyPause() external;
}

interface ISafeRouter {
    function routeToSafeVenue(uint256 amount) external;
}

contract CrownCircuitBreaker {
    address public king;
    bool public armed = true;
    bool public tripped;

    uint256 public constant EUSD_FLOOR = 0.98e18; // $0.98
    uint256 public constant YRSS_DROP_BPS = 500; // 5%

    address[] public amos;
    ISafeRouter public safeRouter;

    uint256 public yRssBaseline;

    event AmoRegistered(address indexed amo);
    event Tripped(string reason, uint256 timestamp);
    event Routed(uint256 amount, uint256 timestamp);
    event Reset(uint256 timestamp);
    event Armed(bool armed);

    error KingOnly();
    error NotArmed();
    error AlreadyTripped();
    error NotTripped();

    modifier onlyKing() {
        if (msg.sender != king) revert KingOnly();
        _;
    }

    constructor(address king_, address safeRouter_, uint256 yRssBaseline_) {
        require(king_ != address(0), "ZERO");
        king = king_;
        safeRouter = ISafeRouter(safeRouter_);
        yRssBaseline = yRssBaseline_;
    }

    function registerAMO(address amo) external onlyKing {
        require(amo != address(0), "ZERO");
        amos.push(amo);
        emit AmoRegistered(amo);
    }

    function amoCount() external view returns (uint256) {
        return amos.length;
    }

    /// @notice Keeper/agent: fresh oracle reads. Trips once; pauses every registered AMO.
    /// @param eusdPrice eUSD/USD, 1e18 = $1.00
    /// @param yRssAssets current yRSS.totalAssets()
    function checkAndTrip(uint256 eusdPrice, uint256 yRssAssets) external {
        if (!armed) revert NotArmed();
        if (tripped) revert AlreadyTripped();
        bool priceTrip = eusdPrice < EUSD_FLOOR;
        bool collatTrip = yRssBaseline > 0 && yRssAssets * 10_000 < yRssBaseline * (10_000 - YRSS_DROP_BPS);
        if (!(priceTrip || collatTrip)) return;

        tripped = true;
        uint256 n = amos.length;
        for (uint256 i; i < n; i++) {
            IAMOPausable(amos[i]).emergencyPause();
        }
        emit Tripped(priceTrip ? "eUSD<0.98" : "yRSS drop>5%", block.timestamp);
    }

    /// @notice After trip: push capital through safe router (Aave venue). Amount from caller context.
    function routeToSafe(uint256 amount) external onlyKing {
        if (!tripped) revert NotTripped();
        require(address(safeRouter) != address(0), "NO_ROUTER");
        safeRouter.routeToSafeVenue(amount);
        emit Routed(amount, block.timestamp);
    }

    function reset(uint256 newBaseline) external onlyKing {
        tripped = false;
        yRssBaseline = newBaseline;
        emit Reset(block.timestamp);
    }

    function setArmed(bool armed_) external onlyKing {
        armed = armed_;
        emit Armed(armed_);
    }

    function setSafeRouter(address r) external onlyKing {
        safeRouter = ISafeRouter(r);
    }

    function setBaseline(uint256 b) external onlyKing {
        yRssBaseline = b;
    }
}
