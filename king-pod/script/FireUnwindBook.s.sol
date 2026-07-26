// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnwindBook} from "../src/CrownUnwindBook.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice KING_GO=1 FIRE_UNWIND_BOOK=1 BOOK=ten|ele77
contract FireUnwindBook is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_77 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_UNWIND_BOOK", uint256(0)) == 1, "NEED FIRE_UNWIND_BOOK=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        string memory book = vm.envOr("BOOK", string("ten"));
        bool isTen = keccak256(bytes(book)) == keccak256(bytes("ten"));
        require(isTen || keccak256(bytes(book)) == keccak256(bytes("ele77")), "BOOK");

        console2.log("hotUsdcBefore", IERC20F(USDC).balanceOf(HOT));
        console2.log("hotEleBefore", IERC20F(ELE).balanceOf(HOT));

        CrownUnwindBook helper = CrownUnwindBook(vm.envOr("UNWIND_HELPER", address(0)));

        vm.startBroadcast(pk);
        if (address(helper) == address(0) || address(helper).code.length == 0) {
            helper = new CrownUnwindBook(HOT);
            console2.log("deployedUnwind", address(helper));
        }
        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(helper))) {
            IMorphoF(MORPHO).setAuthorization(address(helper), true);
        }
        IERC20F(USDC).approve(address(helper), type(uint256).max);

        helper.unwind(isTen ? ORACLE_10 : ORACLE_77, isTen ? LLTV_915 : LLTV_77, 10);
        vm.stopBroadcast();

        bytes32 id = isTen ? TEN : ELE77;
        (, uint128 bor, uint128 coll) = IMorphoF(MORPHO).position(id, HOT);
        console2.log("debtLeft", uint256(bor));
        console2.log("collLeft", uint256(coll));
        console2.log("hotUsdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("hotEleAfter", IERC20F(ELE).balanceOf(HOT));
        console2.log("UNWIND_HELPER", address(helper));
        console2.log("UNWIND_BOOK_OK", uint256(1));
    }
}
