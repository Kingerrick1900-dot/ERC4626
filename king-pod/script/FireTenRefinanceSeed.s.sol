// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20R {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoR {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice After desk wires USDC: repay TEN debt → withdraw matched supply = seed on hot.
/// @dev KING_GO=1 FIRE_TEN_REFANCE=1
///      Requires hot USDC ≥ king borrow on TEN (~$700k). Optional PULL_ELE=1 withdraws coll.
contract FireTenRefinanceSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_TEN_REFANCE", uint256(0)) == 1, "NEED FIRE_TEN_REFANCE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoR.MarketParams memory mp =
            IMorphoR.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);

        IMorphoR(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorphoR(MORPHO).position(TEN, HOT);
        (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorphoR(MORPHO).market(TEN);

        uint256 debt = bs == 0 ? 0 : (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        uint256 supplyAssets = ss == 0 ? 0 : (supShares * uint256(sa)) / uint256(ss);
        uint256 usdcBal = IERC20R(USDC).balanceOf(HOT);

        console2.log("debt", debt);
        console2.log("supplyAssets", supplyAssets);
        console2.log("coll", uint256(coll));
        console2.log("hotUsdc", usdcBal);
        require(borShares > 0, "NO_DEBT");
        // Wire must cover debt; repay-by-shares avoids asset-rounding panic
        require(usdcBal >= debt, "NEED_WIRE_USDC_FOR_DEBT");

        vm.startBroadcast(pk);
        IERC20R(USDC).approve(MORPHO, type(uint256).max);
        IMorphoR(MORPHO).repay(mp, 0, borShares, HOT, "");

        // After repay, idle ≥ prior supply — withdraw king's supply to hot (the seed)
        (supShares,,) = IMorphoR(MORPHO).position(TEN, HOT);
        if (supShares > 0) {
            IMorphoR(MORPHO).withdraw(mp, 0, supShares, HOT, HOT);
        }

        if (vm.envOr("PULL_ELE", uint256(0)) == 1) {
            (,, coll) = IMorphoR(MORPHO).position(TEN, HOT);
            if (coll > 0) IMorphoR(MORPHO).withdrawCollateral(mp, uint256(coll), HOT, HOT);
        }
        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20R(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20R(ELE).balanceOf(HOT));
        console2.log("TEN_REFANCE_SEED_OK", uint256(1));
    }
}
