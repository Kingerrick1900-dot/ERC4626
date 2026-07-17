// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IDesk {
    function seed(uint256 usdcAmount) external;
}

interface IFlashCloser {
    function eliteFlashClose(uint256 rssCollateral, uint256 borrowUsdc, uint256 rssForFill) external;
}

/// @notice $700k vault fire with desk-only capital (Morpho rail flashed).
/// @dev Set FLASH_CLOSER after DeployEliteFlashClose. King needs >= $700k USDC (not $1.4M).
contract ScaleEliteFlash700k is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant DESK = 0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant B = 700_000e6;
    uint256 constant RSS_FILL = 14_000_000 ether;
    uint256 constant RSS_COLL = 18_200_000 ether;

    function run() external {
        address closer = vm.envAddress("FLASH_CLOSER");
        uint256 bal = IERC20(USDC).balanceOf(KING);
        require(bal >= B, "DESK_FUEL");

        vm.startBroadcast();
        IERC20(USDC).approve(DESK, B);
        IDesk(DESK).seed(B);
        IFlashCloser(closer).eliteFlashClose(RSS_COLL, B, RSS_FILL);
        vm.stopBroadcast();
        console2.log("flash-elite 700k fired - desk-only rail");
    }
}
