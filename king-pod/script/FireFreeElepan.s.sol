// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZeroMorpho} from "../src/CrownZeroMorpho.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorphoA {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice FREE ELE — zero Morpho ELE77 loan. No new desk: CrownZeroMorpho + yELE.
/// @dev KING_GO=1 FREE_ELE=1 forge script script/FireFreeElepan.s.sol:FireFreeElepan --broadcast
contract FireFreeElepan is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FREE_ELE", uint256(0)) == 1, "NEED FREE_ELE=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(ELE77, HOT);
        console2.log("borShares", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("eleBefore", IERC20A(ELE).balanceOf(HOT));
        console2.log("yeleAssets", IMetaMorphoA(YELE).totalAssets());
        require(bor > 0 || coll > 0, "NO_POS");

        vm.startBroadcast(pk);

        // CrownZeroMorpho: flash → repay → free coll → yVault covers flash (+$10 buffer).
        CrownZeroMorpho freer = new CrownZeroMorpho(
            MORPHO, USDC, ELE, YELE, HOT, ELE77, ORACLE, IRM, LLTV, HOT
        );
        console2.log("freer", address(freer));

        IMorphoAuth(MORPHO).setAuthorization(address(freer), true);
        IMetaMorphoA(YELE).approve(address(freer), type(uint256).max);
        // Cover flash/share dust gap (CrownZeroMorpho may pull king USDC).
        IERC20A(USDC).approve(address(freer), type(uint256).max);

        freer.zeroBooks();

        vm.stopBroadcast();

        (, uint128 bor2, uint128 coll2) = IMorphoAuth(MORPHO).position(ELE77, HOT);
        console2.log("borAfter", uint256(bor2));
        console2.log("collAfter", uint256(coll2));
        console2.log("eleAfter", IERC20A(ELE).balanceOf(HOT));
        console2.log("usdcAfter", IERC20A(USDC).balanceOf(HOT));
        require(bor2 == 0 && coll2 == 0, "NOT_ZERO");
        console2.log("ELE_FREE_NO_LOAN", uint256(1));
    }
}
