// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownFlashAttack500} from "../src/CrownFlashAttack500.sol";

interface IMorphoT {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoT {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
}

contract FlashAttack500ForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant RSS91 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function test_flash_attack_500k_fork() public {
        uint256 borrowUsdc = 500_000e6;
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        uint256 tvlBefore = IMetaMorphoT(YRSS).totalAssets();

        vm.startPrank(HOT);
        if (IMetaMorphoT(YRSS).supplyQueue(0) != RSS77) {
            bytes32[] memory q = new bytes32[](5);
            q[0] = RSS77;
            q[1] = RSS91;
            q[2] = CBBTC;
            q[3] = WETH;
            q[4] = BRETT;
            IMetaMorphoT(YRSS).setSupplyQueue(q);
        }

        CrownFlashAttack500 attacker =
            new CrownFlashAttack500(MORPHO, USDC, YRSS, HOT, RSS77, RSS, ORACLE, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(attacker), true);
        attacker.attack(borrowUsdc);
        vm.stopPrank();

        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(RSS77, HOT);
        (uint128 sup,, uint128 mBor,,,) = IMorphoT(MORPHO).market(RSS77);
        uint256 yrssAssets = IMetaMorphoT(YRSS).convertToAssets(IMetaMorphoT(YRSS).balanceOf(HOT));

        console2.log("coll", uint256(coll));
        console2.log("debtShares", uint256(bor));
        console2.log("marketSupply", uint256(sup));
        console2.log("marketBorrow", uint256(mBor));
        console2.log("hotYrssAssets", yrssAssets);
        console2.log("landingGain", IERC20T(USDC).balanceOf(LANDING) - landBefore);
        console2.log("yRSS_TVL_gain", IMetaMorphoT(YRSS).totalAssets() - tvlBefore);

        assertGt(uint256(coll), 0, "coll");
        assertGt(uint256(bor), 0, "debt");
        assertGe(IMetaMorphoT(YRSS).totalAssets(), tvlBefore + borrowUsdc - 1e6, "yRSS TVL");
        assertGe(yrssAssets, borrowUsdc - 1e6, "hot yRSS");
    }
}
