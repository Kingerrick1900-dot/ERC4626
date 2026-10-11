// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateHA {
    function isProven(address subject) external view returns (bool);
}

interface IBordersHA {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 6c — Internal arb harvester. Kingdom pools only. No external MEV.
/// @dev Whitelist: RSS_KRT_BASE (Aerodrome) · RSS_KRT_POLYGON (QuickSwap) · RSS_KRT_SCROLL (SyncSwap).
contract HarvesterArb is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    bytes32 public constant RSS_KRT_BASE = keccak256("RSS_KRT_BASE");
    bytes32 public constant RSS_KRT_POLYGON = keccak256("RSS_KRT_POLYGON");
    bytes32 public constant RSS_KRT_SCROLL = keccak256("RSS_KRT_SCROLL");

    IERC20 public immutable usdc;
    IZkGateHA public immutable zkGate;
    IBordersHA public immutable attest;
    address public immutable king;
    address public immutable hot;

    mapping(address => bool) public kingdomPool;
    mapping(bytes32 => address) public labeledPool;
    mapping(address => bool) public bot;
    uint256 public totalArbUsdc;
    uint256 public arbCount;

    event PoolSet(bytes32 indexed label, address indexed pool, bool ok);
    event BotSet(address indexed bot, bool ok);
    event ArbHarvested(address indexed buyPool, address indexed sellPool, uint256 profitUsdc, bytes32 ref);

    error Auth();
    error Zero();
    error ExternalPool();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    constructor(
        address usdc_,
        address zkGate_,
        address attest_,
        address king_,
        address hot_,
        address poolBase_,
        address poolPolygon_,
        address poolScroll_,
        address owner_
    ) Ownable(owner_) {
        require(
            usdc_ != address(0) && zkGate_ != address(0) && attest_ != address(0) && king_ != address(0)
                && hot_ != address(0),
            "ZERO"
        );
        usdc = IERC20(usdc_);
        zkGate = IZkGateHA(zkGate_);
        attest = IBordersHA(attest_);
        king = king_;
        hot = hot_;
        bot[owner_] = true;
        bot[king_] = true;
        if (poolBase_ != address(0)) _setPool(RSS_KRT_BASE, poolBase_, true);
        if (poolPolygon_ != address(0)) _setPool(RSS_KRT_POLYGON, poolPolygon_, true);
        if (poolScroll_ != address(0)) _setPool(RSS_KRT_SCROLL, poolScroll_, true);
    }

    function isKingdomPool(address pool) public view returns (bool) {
        return kingdomPool[pool];
    }

    function setBot(address b, bool ok) external onlyOwner {
        bot[b] = ok;
        emit BotSet(b, ok);
    }

    function setKingdomPool(bytes32 label, address pool, bool ok) external onlyOwner {
        _setPool(label, pool, ok);
    }

    function _setPool(bytes32 label, address pool, bool ok) internal {
        if (pool == address(0)) revert Zero();
        address prev = labeledPool[label];
        if (prev != address(0) && prev != pool) kingdomPool[prev] = false;
        labeledPool[label] = ok ? pool : address(0);
        kingdomPool[pool] = ok;
        emit PoolSet(label, pool, ok);
    }

    /// @notice Book arb profit between two Kingdom pools only → USDC to HOT.
    function harvestArb(address buyPool, address sellPool, uint256 profitUsdc, bytes32 ref)
        external
        onlyBot
        nonReentrant
        whenZk
    {
        if (profitUsdc == 0) revert Zero();
        if (!isKingdomPool(buyPool) || !isKingdomPool(sellPool)) revert ExternalPool();
        usdc.safeTransferFrom(msg.sender, hot, profitUsdc);
        totalArbUsdc += profitUsdc;
        unchecked {
            ++arbCount;
        }
        emit ArbHarvested(buyPool, sellPool, profitUsdc, ref);
    }
}
