// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20O {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IDeepPullO {
    function seed(uint256 usdcAmt, uint256 eusdAmt, int24 tickLower, int24 tickUpper)
        external
        returns (uint256 tokenId);
    function minYrssShares() external view returns (uint256);
}

interface IEusdO {
    function isMinter(address) external view returns (bool);
}

interface IUniPoolO {
    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
    function tickSpacing() external view returns (int24);
}

/// @notice Phase 3: seed Ocean external USDC leg via live DeepPull. Requires AMO6 green + FIRE_OCEAN=1.
contract FireOceanExternalSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant DEEP = 0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;

    function run() external {
        require(vm.envOr("FIRE_OCEAN", uint256(0)) == 1, "FIRE_OCEAN");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 usdcBal = IERC20O(USDC).balanceOf(HOT);
        require(usdcBal > 0, "NO_USDC");
        require(IERC20O(YRSS).balanceOf(HOT) > 0, "NO_YRSS");
        require(IEusdO(EUSD).isMinter(DEEP), "DEEP_NOT_MINTER");

        int24 spacing = IUniPoolO(POOL).tickSpacing();
        int24 tickLower = (-887200 / spacing) * spacing;
        int24 tickUpper = (887200 / spacing) * spacing;

        uint256 usdcAmt = usdcBal;
        uint256 eusdAmt = usdcAmt * 1e12;

        vm.startBroadcast(pk);
        IERC20O(USDC).approve(DEEP, usdcAmt);
        uint256 tokenId = IDeepPullO(DEEP).seed(usdcAmt, eusdAmt, tickLower, tickUpper);
        vm.stopBroadcast();

        console2.log("tokenId", tokenId);
        console2.log("usdcSeeded", usdcAmt);
        console2.log("eusdMinted", eusdAmt);
        console2.log("poolUsdc", IERC20O(USDC).balanceOf(POOL));
        console2.log("MISSION Ocean external USDC leg seeded");
    }
}
