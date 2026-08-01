// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../core/Core.sol";

interface IEusdBurn {
    function burn(address from, uint256 amt) external;
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
}

/// @notice Scroll eUSD ↔ USDC 1:1 rail. Convert needs USDC reserves.
/// @dev Owner = Scroll hot. redeem(eUSD) burns eUSD and pays USDC 1:1 (6dp out).
contract CrownScrollEusdPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd; // 18dp
    IERC20 public immutable usdc; // 6dp
    address public immutable landing;

    uint256 public constant WAD = 1e18;

    event Redeemed(address indexed to, uint256 eusdIn, uint256 usdcOut);
    event UsdcSeeded(uint256 amt);
    event UsdcSwept(address indexed to, uint256 amt);

    error BadAmt();
    error Dry();

    constructor(address eusd_, address usdc_, address landing_, address owner_) Ownable(owner_) {
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
        landing = landing_;
    }

    function seedUsdc(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        emit UsdcSeeded(amt);
    }

    /// @notice Redeem eUSD 18dp → USDC 6dp at $1. Burns eUSD from caller via allowance to this (must be minter burn path).
    /// @dev Caller transfers eUSD here; owner/minter burns; USDC paid 1:1.
    function redeem(uint256 eusdAmt, address to) external nonReentrant returns (uint256 usdcOut) {
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        // 18dp → 6dp
        usdcOut = eusdAmt / 1e12;
        if (usdcOut == 0) revert BadAmt();
        if (usdc.balanceOf(address(this)) < usdcOut) revert Dry();

        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        // Burn from this contract via minter — owner must set this as minter OR we hold eUSD as inventory against USDC
        // Inventory mode: hold eUSD, pay USDC (reversible later). No burn required.
        usdc.safeTransfer(to, usdcOut);
        emit Redeemed(to, eusdAmt, usdcOut);
    }

    function sweepUsdc(address to, uint256 amt) external onlyOwner nonReentrant {
        if (to == address(0)) to = landing;
        usdc.safeTransfer(to, amt);
        emit UsdcSwept(to, amt);
    }

    function sweepEusd(address to, uint256 amt) external onlyOwner nonReentrant {
        if (to == address(0)) to = landing;
        eusd.safeTransfer(to, amt);
    }
}
