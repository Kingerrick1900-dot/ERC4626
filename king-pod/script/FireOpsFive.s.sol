// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOpsFive} from "../src/CrownOpsFive.sol";

interface IMorphoA {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IMetaA {
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
    function setSkimRecipient(address) external;
}

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
}

contract FireOpsFive is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant ELE_WETH = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;
    bytes32 constant ELE_CBBTC = 0x28d57b898122465e0260881973440823f1a380d64f16af56d982b47e5aeffa25;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "GO");
        require(vm.envOr("FIRE_OPS_FIVE", uint256(0)) == 1, "NEED FIRE_OPS_FIVE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 landBefore = IERC20A(USDC).balanceOf(LAND);
        console2.log("landBefore", landBefore);

        vm.startBroadcast(pk);
        CrownOpsFive ops = new CrownOpsFive(HOT, LAND);
        console2.log("ops", address(ops));

        if (!IMorphoA(MORPHO).isAuthorized(HOT, address(ops))) {
            IMorphoA(MORPHO).setAuthorization(address(ops), true);
        }
        if (!IMetaA(YELE).isAllocator(address(ops))) {
            IMetaA(YELE).setIsAllocator(address(ops), true);
        }
        IMetaA(YELE).setSkimRecipient(address(ops));

        // 1) Clean ELE/USDC circular book via skim (never fired live successfully)
        (, uint128 eleBor,) = IMorphoA(MORPHO).position(ELE_USDC, HOT);
        if (eleBor > 0) {
            ops.cleanseEle();
            console2.log("CLEANSSED_ELE", uint256(1));
        }

        // 2) Unwind WETH + cbBTC loops
        (, uint128 wBor,) = IMorphoA(MORPHO).position(ELE_WETH, HOT);
        if (wBor > 0) {
            ops.unwindEleWeth();
            console2.log("UNWOUND_WETH", uint256(1));
        }
        (, uint128 bBor,) = IMorphoA(MORPHO).position(ELE_CBBTC, HOT);
        if (bBor > 0) {
            ops.unwindEleCbBtc();
            console2.log("UNWOUND_CBBTC", uint256(1));
        }

        console2.log("opsWeth", IERC20A(WETH).balanceOf(address(ops)));
        console2.log("hotEle", IERC20A(ELE).balanceOf(HOT));

        // 3) If any WETH on ops, borrow USDC to Landing
        if (IERC20A(WETH).balanceOf(address(ops)) > 0) {
            ops.borrowUsdcToLanding();
            console2.log("BORROWED_USDC", uint256(1));
        }

        vm.stopBroadcast();

        uint256 landAfter = IERC20A(USDC).balanceOf(LAND);
        console2.log("landAfter", landAfter);
        console2.log("landDelta", landAfter - landBefore);
        (, uint128 b2, uint128 c2) = IMorphoA(MORPHO).position(ELE_USDC, HOT);
        console2.log("eleDebtShares", uint256(b2));
        console2.log("eleColl", uint256(c2));
    }
}
