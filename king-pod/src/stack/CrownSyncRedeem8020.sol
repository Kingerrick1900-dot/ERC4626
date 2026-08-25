// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {IERC8020} from "./interfaces/IERC8020.sol";

interface IPsmRedeem2 {
    function redeemUsdc(uint256 eusdAmt, address to) external returns (uint256 usdcOut);
    function usdcReserve() external view returns (uint256);
}

/// @title CrownSyncRedeem8020
/// @notice Synchronous redeem: eUSD → USDC in one tx when PSM has reserve. No 7540 queue.
contract CrownSyncRedeem8020 is IERC8020, Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public immutable gusd;
    IPsmRedeem2 public immutable psm;
    IERC20 public immutable usdc;

    event SyncRedeemed(address indexed owner, address indexed receiver, uint256 eusdIn, uint256 usdcOut);

    error BadAmt();
    error LiquidityMiss();

    constructor(address eusd_, address gusd_, address psm_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && psm_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        gusd = gusd_;
        psm = IPsmRedeem2(psm_);
        usdc = IERC20(usdc_);
    }

    function maxRedeemSync(address) public view returns (uint256) {
        return psm.usdcReserve() * 1e12;
    }

    function previewRedeemSync(uint256 assets) public view returns (uint256) {
        if (assets == 0 || assets > maxRedeemSync(address(0))) return 0;
        return assets / 1e12;
    }

    function redeemSync(uint256 assets, address receiver, address owner_)
        external
        nonReentrant
        returns (uint256 usdcOut)
    {
        if (assets == 0) revert BadAmt();
        if (receiver == address(0)) receiver = msg.sender;
        if (owner_ == address(0)) owner_ = msg.sender;
        if (assets > maxRedeemSync(owner_)) revert LiquidityMiss();

        eusd.safeTransferFrom(owner_, address(this), assets);
        eusd.safeApprove(address(psm), 0);
        eusd.safeApprove(address(psm), assets);
        usdcOut = psm.redeemUsdc(assets, address(this));
        if (usdcOut == 0) revert LiquidityMiss();
        usdc.safeTransfer(receiver, usdcOut);
        emit SyncRedeemed(owner_, receiver, assets, usdcOut);
    }
}
