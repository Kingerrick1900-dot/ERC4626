// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownExitLadder} from "../src/CrownExitLadder.sol";

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYeleF {
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
    function config(bytes32) external view returns (uint184, bool, uint64);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

interface IZkF {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

/// @notice KING_GO=1 FIRE_EXIT=1 MODE=idle|loop ASK_USDC=700000000000
contract FireExitLadder is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_EXIT", uint256(0)) == 1, "NEED FIRE_EXIT=1");
        require(IZkF(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkF(GATE).attestations(HOT);
        require(attest >= IZkF(GATE).minThreshold(), "BELOW_THRESHOLD");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        string memory mode = vm.envOr("MODE", string("idle"));
        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));

        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("idle", idle);
        console2.log("mode", mode);
        console2.log("ask", ask);

        uint256 landBefore = IERC20F(USDC).balanceOf(LAND);

        vm.startBroadcast(pk);
        address existing = vm.envOr("EXIT_LADDER", address(0));
        CrownExitLadder x = existing == address(0)
            ? new CrownExitLadder(HOT, LAND)
            : CrownExitLadder(existing);
        console2.log("exitLadder", address(x));

        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(x))) {
            IMorphoF(MORPHO).setAuthorization(address(x), true);
        }

        (uint256 viewIdle, uint256 room) = x.idleAndRoom();
        console2.log("viewIdle", viewIdle);
        console2.log("lltvRoom", room);

        if (keccak256(bytes(mode)) == keccak256(bytes("loop"))) {
            (, bool wethOn,) = IYeleF(YELE).config(WETH_USDC);
            require(wethOn, "WETH_OFF");
            require(idle >= ask, "NO_IDLE_FOR_LOOP");
            if (!IYeleF(YELE).isAllocator(address(x))) {
                IYeleF(YELE).setIsAllocator(address(x), true);
            }
            x.leverageLoop(ask);
        } else {
            // idle mode — draw whatever liquid exists (may be dust)
            x.drawIdle(ask);
        }
        vm.stopBroadcast();

        uint256 landAfter = IERC20F(USDC).balanceOf(LAND);
        console2.log("landDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("EXIT_OK", uint256(1));
    }
}
