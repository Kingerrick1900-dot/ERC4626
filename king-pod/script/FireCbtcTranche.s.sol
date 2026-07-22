// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface ISeeder {
    function flashSeed(address loan, address oracle, address irm, uint256 lltv, uint256 flashAmt, uint256 rssColl)
        external;
}

interface IERC20T {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IOracleT {
    function price() external view returns (uint256);
}

interface IMorphoT {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice HF-safe cbBTC depth tranche on live RSS/cbBTC Morpho market.
/// @dev KING_OK=1 FIRE_CBTC_TRANCHE=1 forge script … --broadcast
contract FireCbtcTranche is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORA_C = 0x7c60830200D14F7cDd020bd1c0Aa10d6F254bd0b;
    address constant SEEDER = 0x38bF10f1b62282F08f9fC97E2DB116DD2cBbf2F6;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant IDC = 0x88fb488074c9f9f3acaa5f84a2f4181bc371defa66ff4a9e42e1e5f0d563be0e;
    uint256 constant HF_TARGET = 1.56e18; // above 1.55 floor

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_CBTC_TRANCHE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 flashCbtc = vm.envOr("FLASH_CBTC", uint256(5e8)); // 5 cbBTC default
        uint256 px = IOracleT(ORA_C).price();
        uint256 rssColl = flashCbtc * HF_TARGET * 1e36 / (px * 1e18);
        console2.log("FLASH_CBTC", flashCbtc);
        console2.log("RSS_COLL", rssColl);
        console2.log("pxC", px);
        require(IERC20T(RSS).balanceOf(HOT) >= rssColl, "RSS_SHORT");

        vm.startBroadcast(pk);
        IERC20T(RSS).approve(SEEDER, rssColl);
        ISeeder(SEEDER).flashSeed(CBTC, ORA_C, IRM, LLTV, flashCbtc, rssColl);
        vm.stopBroadcast();

        (uint128 supply,, uint128 borrow,,,) = IMorphoT(MORPHO).market(IDC);
        console2.log("cbBTC supply", uint256(supply));
        console2.log("cbBTC borrow", uint256(borrow));
        (, uint128 bSh, uint128 coll) = IMorphoT(MORPHO).position(IDC, HOT);
        console2.log("pos borrowShares", uint256(bSh));
        console2.log("pos collateral", uint256(coll));
    }
}
