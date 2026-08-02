// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Y {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IVaultY {
    function balanceOf(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IEscrowY {
    function list(uint256 shares, uint256 usdcAsk) external;
}

/// @notice Extract value from yELE shares: transfer to buyer or list escrow for USDC→Landing.
/// @dev KING_GO=1 FIRE_YELE_SHARES=1
///      MODE=transfer requires TO=
///      MODE=escrow requires ESCROW= deployed CrownYeleShareEscrow
contract FireYeleShareExtract is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_YELE_SHARES", uint256(0)) == 1, "NEED FIRE_YELE_SHARES=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        // Landing holds shares; hot is owner/curator — transfer must be from Landing key OR hot if shares move to hot first.
        // Default: broadcast as HOT only if shares are on HOT; else require LANDING_KEY.
        string memory mode = vm.envOr("MODE", string("transfer"));
        uint256 face = vm.envOr("USDC_FACE", uint256(500_000e6));
        uint256 shares = IVaultY(YELE).convertToShares(face);
        uint256 landShares = IVaultY(YELE).balanceOf(LANDING);
        require(shares > 0 && shares <= landShares, "SHARES");

        if (_eq(mode, "transfer")) {
            address to = vm.envAddress("TO");
            require(to != address(0), "TO");
            uint256 lpk = vm.envUint("LANDING_KEY");
            require(vm.addr(lpk) == LANDING, "LANDING_KEY");
            vm.startBroadcast(lpk);
            require(IVaultY(YELE).transfer(to, shares), "XFER");
            vm.stopBroadcast();
            console2.log("transferredShares", shares);
            console2.log("to", to);
            console2.log("faceUsdc", face);
            console2.log("YELE_TRANSFER_OK", uint256(1));
        } else if (_eq(mode, "escrow")) {
            address escrow = vm.envAddress("ESCROW");
            uint256 lpk = vm.envUint("LANDING_KEY");
            require(vm.addr(lpk) == LANDING, "LANDING_KEY");
            vm.startBroadcast(lpk);
            IERC20Y(YELE).approve(escrow, shares);
            IEscrowY(escrow).list(shares, face);
            vm.stopBroadcast();
            console2.log("escrowedShares", shares);
            console2.log("usdcAsk", face);
            console2.log("YELE_ESCROW_OK", uint256(1));
        } else {
            revert("MODE");
        }

        console2.log("remainingLandingShares", IVaultY(YELE).balanceOf(LANDING));
        // silence unused
        pk;
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
