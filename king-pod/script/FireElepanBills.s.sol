// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanBills} from "../src/CrownElepanBills.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IYeleF {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function feeRecipient() external view returns (address);
    function setFeeRecipient(address) external;
    function setFee(uint256) external;
    function fee() external view returns (uint256);
}

/// @dev KING_GO=1 FIRE_ELE_BILLS=1 BILLS=0x01D1...
contract FireElepanBills is Script {
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

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ELE_BILLS", uint256(0)) == 1, "NEED FIRE_ELE_BILLS=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address billsAddr = vm.envOr("BILLS", address(0x01D1De8796B1dDbdB5C900277A54b6944C125906));
        uint256 yeleHot = IYeleF(YELE).balanceOf(HOT);
        console2.log("yeleOnHot", yeleHot);
        require(yeleHot > 0, "MOVE_YELE_LANDING_TO_HOT");

        CrownElepanBills bills = CrownElepanBills(billsAddr);

        vm.startBroadcast(pk);
        // Keep fee shares on hot during unwind (not Landing)
        if (IYeleF(YELE).feeRecipient() != HOT) {
            IYeleF(YELE).setFeeRecipient(HOT);
        }
        if (IYeleF(YELE).fee() != 0) {
            IYeleF(YELE).setFee(0);
        }

        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(bills))) {
            IMorphoF(MORPHO).setAuthorization(address(bills), true);
        }
        IYeleF(YELE).approve(address(bills), type(uint256).max);

        uint256 buf = IERC20F(USDC).balanceOf(HOT);
        if (buf > 0) {
            IERC20F(USDC).transfer(address(bills), buf);
        }

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        uint256 eleBefore = IERC20F(ELE).balanceOf(HOT);
        bills.unwind();
        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoF(MORPHO).position(MID, HOT);
        console2.log("debtAfter", uint256(bor));
        console2.log("collAfter", uint256(coll));
        console2.log("eleFreed", IERC20F(ELE).balanceOf(HOT) - eleBefore);
        console2.log("landingUsdc", IERC20F(USDC).balanceOf(LANDING));
        console2.log("landingDelta", IERC20F(USDC).balanceOf(LANDING) - landBefore);
        require(bor == 0 && coll == 0, "NOT_CLEAN");
        console2.log("ELE_BILLS_UNWIND_OK", uint256(1));
    }
}
