// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ICdp {
    function deposit(uint256 collAmt) external;
    function mint(uint256 mintAmt) external;
    function collOf(address) external view returns (uint256);
    function debtOf(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
}

interface IAdv {
    function stockKusd(uint256 amt) external;
    function kusdStock() external view returns (uint256);
}

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Maximize sovereign credit: more RSS into CDP -> more kUSD -> stock Advance.
/// @dev KING_OK=1 FIRE_MAXIMIZE=1  No buyer talk. RSS is the budget.
contract FireMaximizeSystem is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant CDP = 0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_MAXIMIZE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // Default: +4M RSS coll -> +2.8M kUSD @ 70%
        uint256 coll = vm.envOr("COLL_RSS", uint256(4_000_000 ether));
        uint256 free = IERC20M(RSS).balanceOf(HOT);
        if (coll > free) coll = free;
        require(coll > 0, "NO_RSS");

        uint256 mintAmt = vm.envOr("MINT_KUSD", uint256(0));
        if (mintAmt == 0) mintAmt = (coll * 700000) / 1e18;

        vm.startBroadcast(pk);
        IERC20M(RSS).approve(CDP, coll);
        ICdp(CDP).deposit(coll);
        ICdp(CDP).mint(mintAmt);

        uint256 kBal = IERC20M(KUSD).balanceOf(HOT);
        if (kBal > 0) {
            IERC20M(KUSD).approve(ADV, kBal);
            IAdv(ADV).stockKusd(kBal);
        }
        vm.stopBroadcast();

        console2.log("collAdded", coll);
        console2.log("minted", mintAmt);
        console2.log("collTotal", ICdp(CDP).collOf(HOT));
        console2.log("debtTotal", ICdp(CDP).debtOf(HOT));
        console2.log("advKusd", IAdv(ADV).kusdStock());
        console2.log("MAXIMIZE_OK", uint256(1));
    }
}
