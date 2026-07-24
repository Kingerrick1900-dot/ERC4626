// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";
import {CrownElepanBills} from "../src/CrownElepanBills.sol";
interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}
interface IMorphoT {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}
interface IYeleT {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function maxRedeem(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}
contract ElepanBillsLiveBufTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_live_buf_only() public {
        uint256 hotUsdc = IERC20T(USDC).balanceOf(HOT);
        console2.log("hotUsdc", hotUsdc);
        console2.log("yeleHot", IYeleT(YELE).balanceOf(HOT));
        console2.log("landYele", IYeleT(YELE).balanceOf(LANDING));

        vm.startPrank(HOT);
        CrownElepanBills bills = new CrownElepanBills(
            MORPHO, USDC, ELE, YELE, HOT, LANDING, MID, ORACLE, IRM, LLTV, HOT
        );
        IMorphoT(MORPHO).setAuthorization(address(bills), true);
        IYeleT(YELE).approve(address(bills), type(uint256).max);
        if (hotUsdc > 0) IERC20T(USDC).transfer(address(bills), hotUsdc);
        vm.stopPrank();

        console2.log("billsUsdc", IERC20T(USDC).balanceOf(address(bills)));
        vm.prank(HOT);
        bills.unwind();

        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MID, HOT);
        console2.log("debt", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("landingUsdc", IERC20T(USDC).balanceOf(LANDING));
        console2.log("yeleTA", IYeleT(YELE).totalAssets());
        assertEq(uint256(bor), 0, "debt");
        assertEq(uint256(coll), 0, "coll");
    }
}
