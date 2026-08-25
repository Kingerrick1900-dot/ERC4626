// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {IERC8020} from "./interfaces/IERC8020.sol";

interface IPsm8020 {
    function redeemUsdc(uint256 eusdAmt) external returns (uint256 usdcOut);
    function usdcReserve() external view returns (uint256);
}

/// @title CrownSyncRedeem8020
/// @notice Synchronous redeem rail: gUSD/eUSD → USDC in one tx when PSM has reserve.
/// @dev No 7540 queue. Reverts on liquidity miss (honest Fed: no fake async).
contract CrownSyncRedeem8020 is IERC8020, Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable gusd; // optional; address(0) = eUSD-only
    IPsm8020 public immutable psm;
    IERC20 public immutable usdc;

    event SyncRedeemed(address indexed owner, address indexed receiver, uint256 eusdIn, uint256 usdcOut);

    error BadAmt();
    error LiquidityMiss();
    error BadToken();

    constructor(address eusd_, address gusd_, address psm_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && psm_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        gusd = IERC20(gusd_);
        psm = IPsm8020(psm_);
        usdc = IERC20(usdc_);
    }

    function maxRedeemSync(address) public view returns (uint256) {
        // eUSD 18dp vs USDC 6dp: reserve * 1e12 = max eUSD at $1
        uint256 reserve = psm.usdcReserve();
        return reserve * 1e12;
    }

    function previewRedeemSync(uint256 assets) public view returns (uint256) {
        if (assets == 0) return 0;
        uint256 maxE = maxRedeemSync(address(0));
        if (assets > maxE) return 0;
        return assets / 1e12; // $1 peg → USDC 6dp
    }

    /// @notice Pull eUSD (or unwrap path via gUSD holder pre-unwrap), redeem sync via PSM.
    function redeemSync(uint256 assets, address receiver, address owner_) external nonReentrant returns (uint256 usdcOut) {
        if (assets == 0) revert BadAmt();
        if (receiver == address(0)) receiver = msg.sender;
        if (owner_ == address(0)) owner_ = msg.sender;
        if (assets > maxRedeemSync(owner_)) revert LiquidityMiss();

        eusd.safeTransferFrom(owner_, address(this), assets);
        eusd.safeApprove(address(psm), assets);
        usdcOut = psm.redeemUsdc(assets);
        if (usdcOut == 0) revert LiquidityMiss();
        usdc.safeTransfer(receiver, usdcOut);
        emit SyncRedeemed(owner_, receiver, assets, usdcOut);
    }
}
