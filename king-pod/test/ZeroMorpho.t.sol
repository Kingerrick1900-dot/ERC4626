// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";
import {CrownZeroMorpho} from "../src/CrownZeroMorpho.sol";
interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}
interface IERC20A { function approve(address,uint256) external returns (bool); function balanceOf(address) external view returns (uint256); }
interface IYrssA { function approve(address,uint256) external returns (bool); function balanceOf(address) external view returns (uint256); }
contract ZeroMorphoTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    function test_zero_morpho() public {
        vm.startPrank(HOT);
        CrownZeroMorpho z = new CrownZeroMorpho(MORPHO, USDC, RSS, YRSS, HOT, MID, ORACLE, IRM, LLTV, HOT);
        IMorphoAuth(MORPHO).setAuthorization(address(z), true);
        IYrssA(YRSS).approve(address(z), type(uint256).max);
        IERC20A(USDC).approve(address(z), type(uint256).max);
        z.zeroBooks();
        vm.stopPrank();
        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MID, HOT);
        console2.log("bor", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("rss", IERC20A(RSS).balanceOf(HOT)/1e18);
        assertEq(uint256(bor), 0);
        assertEq(uint256(coll), 0);
    }
}
