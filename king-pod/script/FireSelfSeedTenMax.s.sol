// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSelfSeedTen} from "../src/CrownSelfSeedTen.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoS {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice KING_GO=1 FIRE_SELF_SEED_TEN_MAX=1 SEED_USDC=175000000000000
/// @dev Reuses live $10 oracle + TEN market. Does NOT deploy a new oracle.
contract FireSelfSeedTenMax is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant HELPER_LIVE = 0x4A39FAD3Fe149dE3445c9DfF29B1D703e4c9FFb2;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SELF_SEED_TEN_MAX", uint256(0)) == 1, "NEED FIRE_SELF_SEED_TEN_MAX=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 seed = vm.envOr("SEED_USDC", uint256(175_000_000e6));
        uint256 eleAmt = vm.envOr("ELE_AMT", uint256(0));

        // Cap seed to Morpho USDC balance minus $1M buffer
        uint256 morphoUsdc = IERC20S(USDC).balanceOf(MORPHO);
        uint256 maxSeed = morphoUsdc > 1_000_000e6 ? morphoUsdc - 1_000_000e6 : morphoUsdc / 2;
        if (seed > maxSeed) seed = maxSeed;

        console2.log("hotUsdcBefore", IERC20S(USDC).balanceOf(HOT));
        console2.log("hotEleBefore", IERC20S(ELE).balanceOf(HOT));
        console2.log("morphoUsdc", morphoUsdc);
        console2.log("seed", seed);

        CrownSelfSeedTen helper = CrownSelfSeedTen(vm.envOr("HELPER", HELPER_LIVE));
        require(address(helper).code.length > 0, "NO_HELPER");
        require(helper.king() == HOT, "HELPER_KING");
        require(helper.oracle() == ORACLE_10, "HELPER_ORACLE");

        vm.startBroadcast(pk);
        if (!IMorphoS(MORPHO).isAuthorized(HOT, address(helper))) {
            IMorphoS(MORPHO).setAuthorization(address(helper), true);
        }
        uint256 eleBal = IERC20S(ELE).balanceOf(HOT);
        if (eleAmt == 0 || eleAmt > eleBal) eleAmt = eleBal;
        require(eleAmt >= 1e8, "NEED_ELE");
        // Coll value @ $10 (ELE 8dp → USDC 6dp), then 91.5% LLTV
        uint256 collValue = (eleAmt * 10 * 1e6) / 1e8;
        uint256 maxBorrow = collValue * 915 / 1000;
        require(seed <= maxBorrow, "SEED_GT_LLTV");
        console2.log("maxBorrow", maxBorrow);

        IERC20S(ELE).approve(address(helper), eleAmt);
        helper.selfSeed(eleAmt, seed);
        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoS(MORPHO).market(TEN);
        (uint256 sup, uint128 bor, uint128 coll) = IMorphoS(MORPHO).position(TEN, HOT);
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("kingSupplyShares", sup);
        console2.log("kingBorrowShares", uint256(bor));
        console2.log("kingColl", uint256(coll));
        console2.log("hotUsdcAfter", IERC20S(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20S(ELE).balanceOf(HOT));
        console2.log("SELF_SEED_TEN_MAX_OK", uint256(1));
    }
}
