// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deposit() external payable; // WETH
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Top off Elepan/cbBTC + Elepan/WETH Morpho books with ~$2 idle loan each.
/// @dev Sized from Uni V3 spot at fire time (~$65.7k BTC / ~$1.93k ETH). Leaves gas on hot.
contract TopOffElepanBtcEthTwoUsd is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant ORACLE_CBTC = 0x08DEeEF782B81C8CDD2e11bF5a54982f3A11C94d;
    address constant ORACLE_WETH = 0xF927B35E62A0111Da1A5D4Da63FA57E473B525E5;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    bytes32 constant CBBTC_M = 0x28d57b898122465e0260881973440823f1a380d64f16af56d982b47e5aeffa25;
    bytes32 constant WETH_M = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;

    // ~$2 each at fire-time Uni spot (cbBTC≈$65.7k, WETH≈$1.93k)
    uint256 constant CBTC_AMT = 3045; // 8dp
    uint256 constant WETH_AMT = 1_038_736_577_675_304; // 18dp
    uint256 constant ETH_GAS_FLOOR = 0.003 ether;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_TOPOFF", uint256(0)) == 1, "NEED FIRE_TOPOFF=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 cbtcBal = IERC20T(CBTC).balanceOf(HOT);
        uint256 ethBal = HOT.balance;
        console2.log("cbtcBefore", cbtcBal);
        console2.log("ethBefore", ethBal);
        require(cbtcBal >= CBTC_AMT, "CBTC");
        require(ethBal >= WETH_AMT + ETH_GAS_FLOOR, "ETH");

        (uint128 cSup0,, uint128 cBor0,,,) = IMorphoT(MORPHO).market(CBBTC_M);
        (uint128 wSup0,, uint128 wBor0,,,) = IMorphoT(MORPHO).market(WETH_M);
        console2.log("cbtcIdleBefore", uint256(cSup0) - uint256(cBor0));
        console2.log("wethIdleBefore", uint256(wSup0) - uint256(wBor0));

        IMorphoT.MarketParams memory mpC = IMorphoT.MarketParams({
            loanToken: CBTC,
            collateralToken: ELEPAN,
            oracle: ORACLE_CBTC,
            irm: IRM,
            lltv: LLTV
        });
        IMorphoT.MarketParams memory mpW = IMorphoT.MarketParams({
            loanToken: WETH,
            collateralToken: ELEPAN,
            oracle: ORACLE_WETH,
            irm: IRM,
            lltv: LLTV
        });

        vm.startBroadcast(pk);
        IERC20T(WETH).deposit{value: WETH_AMT}();
        IERC20T(CBTC).approve(MORPHO, CBTC_AMT);
        IERC20T(WETH).approve(MORPHO, WETH_AMT);
        IMorphoT(MORPHO).supply(mpC, CBTC_AMT, 0, HOT, hex"");
        IMorphoT(MORPHO).supply(mpW, WETH_AMT, 0, HOT, hex"");
        vm.stopBroadcast();

        (uint128 cSup1,, uint128 cBor1,,,) = IMorphoT(MORPHO).market(CBBTC_M);
        (uint128 wSup1,, uint128 wBor1,,,) = IMorphoT(MORPHO).market(WETH_M);
        uint256 cIdle = uint256(cSup1) - uint256(cBor1);
        uint256 wIdle = uint256(wSup1) - uint256(wBor1);
        console2.log("cbtcIdleAfter", cIdle);
        console2.log("wethIdleAfter", wIdle);
        require(cIdle >= CBTC_AMT - 1, "CBTC_IDLE");
        require(wIdle >= WETH_AMT - 1, "WETH_IDLE");
        console2.log("TOPOFF_2USD_OK", uint256(1));
    }
}
