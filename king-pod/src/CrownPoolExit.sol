// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoPE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory m, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @title CrownPoolExit
/// @notice Post-cap exit draw: borrow idle USDC from synth Morpho market against eUSD → HOT.
/// @dev Only works when market idle > 0. Loop-to-cap first; exit when depth leaves borrowable USDC.
contract CrownPoolExit is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoPE public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable hot;
    IMorphoPE.MarketParams public mp;
    bytes32 public immutable marketId;
    uint256 public totalBorrowed;

    event OpenBorrowed(uint256 usdcAmt, uint256 eusdColl);

    error Auth();
    error Bad();
    error Idle();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address hot_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoPE(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        hot = hot_;
        mp = IMorphoPE.MarketParams(usdc_, eusd_, oracle_, irm_, lltv_);
        marketId = keccak256(abi.encode(mp));
    }

    function idle() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice Borrow real idle USDC against eUSD collateral to HOT.
    function openBorrow(uint256 usdcAmt, uint256 eusdColl) external onlyHot nonReentrant {
        if (usdcAmt == 0 || eusdColl == 0) revert Bad();
        if (idle() < usdcAmt) revert Idle();
        eusd.safeTransferFrom(hot, address(this), eusdColl);
        eusd.approve(address(morpho), eusdColl);
        morpho.supplyCollateral(mp, eusdColl, hot, "");
        morpho.borrow(mp, usdcAmt, 0, hot, hot);
        totalBorrowed += usdcAmt;
        emit OpenBorrowed(usdcAmt, eusdColl);
    }
}
