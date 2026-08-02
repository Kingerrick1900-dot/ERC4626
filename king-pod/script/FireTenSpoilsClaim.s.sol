// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoC {
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

/// @notice SPOILS OF WAR — claim TEN $700k supply onto hot after USDC covers debt.
/// @dev KING_GO=1 FIRE_TEN_SPOILS=1
///      Wire path: hot USDC ≥ debt → repay-by-shares → withdraw supply → optional PULL_ELE=1
///      FREE_ELE=1 alone: withdraw excess ELE coll while keeping TEN debt healthy (no USDC claim).
contract FireTenSpoilsClaim is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant ORACLE_PRICE = 1e35; // $10 ELE scale

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_TEN_SPOILS", uint256(0)) == 1, "NEED FIRE_TEN_SPOILS=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoC.MarketParams memory mp =
            IMorphoC.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);

        IMorphoC(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorphoC(MORPHO).position(TEN, HOT);
        (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorphoC(MORPHO).market(TEN);

        uint256 debt = bs == 0 ? 0 : (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        uint256 supplyAssets = ss == 0 ? 0 : (supShares * uint256(sa)) / uint256(ss);
        uint256 usdcBal = IERC20C(USDC).balanceOf(HOT);

        console2.log("SPOIL_debt", debt);
        console2.log("SPOIL_supply", supplyAssets);
        console2.log("SPOIL_coll", uint256(coll));
        console2.log("hotUsdc", usdcBal);
        console2.log("LONG_LINE_THE_KING", uint256(1));

        bool freeEleOnly = vm.envOr("FREE_ELE", uint256(0)) == 1;
        bool claimUsdc = vm.envOr("CLAIM_USDC", uint256(1)) == 1;

        if (freeEleOnly && !claimUsdc) {
            // Keep 10x min coll for debt at $10 / 91.5%
            uint256 minColl = _minColl(debt);
            uint256 keep = minColl * 10;
            if (keep < minColl * 2) keep = minColl * 2;
            require(uint256(coll) > keep, "NO_FREE_ELE");
            uint256 freeAmt = uint256(coll) - keep;
            console2.log("freeEle", freeAmt);

            vm.startBroadcast(pk);
            IMorphoC(MORPHO).withdrawCollateral(mp, freeAmt, HOT, HOT);
            vm.stopBroadcast();

            console2.log("hotEleAfter", IERC20C(ELE).balanceOf(HOT));
            console2.log("TEN_SPOILS_FREE_ELE_OK", uint256(1));
            return;
        }

        require(borShares > 0, "NO_DEBT");
        require(usdcBal >= debt, "SPOIL_LOCKED_NEED_WIRE");

        vm.startBroadcast(pk);
        IERC20C(USDC).approve(MORPHO, type(uint256).max);
        IMorphoC(MORPHO).repay(mp, 0, borShares, HOT, "");

        (supShares,,) = IMorphoC(MORPHO).position(TEN, HOT);
        if (supShares > 0) {
            IMorphoC(MORPHO).withdraw(mp, 0, supShares, HOT, HOT);
        }

        if (vm.envOr("PULL_ELE", uint256(0)) == 1) {
            (,, coll) = IMorphoC(MORPHO).position(TEN, HOT);
            if (coll > 0) IMorphoC(MORPHO).withdrawCollateral(mp, uint256(coll), HOT, HOT);
        }
        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20C(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20C(ELE).balanceOf(HOT));
        console2.log("TEN_SPOILS_CLAIM_OK", uint256(1));
    }

    function _minColl(uint256 debt) internal pure returns (uint256) {
        if (debt == 0) return 0;
        // collValue = coll * price / 1e36; maxBorrow = collValue * lltv / 1e18
        // minColl = debt * 1e18 / lltv * 1e36 / price
        uint256 needValue = (debt * 1e18 + LLTV_915 - 1) / LLTV_915;
        return (needValue * 1e36 + ORACLE_PRICE - 1) / ORACLE_PRICE;
    }
}
