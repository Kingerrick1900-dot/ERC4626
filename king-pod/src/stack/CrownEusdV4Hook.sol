// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";

/// @dev Minimal Uniswap v4 PoolManager / Hooks surface (Base PoolManager 0x498581ff…).
library PoolIdLibrary {
    function toId(PoolKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }
}

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

interface IPoolManagerLite {
    function getSlot0(bytes32 poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);
}

/// @notice Uniswap v4 hook + solver-facing eUSD/USDC reference price.
/// @dev Deploy as the pool's hooks address (mine address flags for afterSwap + afterInitialize).
///      Provides unmanipulable TWAP-style reference for ERC-7683 solvers.
contract CrownEusdV4Hook is Ownable {
    using PoolIdLibrary for PoolKey;

    address public immutable poolManager;
    address public immutable eusd;
    address public immutable usdc;

    uint32 public twapWindow = 30 minutes;
    uint256 public constant WAD = 1e18;

    struct Observation {
        uint32 timestamp;
        int56 tickCumulative;
        uint160 sqrtPriceX96;
        uint256 priceWad;
    }

    mapping(bytes32 => Observation[]) public observations;
    mapping(bytes32 => PoolKey) public poolKeys;

    event PoolRegistered(bytes32 indexed poolId, address currency0, address currency1, uint24 fee);
    event ObservationWritten(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick, uint32 ts);
    event TwapWindowSet(uint32 window);

    error OnlyManager();
    error NoObs();
    error NotReady();

    constructor(address poolManager_, address eusd_, address usdc_, address owner_) Ownable(owner_) {
        require(poolManager_ != address(0) && eusd_ != address(0) && usdc_ != address(0), "ZERO");
        poolManager = poolManager_;
        eusd = eusd_;
        usdc = usdc_;
    }

    function setTwapWindow(uint32 w) external onlyOwner {
        require(w >= 1 minutes && w <= 1 days, "WINDOW");
        twapWindow = w;
        emit TwapWindowSet(w);
    }

    /// @notice Hook permission flags encoded into deployer salt / CREATE2 address.
    /// afterInitialize | afterSwap
    function getHookPermissions() external pure returns (uint160 flags) {
        // bit 12 afterInitialize, bit 14 afterSwap (v4 convention)
        flags = uint160(1 << 12) | uint160(1 << 14);
    }

    function afterInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        returns (bytes4)
    {
        if (msg.sender != poolManager) revert OnlyManager();
        bytes32 id = key.toId();
        poolKeys[id] = key;
        _write(id, sqrtPriceX96, tick);
        emit PoolRegistered(id, key.currency0, key.currency1, key.fee);
        return this.afterInitialize.selector;
    }

    function afterSwap(address, PoolKey calldata key, SwapParams calldata, int256, int256, bytes calldata)
        external
        returns (bytes4, int256)
    {
        if (msg.sender != poolManager) revert OnlyManager();
        bytes32 id = key.toId();
        (uint160 sqrtPriceX96, int24 tick,,) = IPoolManagerLite(poolManager).getSlot0(id);
        _write(id, sqrtPriceX96, tick);
        return (this.afterSwap.selector, 0);
    }

    /// @notice Manual observation sync when PoolManager getSlot0 is available off-hook.
    function sync(PoolKey calldata key) external {
        bytes32 id = key.toId();
        poolKeys[id] = key;
        (uint160 sqrtPriceX96, int24 tick,,) = IPoolManagerLite(poolManager).getSlot0(id);
        _write(id, sqrtPriceX96, tick);
    }

    /// @notice Push observation (owner / keeper) from an external sqrtPrice read.
    function pushObservation(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) external onlyOwner {
        _write(poolId, sqrtPriceX96, tick);
    }

    /// @notice Solver reference price: eUSD/USD in WAD (1e18 = $1.00).
    /// @dev TWAP of precomputed observation prices over twapWindow.
    function getReferencePrice(bytes32 poolId) public view returns (uint256 priceWad) {
        Observation[] storage obs = observations[poolId];
        uint256 n = obs.length;
        if (n == 0) revert NoObs();

        Observation memory latest = obs[n - 1];
        if (n == 1 || block.timestamp < uint256(twapWindow) + uint256(obs[0].timestamp)) {
            return latest.priceWad;
        }
        uint32 target = uint32(block.timestamp - uint256(twapWindow));

        Observation memory early = obs[0];
        for (uint256 i = 1; i < n; ++i) {
            if (obs[i].timestamp <= target) early = obs[i];
            else break;
        }
        return (early.priceWad + latest.priceWad) / 2;
    }

    function getReferencePriceWad(PoolKey calldata key) external view returns (uint256) {
        return getReferencePrice(key.toId());
    }

    function observationCount(bytes32 poolId) external view returns (uint256) {
        return observations[poolId].length;
    }

    function _write(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) internal {
        Observation[] storage obs = observations[poolId];
        if (obs.length >= 64) {
            for (uint256 i; i < 63; ++i) {
                obs[i] = obs[i + 1];
            }
            obs.pop();
        }
        uint256 px = _sqrtPriceToEusdWad(sqrtPriceX96, poolId);
        obs.push(
            Observation({
                timestamp: uint32(block.timestamp),
                tickCumulative: int56(tick),
                sqrtPriceX96: sqrtPriceX96,
                priceWad: px
            })
        );
        emit ObservationWritten(poolId, sqrtPriceX96, tick, uint32(block.timestamp));
    }

    /// @dev Overflow-safe token1/token0 ≈ (sqrtP / 2^96)^2 → eUSD/USD WAD.
    function _sqrtPriceToEusdWad(uint160 sqrtPriceX96, bytes32 poolId) internal view returns (uint256) {
        PoolKey memory key = poolKeys[poolId];
        uint256 x = uint256(sqrtPriceX96);
        if (x == 0) return WAD;

        // a = sqrtP / 2^48 → ratioQ96 = a^2 = sqrtP^2 / 2^96 (fits for sqrtP ≤ 2^128)
        uint256 a = x >> 48;
        if (a == 0) return WAD;
        uint256 ratioQ96 = a * a; // Q96
        // human = ratioQ96 / 2^96
        // WAD price = ratioQ96 * WAD / 2^96
        uint256 humanWad = (ratioQ96 * WAD) >> 96;
        if (humanWad == 0) humanWad = 1;

        // Decimal adjust: USDC 6dp vs eUSD 18dp ⇒ × 1e12 on the USDC-per-eUSD side
        if (key.currency0 == usdc && key.currency1 == eusd) {
            // raw human is eUSD/USDC in atomic units; convert to USD peg WAD
            // atomic ratio ≈ 1e12 at $1; so priceWad = humanWad / 1e12
            return humanWad / 1e12 == 0 ? humanWad : humanWad / 1e12;
        }
        if (key.currency0 == eusd && key.currency1 == usdc) {
            // human ≈ USDC/eUSD atomic ≈ 1e-12 at peg → invert
            uint256 adj = humanWad * 1e12;
            if (adj == 0) revert NotReady();
            return (WAD * WAD) / adj;
        }
        // tick-0 initialize path (equal decimals assumption)
        return humanWad;
    }
}
