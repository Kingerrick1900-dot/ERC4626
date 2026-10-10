// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateKM {
    function isProven(address subject) external view returns (bool);
}

interface IBordersKM {
    function bordersSecure() external view returns (bool);
}

interface IFeeBook {
    function totalHarvestedUsdc() external view returns (uint256);
}

interface IArbBook {
    function totalArbUsdc() external view returns (uint256);
}

interface IChinaBook {
    function totalFeesUsdc() external view returns (uint256);
}

/// @notice Build 7 — Kill metric dashboard. Public on-chain weekly USDC fee score.
/// @dev Reads four Harvester lines. consecutiveFails >= 2 → nigeriaOnlyMode.
contract KillMetric is Ownable {
    uint256 public constant WEEK = 7 days;
    uint256 public constant TARGET_WEEK1 = 10_000e6; // $10K
    uint256 public constant TARGET_WEEK4 = 100_000e6; // $100K
    uint256 public constant FAIL_LIMIT = 2;

    IZkGateKM public immutable zkGate;
    IBordersKM public immutable attest;
    address public immutable king;

    // Registry — Builds 1–6d
    address public immutable sovereignRail; // 1
    address public immutable oracle; // 2
    address public immutable krt; // 3
    bytes32 public immutable marketId; // 4
    address public immutable nigeriaDesk; // 5
    address public immutable harvesterRemittance; // 6a
    address public immutable harvesterFees; // 6b
    address public immutable harvesterArb; // 6c
    address public immutable harvesterChina; // 6d
    address public immutable hot;

    uint256 public weekStart;
    uint256 public weekIndex; // 1-based
    uint256 public lastReportedTotal;
    uint256 public feesThisWeek;
    uint256 public consecutiveFails;
    uint256 public consecutiveGreen;
    bool public nigeriaOnlyMode;

    mapping(uint256 => uint256) public feesByWeek;
    mapping(uint256 => bool) public greenByWeek;

    event WeeklyReport(
        uint256 indexed week,
        uint256 feesThisWeek,
        uint256 target,
        bool green,
        uint256 consecutiveFails,
        bool nigeriaOnlyMode
    );

    error NotProven();
    error Borders();
    error Auth();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    struct Registry {
        address zkGate;
        address attest;
        address king;
        address hot;
        address sovereignRail;
        address oracle;
        address krt;
        bytes32 marketId;
        address nigeriaDesk;
        address harvesterRemittance;
        address harvesterFees;
        address harvesterArb;
        address harvesterChina;
        address owner;
    }

    constructor(Registry memory r) Ownable(r.owner) {
        require(
            r.zkGate != address(0) && r.attest != address(0) && r.king != address(0) && r.hot != address(0)
                && r.sovereignRail != address(0) && r.oracle != address(0) && r.krt != address(0)
                && r.nigeriaDesk != address(0) && r.harvesterRemittance != address(0)
                && r.harvesterFees != address(0) && r.harvesterArb != address(0)
                && r.harvesterChina != address(0),
            "ZERO"
        );
        zkGate = IZkGateKM(r.zkGate);
        attest = IBordersKM(r.attest);
        king = r.king;
        hot = r.hot;
        sovereignRail = r.sovereignRail;
        oracle = r.oracle;
        krt = r.krt;
        marketId = r.marketId;
        nigeriaDesk = r.nigeriaDesk;
        harvesterRemittance = r.harvesterRemittance;
        harvesterFees = r.harvesterFees;
        harvesterArb = r.harvesterArb;
        harvesterChina = r.harvesterChina;
        weekStart = block.timestamp;
        weekIndex = 1;
        nigeriaOnlyMode = false;
    }

    /// @notice Public target for current week (ramps week1 → week4).
    function currentTarget() public view returns (uint256) {
        if (weekIndex <= 1) return TARGET_WEEK1;
        if (weekIndex >= 4) return TARGET_WEEK4;
        // linear ramp weeks 2–3
        uint256 span = TARGET_WEEK4 - TARGET_WEEK1;
        return TARGET_WEEK1 + (span * (weekIndex - 1)) / 3;
    }

    /// @notice Sum lifetime USDC fees across four Harvester lines (view).
    function readAllLines()
        public
        view
        returns (uint256 remittance, uint256 fees, uint256 arb, uint256 china, uint256 total)
    {
        remittance = IFeeBook(harvesterRemittance).totalHarvestedUsdc();
        fees = IFeeBook(harvesterFees).totalHarvestedUsdc();
        arb = IArbBook(harvesterArb).totalArbUsdc();
        china = IChinaBook(harvesterChina).totalFeesUsdc();
        total = remittance + fees + arb + china;
    }

    /// @notice Snapshot weekly USDC fees from all four lines. Advances week when due.
    function reportWeeklyUSDC()
        external
        whenZk
        returns (uint256 week, uint256 fees, uint256 target, bool green, bool nigeriaOnly)
    {
        if (msg.sender != owner && msg.sender != king && msg.sender != hot) revert Auth();

        (, , , , uint256 lifetime) = readAllLines();
        // delta since last report = this week's incremental landings
        uint256 delta = lifetime > lastReportedTotal ? lifetime - lastReportedTotal : 0;
        feesThisWeek += delta;
        lastReportedTotal = lifetime;

        _rollIfNeeded();

        week = weekIndex;
        fees = feesThisWeek;
        target = currentTarget();
        green = feesThisWeek >= target;
        nigeriaOnly = nigeriaOnlyMode;
        emit WeeklyReport(week, fees, target, green, consecutiveFails, nigeriaOnlyMode);
    }

    function _rollIfNeeded() internal {
        if (block.timestamp < weekStart + WEEK) return;

        uint256 target = currentTarget();
        bool green = feesThisWeek >= target;
        greenByWeek[weekIndex] = green;
        feesByWeek[weekIndex] = feesThisWeek;

        if (green) {
            unchecked {
                ++consecutiveGreen;
            }
            consecutiveFails = 0;
            if (nigeriaOnlyMode && consecutiveGreen >= FAIL_LIMIT) {
                nigeriaOnlyMode = false;
            }
        } else {
            consecutiveGreen = 0;
            unchecked {
                ++consecutiveFails;
            }
            if (consecutiveFails >= FAIL_LIMIT) {
                nigeriaOnlyMode = true;
            }
        }

        uint256 elapsed = block.timestamp - weekStart;
        uint256 weeksPassed = elapsed / WEEK;
        weekStart += weeksPassed * WEEK;
        weekIndex += weeksPassed;
        feesThisWeek = 0;
    }

    /// @notice Public dashboard read — no auth.
    function status()
        external
        view
        returns (
            uint256 week,
            uint256 fees,
            uint256 target,
            bool green,
            uint256 fails,
            bool nigeriaOnly,
            uint256 remittance,
            uint256 amoFees,
            uint256 arb,
            uint256 china
        )
    {
        week = weekIndex;
        fees = feesThisWeek;
        target = currentTarget();
        green = feesThisWeek >= target;
        fails = consecutiveFails;
        nigeriaOnly = nigeriaOnlyMode;
        (remittance, amoFees, arb, china,) = readAllLines();
    }
}
