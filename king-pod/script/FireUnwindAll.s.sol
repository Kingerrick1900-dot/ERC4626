// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownForceShareUsdc} from "../src/CrownForceShareUsdc.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
}

/// @notice KING_GO=1 FIRE_UNWIND_ALL=1 — flash-close TEN + ELE77, pull ELE to hot.
/// @dev Matched books ⇒ hot USDC Δ ≈ 0. Recovers ELE. Dust debt cleared from hot USDC.
contract FireUnwindAll is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_77 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant FORCE_HELPER = 0x2D7C6966932e586fa65a2BC43a53F770Fe73C0a6;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_UNWIND_ALL", uint256(0)) == 1, "NEED FIRE_UNWIND_ALL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        console2.log("hotUsdcBefore", IERC20U(USDC).balanceOf(HOT));
        console2.log("hotEleBefore", IERC20U(ELE).balanceOf(HOT));

        CrownForceShareUsdc helper = CrownForceShareUsdc(FORCE_HELPER);
        require(address(helper).code.length > 0, "NO_HELPER");

        IMorphoU.MarketParams memory mpTen =
            IMorphoU.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMorphoU.MarketParams memory mp77 =
            IMorphoU.MarketParams(USDC, ELE, ORACLE_77, IRM, LLTV_77);

        vm.startBroadcast(pk);
        if (!IMorphoU(MORPHO).isAuthorized(HOT, address(helper))) {
            IMorphoU(MORPHO).setAuthorization(address(helper), true);
        }

        _forceClose(helper, mpTen, TEN, LLTV_915, ORACLE_10);
        _forceClose(helper, mp77, ELE77, LLTV_77, ORACLE_77);

        IERC20U(USDC).approve(MORPHO, type(uint256).max);
        _sweepBook(mpTen, TEN);
        _sweepBook(mp77, ELE77);
        vm.stopBroadcast();

        console2.log("hotUsdcAfter", IERC20U(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20U(ELE).balanceOf(HOT));
        console2.log("UNWIND_ALL_OK", uint256(1));
    }

    function _forceClose(
        CrownForceShareUsdc helper,
        IMorphoU.MarketParams memory mp,
        bytes32 id,
        uint256 lltv,
        address oracle
    ) internal {
        IMorphoU(MORPHO).accrueInterest(mp);
        (uint256 sup, uint128 bor,) = IMorphoU(MORPHO).position(id, HOT);
        if (bor == 0 || sup == 0) return;

        (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorphoU(MORPHO).market(id);
        uint256 debt = (uint256(bor) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        uint256 supplyAssets = (sup * uint256(sa)) / uint256(ss);
        // Helper requires pulled >= flash; share rounding can short 1 wei — leave buffer.
        uint256 flash = debt < supplyAssets ? debt : supplyAssets;
        require(flash > 10, "FLASH_DUST");
        flash -= 10;

        console2.log("forceId", uint256(id) >> 192);
        console2.log("debt", debt);
        console2.log("flash", flash);

        helper.forceMorphoSupply(
            CrownForceShareUsdc.MarketParams(USDC, ELE, oracle, IRM, lltv), flash, HOT
        );
    }

    function _sweepBook(IMorphoU.MarketParams memory mp, bytes32 id) internal {
        IMorphoU(MORPHO).accrueInterest(mp);
        (uint256 sup, uint128 bor, uint128 coll) = IMorphoU(MORPHO).position(id, HOT);

        if (bor > 0) {
            (,, uint128 ba, uint128 bs,,) = IMorphoU(MORPHO).market(id);
            uint256 debt = (uint256(bor) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
            console2.log("dustDebt", debt);
            require(IERC20U(USDC).balanceOf(HOT) >= debt, "NEED_USDC_DUST");
            IMorphoU(MORPHO).repay(mp, 0, bor, HOT, "");
            (sup,, coll) = IMorphoU(MORPHO).position(id, HOT);
        }

        if (sup > 0) {
            (uint128 sa, uint128 ss,,,,) = IMorphoU(MORPHO).market(id);
            uint256 idle = uint256(sa); // borrow should be 0
            if (idle > 0) {
                IMorphoU(MORPHO).withdraw(mp, 0, sup, HOT, HOT);
            }
            (,, coll) = IMorphoU(MORPHO).position(id, HOT);
        }

        if (coll > 0) {
            console2.log("pullEle", uint256(coll));
            IMorphoU(MORPHO).withdrawCollateral(mp, uint256(coll), HOT, HOT);
        }
    }
}
