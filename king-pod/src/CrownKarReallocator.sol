// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {IKarPublicAllocator} from "./interfaces/IKarPublicAllocator.sol";

interface IMorphoR {
    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}

/// @title CrownKarReallocator
/// @notice On-chain tip of the Steakhouse/Gauntlet PA playbook for Kingdom vaults.
/// @dev Off-chain KAR watcher decides when; this module enforces killswitch + hot-only fire.
///      PublicAllocator is intra-vault only — cannot cross Steakhouse→ySYNTH without their maxIn.
contract CrownKarReallocator is Ownable, ReentrancyGuard {
    IKarPublicAllocator public immutable pa;
    IMorphoR public immutable morpho;
    address public immutable hot;

    address public vault; // ySYNTH-USDC (or other Kingdom MetaMorpho)
    bytes32 public targetMarketId;
    bool public killswitch; // true = refuse fire
    bool public armed;

    uint256 public minIdleThreshold; // USDC 6dp
    uint256 public maxUtilBps; // fire when util > this (default 9500)
    uint256 public totalPulled;
    uint256 public fireCount;

    mapping(bytes32 => bool) public marketBanned;
    mapping(bytes32 => uint16) public riskScore;
    uint16 public maxRiskScore = 7000;

    event Armed(bool on);
    event Killswitch(bool on);
    event VaultSet(address vault, bytes32 targetMarket);
    event MarketBanned(bytes32 indexed id, bool banned);
    event RiskScore(bytes32 indexed id, uint16 score);
    event Reallocated(address indexed vault, bytes32 indexed fromId, uint256 amount, bytes32 toId);
    event Skipped(bytes32 indexed id, string reason);

    error Auth();
    error Disarmed();
    error Killed();
    error Banned();
    error Risk();
    error Idle();
    error Util();
    error Bad();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(address pa_, address morpho_, address hot_, address owner_) Ownable(owner_) {
        pa = IKarPublicAllocator(pa_);
        morpho = IMorphoR(morpho_);
        hot = hot_;
        maxUtilBps = 9500;
        minIdleThreshold = 1_000e6;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setKillswitch(bool on) external onlyHot {
        killswitch = on;
        emit Killswitch(on);
    }

    function setVault(address vault_, bytes32 targetMarketId_) external onlyOwner {
        if (vault_ == address(0) || targetMarketId_ == bytes32(0)) revert Bad();
        vault = vault_;
        targetMarketId = targetMarketId_;
        emit VaultSet(vault_, targetMarketId_);
    }

    function setThresholds(uint256 minIdle, uint256 maxUtilBps_) external onlyOwner {
        minIdleThreshold = minIdle;
        maxUtilBps = maxUtilBps_;
    }

    function setMaxRiskScore(uint16 s) external onlyOwner {
        maxRiskScore = s;
    }

    function banMarket(bytes32 id, bool banned) external onlyHot {
        marketBanned[id] = banned;
        emit MarketBanned(id, banned);
    }

    function setRiskScore(bytes32 id, uint16 score) external onlyHot {
        riskScore[id] = score;
        emit RiskScore(id, score);
    }

    function marketUtilBps(bytes32 id) public view returns (uint256) {
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        if (supply == 0) return 0;
        return (uint256(borrow) * 10_000) / uint256(supply);
    }

    function marketIdle(bytes32 id) public view returns (uint256) {
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        return uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
    }

    /// @notice KAR watcher entry — pull idle from source markets into target via PublicAllocator.
    function fireReallocate(
        IKarPublicAllocator.Withdrawal[] calldata withdrawals,
        IKarPublicAllocator.MarketParams calldata supplyMarketParams
    ) external payable onlyHot nonReentrant {
        if (!armed) revert Disarmed();
        if (killswitch) revert Killed();
        if (vault == address(0)) revert Bad();

        bytes32 toId = keccak256(abi.encode(supplyMarketParams));
        if (toId != targetMarketId) revert Bad();

        uint256 util = marketUtilBps(targetMarketId);
        if (util < maxUtilBps) revert Util();

        uint256 pulled;
        for (uint256 i; i < withdrawals.length; ++i) {
            bytes32 fromId = keccak256(abi.encode(withdrawals[i].marketParams));
            if (marketBanned[fromId]) {
                emit Skipped(fromId, "banned");
                revert Banned();
            }
            if (riskScore[fromId] > maxRiskScore) {
                emit Skipped(fromId, "risk");
                revert Risk();
            }
            uint256 idle = marketIdle(fromId);
            if (idle < minIdleThreshold && withdrawals[i].amount >= 1e6) {
                emit Skipped(fromId, "idle");
                revert Idle();
            }
            pulled += withdrawals[i].amount;
        }

        uint256 feeAmt = pa.fee(vault);
        pa.reallocateTo{value: feeAmt}(vault, withdrawals, supplyMarketParams);

        totalPulled += pulled;
        unchecked {
            ++fireCount;
        }
        if (withdrawals.length > 0) {
            emit Reallocated(
                vault, keccak256(abi.encode(withdrawals[0].marketParams)), pulled, targetMarketId
            );
        }
    }

    receive() external payable {}
}
