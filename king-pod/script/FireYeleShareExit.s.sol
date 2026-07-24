// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IVaultS {
    function balanceOf(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Exit $500k face of yELE shares from Landing for USDC (OTC / desk).
/// @dev Landing holds 100% of the $14M self-seed claim. Shares ARE the $14M.
///      Buyer sends USDC to Landing first (or atomic escrow). This script transfers shares.
///      KING_GO=1 FIRE_SHARE_EXIT=1
///      Mode A: BUYER already paid — transfer shares to BUYER
///      Mode B: quote only — print share amount for $500k
contract FireYeleShareExit is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant ASK = 500_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SHARE_EXIT", uint256(0)) == 1, "NEED FIRE_SHARE_EXIT=1");

        uint256 ask = vm.envOr("ASK_USDC", ASK);
        uint256 shares = IVaultS(YELE).convertToShares(ask);
        uint256 landShares = IVaultS(YELE).balanceOf(LANDING);
        require(shares > 0 && shares <= landShares, "SHARES");

        console2.log("askUsdc", ask);
        console2.log("sharesOut", shares);
        console2.log("previewAssets", IVaultS(YELE).previewRedeem(shares));
        console2.log("landingShares", landShares);

        address buyer = vm.envOr("BUYER", address(0));
        if (buyer == address(0)) {
            console2.log("QUOTE_ONLY", uint256(1));
            console2.log("Set BUYER=0x... after USDC received on Landing to transfer shares");
            return;
        }

        // Require Landing already received the USDC (buyer prepaid)
        uint256 minUsdc = vm.envOr("MIN_LANDING_USDC", ask);
        require(IERC20S(USDC).balanceOf(LANDING) >= minUsdc, "USDC_NOT_ON_LANDING");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        // Landing is EOA — hot must be Landing for transfer, or Landing signs
        require(vm.addr(pk) == LANDING, "NEED_LANDING_KEY");

        vm.startBroadcast(pk);
        require(IVaultS(YELE).transfer(buyer, shares), "XFER");
        vm.stopBroadcast();

        console2.log("SHARE_EXIT_OK", uint256(1));
        console2.log("buyer", buyer);
    }
}
