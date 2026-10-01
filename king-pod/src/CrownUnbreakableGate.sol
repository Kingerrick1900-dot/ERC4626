// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable} from "./lib/Core.sol";

interface IMorphoMkt {
    function market(bytes32 id)
        external
        view
        returns (uint128 totalSupplyAssets, uint128, uint128 totalBorrowAssets, uint128, uint128, uint128);
}

interface ILoopNative {
    function fires() external view returns (uint256);
    function totalFlashed() external view returns (uint256);
}

interface IExitNative {
    function inventory(address token) external view returns (uint256);
}

interface IYrssPeg {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

interface IPqGate {
    function activeDilithium() external view returns (bytes32);
}

interface IStarkGate {
    function lastStarkRoot() external view returns (bytes32);
    function lastBoundPayload() external view returns (bytes32);
}

/// @title CrownUnbreakableGate
/// @notice Contract-enforced sequence. No human gate. HOT still signs Loop/Exit txs;
///         every next phase reverts unless prior gate is on-chain true.
/// @dev Gate A = Morpho market depth > $2M. Gate B = confirmed HOT USDC gain > $500k from Exit.
///      Kill: yRSS depeg >5%, depth < $1M, or full util with depth < Gate A -> pause + rescue signal.
contract CrownUnbreakableGate is Ownable {
    uint256 public constant GATE_A_DEPTH = 2_000_000e6;
    uint256 public constant GATE_B_EXIT = 500_000e6;
    uint256 public constant KILL_DEPTH = 1_000_000e6;
    uint256 public constant DEPEG_BPS = 500;
    uint256 public constant BPS = 10_000;

    IMorphoMkt public immutable morpho;
    ILoopNative public immutable loop;
    IExitNative public immutable exitVault;
    IYrssPeg public immutable yrss;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable hot;
    bytes32 public immutable marketId;

    IPqGate public pq;
    IStarkGate public stark;
    address public aaveSleeve;

    bool public paused;
    bool public gateAPassed;
    bool public gateBPassed;
    uint256 public exitedUsdcToHot;
    uint256 public yrssBaselineAssetsPerShare;
    uint256 public flywheelLenderPaid;
    uint256 public flywheelBorrowerPaid;
    uint256 public scaleArmedTo;
    uint256 public lastDepth;
    uint256 public lastUtilBps;
    uint256 public lastPegBps;

    event GateA(uint256 depth, bool ok);
    event GateB(uint256 exitedUsdc, bool ok);
    event FlywheelPaid(address indexed to, uint256 eusdAmt, bool borrower);
    event ScaleArmed(uint256 maxFlashUsdc, bytes32 dilithium, bytes32 starkRoot);
    event Kill(string reason, uint256 depth, uint256 utilBps, uint256 pegBps);
    event RescueToAave(address sleeve, uint256 hotUsdcHint);
    event ArmorSet(address pq, address stark, address aave);
    event PegSnapshot(uint256 assetsPerShare);

    error GateAFail();
    error GateBFail();
    error Paused();
    error Auth();
    error Bad();
    error Pq();
    error Stark();
    error ScaleCap();
    error Inventory();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address loop_,
        address exit_,
        address yrss_,
        address usdc_,
        address eusd_,
        address hot_,
        bytes32 marketId_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoMkt(morpho_);
        loop = ILoopNative(loop_);
        exitVault = IExitNative(exit_);
        yrss = IYrssPeg(yrss_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        hot = hot_;
        marketId = marketId_;
        _snapshotPeg();
        refreshGateA();
    }

    function setArmor(address pq_, address stark_, address aave_) external onlyOwner {
        pq = IPqGate(pq_);
        stark = IStarkGate(stark_);
        aaveSleeve = aave_;
        emit ArmorSet(pq_, stark_, aave_);
    }

    function snapshotPeg() external onlyHot {
        _snapshotPeg();
    }

    function vaultDepth() public view returns (uint256) {
        (uint128 supply,,,,,) = morpho.market(marketId);
        return uint256(supply);
    }

    function utilBps() public view returns (uint256) {
        (uint128 supply,, uint128 borrow,,,) = morpho.market(marketId);
        if (supply == 0) return 0;
        return (uint256(borrow) * BPS) / uint256(supply);
    }

    function pegBps() public view returns (uint256) {
        if (yrssBaselineAssetsPerShare == 0) return BPS;
        uint256 cur = _assetsPerShare();
        if (cur >= yrssBaselineAssetsPerShare) return BPS;
        return (cur * BPS) / yrssBaselineAssetsPerShare;
    }

    function scoreboard()
        external
        view
        returns (
            uint256 depth,
            uint256 hotUsdc,
            uint256 hotEusd,
            uint256 util,
            uint256 peg,
            uint256 fires,
            uint256 flashed,
            bool a,
            bool b,
            bool killOn
        )
    {
        depth = vaultDepth();
        hotUsdc = usdc.balanceOf(hot);
        hotEusd = eusd.balanceOf(hot);
        util = utilBps();
        peg = pegBps();
        fires = loop.fires();
        flashed = loop.totalFlashed();
        a = depth > GATE_A_DEPTH;
        b = gateBPassed;
        killOn = paused;
    }

    /// @notice Refresh Gate A from live Morpho depth. Emits GateA.
    function refreshGateA() public returns (bool ok) {
        uint256 d = vaultDepth();
        lastDepth = d;
        lastUtilBps = utilBps();
        lastPegBps = pegBps();
        ok = d > GATE_A_DEPTH;
        gateAPassed = ok;
        emit GateA(d, ok);
    }

    /// @notice Phase check before Exit — Gate A + Exit USDC inventory > $500k. No human override.
    function assertCanExit() external returns (bool) {
        _checkKill();
        if (!refreshGateA()) revert GateAFail();
        uint256 inv = exitVault.inventory(address(usdc));
        if (inv <= GATE_B_EXIT) revert Inventory();
        return true;
    }

    /// @notice Confirm Exit produced > $500k USDC to HOT. Sets Gate B. Reverts otherwise.
    function confirmExit(uint256 baselineHotUsdc) external onlyHot returns (bool) {
        _checkKill();
        if (!refreshGateA()) revert GateAFail();
        uint256 now_ = usdc.balanceOf(hot);
        if (now_ <= baselineHotUsdc) revert GateBFail();
        uint256 gained = now_ - baselineHotUsdc;
        exitedUsdcToHot = gained;
        gateBPassed = gained > GATE_B_EXIT;
        emit GateB(gained, gateBPassed);
        if (!gateBPassed) revert GateBFail();
        return true;
    }

    /// @notice Phase check before flywheel pay.
    function assertCanFlywheel() external view returns (bool) {
        if (paused) revert Paused();
        if (!gateBPassed) revert GateBFail();
        return true;
    }

    /// @notice Fire 3 — record + allow eUSD boost accounting (actual transfer is HOT→recipient).
    function recordFlywheel(address to, uint256 eusdAmt, bool borrower) external onlyHot {
        _checkKill();
        if (!gateBPassed) revert GateBFail();
        if (to == address(0) || eusdAmt == 0) revert Bad();
        if (borrower) flywheelBorrowerPaid += eusdAmt;
        else flywheelLenderPaid += eusdAmt;
        emit FlywheelPaid(to, eusdAmt, borrower);
    }

    /// @notice Fire 4 arm — Dilithium + Stark bind required. Cap ≥ $10M.
    function armScale(uint256 maxFlashUsdc) external onlyHot {
        _checkKill();
        if (!gateBPassed) revert GateBFail();
        if (address(pq) == address(0) || pq.activeDilithium() == bytes32(0)) revert Pq();
        if (address(stark) == address(0) || stark.lastBoundPayload() == bytes32(0)) revert Stark();
        if (maxFlashUsdc < 10_000_000e6) revert Bad();
        scaleArmedTo = maxFlashUsdc;
        emit ScaleArmed(maxFlashUsdc, pq.activeDilithium(), stark.lastStarkRoot());
    }

    /// @notice Phase check before $10M/$50M/$200M scale fires.
    function assertCanScale(uint256 flashUsdc) external view returns (bool) {
        if (paused) revert Paused();
        if (!gateBPassed) revert GateBFail();
        if (flashUsdc > scaleArmedTo) revert ScaleCap();
        if (address(pq) == address(0) || pq.activeDilithium() == bytes32(0)) revert Pq();
        return true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function _snapshotPeg() internal {
        yrssBaselineAssetsPerShare = _assetsPerShare();
        emit PegSnapshot(yrssBaselineAssetsPerShare);
    }

    function _assetsPerShare() internal view returns (uint256) {
        try yrss.convertToAssets(1e18) returns (uint256 a) {
            return a;
        } catch {
            uint256 ts = yrss.totalSupply();
            if (ts == 0) return 1e6;
            return (yrss.totalAssets() * 1e18) / ts;
        }
    }

    function _checkKill() internal {
        uint256 d = vaultDepth();
        uint256 u = utilBps();
        uint256 p = pegBps();
        lastDepth = d;
        lastUtilBps = u;
        lastPegBps = p;

        if (p + DEPEG_BPS < BPS) {
            paused = true;
            emit Kill("YRSS_DEPEG", d, u, p);
            emit RescueToAave(aaveSleeve, usdc.balanceOf(hot));
            revert Paused();
        }
        if (d < KILL_DEPTH) {
            paused = true;
            emit Kill("DEPTH_FLOOR", d, u, p);
            emit RescueToAave(aaveSleeve, usdc.balanceOf(hot));
            revert Paused();
        }
        // Self-seed util≈100% is normal; kill only if depth also below Gate A.
        if (u >= BPS && d < GATE_A_DEPTH) {
            paused = true;
            emit Kill("UTIL_DEPTH", d, u, p);
            emit RescueToAave(aaveSleeve, usdc.balanceOf(hot));
            revert Paused();
        }
    }
}
