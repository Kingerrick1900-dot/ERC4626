// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IEusdM {
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IGusdW {
    function wrap(uint256 amt, address to) external returns (uint256);
    function unwrap(uint256 amt, address to) external returns (uint256);
    function eusd() external view returns (address);
    function approve(address, uint256) external returns (bool);
}

interface IAeroRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

/// @title CrownOceanSeeder
/// @notice FAKE DEPTH the industry way: mint eUSD, wrap gUSD, LP both sides Aero. No Circle USDC.
contract CrownOceanSeeder is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IEusdM public immutable eusd;
    IGusdW public immutable gusd;
    IAeroRouter public immutable router;
    address public immutable king;
    address public landing;

    bool public armed = true;

    uint256 public totalMinted;
    uint256 public totalLpEusd;
    uint256 public totalLpGusd;
    uint256 public lastSeed;

    event Armed(bool on);
    event LandingSet(address landing);
    event OceanSeeded(uint256 eusdMinted, uint256 eusdLp, uint256 gusdLp, uint256 liquidity);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NotMinter();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address eusd_,
        address gusd_,
        address router_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        eusd = IEusdM(eusd_);
        gusd = IGusdW(gusd_);
        router = IAeroRouter(router_);
        king = king_;
        landing = landing_;
        IERC20(eusd_).safeApprove(gusd_, type(uint256).max);
        IERC20(eusd_).safeApprove(router_, type(uint256).max);
        IERC20(gusd_).safeApprove(router_, type(uint256).max);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    /// @notice Mint `2 * side` eUSD, wrap `side` to gUSD, LP equal sides into Aero stable pool.
    /// @param side Amount per side (18dp). 0 reverts.
    function seedOcean(uint256 side) external onlyKing nonReentrant returns (uint256 liquidity) {
        if (!armed) revert NotArmed();
        if (side == 0) revert BadAmt();
        if (!eusd.isMinter(address(this))) revert NotMinter();

        uint256 mintAmt = side * 2;
        eusd.mint(address(this), mintAmt);
        totalMinted += mintAmt;

        // wrap half → gUSD to this contract
        gusd.wrap(side, address(this));

        (uint256 a, uint256 b, uint256 liq) = router.addLiquidity(
            address(eusd),
            address(gusd),
            true,
            side,
            side,
            0,
            0,
            landing,
            block.timestamp + 600
        );
        liquidity = liq;
        totalLpEusd += a;
        totalLpGusd += b;
        lastSeed = side;
        emit OceanSeeded(mintAmt, a, b, liq);
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
