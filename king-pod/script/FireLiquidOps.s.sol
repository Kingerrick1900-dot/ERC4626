// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IPsmL {
    function sweep(address token, uint256 amount, address to) external;
    function owner() external view returns (address);
}

/// @notice Real liquid assets → cold. KING_GO=1 FIRE_LIQUID=1
/// @dev Hot-signed only. Landing USDC needs LANDING_KEY (optional). yELE-K shares need COLD_KEY to unlock.
contract FireLiquidOps is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant COLD = 0xd2511FFa5F720A3d0cB7D1C9b44A9539c42BDf41;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_150 = 0x088A80C2193de049c6E8DeD2CF371e1C4180Fe12;
    address constant ORACLE_100 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant PSM = 0x9199E5099C2C46A688F982E377a146Ab6db8060b;
    bytes32 constant ELE915 = 0x10586d9499c8cb93d571f2ddeb41be9b456faac1019c6ceb07ed4113df6d0162;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant LLTV_77 = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_LIQUID", uint256(0)) == 1, "NEED FIRE_LIQUID=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "HOT");

        // Optional: Landing → cold only if LANDING_KEY is the Landing wallet
        uint256 landPk = vm.envOr("LANDING_KEY", uint256(0));
        if (landPk != 0 && vm.addr(landPk) == LAND) {
            uint256 landUsdc = IERC20L(USDC).balanceOf(LAND);
            console2.log("landUsdc", landUsdc);
            if (landUsdc > 0) {
                vm.startBroadcast(landPk);
                IERC20L(USDC).transfer(COLD, landUsdc);
                vm.stopBroadcast();
            }
        } else {
            console2.log("Landing USDC locked (need Landing key)", IERC20L(USDC).balanceOf(LAND));
        }

        vm.startBroadcast(hotPk);

        // Free 14M ELE on 91.5% (no debt) → cold
        IMorphoL.MarketParams memory mp915 =
            IMorphoL.MarketParams(USDC, ELE, ORACLE_150, IRM, LLTV_915);
        (, , uint128 coll915) = IMorphoL(MORPHO).position(ELE915, HOT);
        console2.log("ele915coll", uint256(coll915));
        if (coll915 > 0) {
            IMorphoL(MORPHO).withdrawCollateral(mp915, uint256(coll915), HOT, COLD);
        }

        // Dust idle on 77% → cold USDC
        IMorphoL.MarketParams memory mp77 =
            IMorphoL.MarketParams(USDC, ELE, ORACLE_100, IRM, LLTV_77);
        IMorphoL(MORPHO).accrueInterest(mp77);
        (uint128 sa,, uint128 ba,,,) = IMorphoL(MORPHO).market(ELE77);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("idle77", idle);
        if (idle > 1) {
            IMorphoL(MORPHO).borrow(mp77, idle - 1, 0, HOT, COLD);
        }

        if (IPsmL(PSM).owner() == HOT) {
            uint256 psmUsdc = IERC20L(USDC).balanceOf(PSM);
            if (psmUsdc > 0) IPsmL(PSM).sweep(USDC, psmUsdc, COLD);
        }

        uint256 hotUsdc = IERC20L(USDC).balanceOf(HOT);
        if (hotUsdc > 0) IERC20L(USDC).transfer(COLD, hotUsdc);
        uint256 hotEle = IERC20L(ELE).balanceOf(HOT);
        if (hotEle > 0) IERC20L(ELE).transfer(COLD, hotEle);

        vm.stopBroadcast();

        console2.log("coldUsdc", IERC20L(USDC).balanceOf(COLD));
        console2.log("coldEle", IERC20L(ELE).balanceOf(COLD));
        console2.log("LIQUID_OPS_OK", uint256(1));
    }
}
