// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPotFill} from "../src/CrownPotFill.sol";

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYeleF {
    function setIsAllocator(address, bool) external;
    function isAllocator(address) external view returns (bool);
    function totalAssets() external view returns (uint256);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

interface IZkF {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

/// @notice KING_GO=1 FIRE_POT=1 ASK_USDC=700000000000 — fill yELE-K from Morpho flash.
contract FirePotFill is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant MIN_ETH = 2e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_POT", uint256(0)) == 1, "NEED FIRE_POT=1");
        require(IZkF(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkF(GATE).attestations(HOT);
        require(attest >= IZkF(GATE).minThreshold(), "BELOW_THRESHOLD");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(HOT.balance >= MIN_ETH, "GAS_FLOOR");

        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));
        address vault = vm.envOr("VAULT", YELE_K);

        // PA from empty vault cannot fill — flash is the means.
        console2.log("vaultBefore", IYeleF(vault).totalAssets());
        console2.log("ask", ask);

        uint256 landBefore = IERC20F(USDC).balanceOf(LAND);

        vm.startBroadcast(pk);
        address existing = vm.envOr("POT_FILL", address(0));
        CrownPotFill pot = existing == address(0) ? new CrownPotFill(HOT, LAND, vault) : CrownPotFill(existing);
        console2.log("potFill", address(pot));

        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(pot))) {
            IMorphoF(MORPHO).setAuthorization(address(pot), true);
        }
        if (!IYeleF(vault).isAllocator(address(pot))) {
            IYeleF(vault).setIsAllocator(address(pot), true);
        }

        pot.fill(ask);
        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("vaultAfter", IYeleF(vault).totalAssets());
        console2.log("eleIdle", idle);
        console2.log("landDelta", IERC20F(USDC).balanceOf(LAND) > landBefore
            ? IERC20F(USDC).balanceOf(LAND) - landBefore
            : 0);
        console2.log("POT_FILL_OK", uint256(1));
    }
}
