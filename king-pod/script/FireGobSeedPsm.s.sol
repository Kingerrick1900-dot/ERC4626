// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssWethDesk} from "../src/CrownRssWethDesk.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams calldata, uint256, address, bytes calldata) external;
    function borrow(MarketParams calldata, uint256, uint256, address, address) external returns (uint256, uint256);
}

interface IPsmS {
    function seed(address, uint256) external;
    function usdcReserve() external view returns (uint256);
}

/// @notice GO-B live fire AFTER WETH is on hot (from desk loan or lender).
/// @dev Env: PRIVATE_KEY, WETH_IN (18dp), USDC_OUT (6dp), optional DESK / skip desk.
///      Does not sell RSS. Does not touch RSS Morpho books.
contract FireGobSeedPsm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 0.86e18;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 wethIn = vm.envUint("WETH_IN");
        uint256 usdcOut = vm.envUint("USDC_OUT");
        require(IERC20S(WETH).balanceOf(HOT) >= wethIn, "NO_WETH");

        IMorphoS.MarketParams memory mp =
            IMorphoS.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV);

        vm.startBroadcast(pk);
        IERC20S(WETH).approve(MORPHO, wethIn);
        IMorphoS(MORPHO).supplyCollateral(mp, wethIn, HOT, "");
        IMorphoS(MORPHO).borrow(mp, usdcOut, 0, HOT, HOT);
        IERC20S(USDC).approve(PSM, usdcOut);
        IPsmS(PSM).seed(USDC, usdcOut);
        vm.stopBroadcast();

        console2.log("WETH_IN", wethIn);
        console2.log("USDC_SEEDED", usdcOut);
        console2.log("PSM_RESERVE", IPsmS(PSM).usdcReserve());
    }
}
