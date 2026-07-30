// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Live Scroll Gold Parity PSM at 0x064489A287448674AA1dC6fb740d2F518CBA75dA
interface ICrownGoldParityPsm {
    function eusd() external view returns (address);
    function usdc() external view returns (address);
    function kxau() external view returns (address);
    function oracle() external view returns (address);
    function landing() external view returns (address);

    function redeemUsdc(uint256 eusdAmt, address to) external returns (uint256 usdcOut);
    function redeemKxau(uint256 eusdAmt, address to) external returns (uint256 kxauOut);
    function seedUsdc(uint256 amt) external;
    function seedKxau(uint256 amt) external;
    function usdcReserve() external view returns (uint256);
    function goldReserveUsd6() external view returns (uint256);
    function quoteKxau(uint256 eusdAmt) external view returns (uint256);
}
