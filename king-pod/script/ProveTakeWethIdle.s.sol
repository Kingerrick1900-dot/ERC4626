// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {CrownTakeWethIdle} from "../src/CrownTakeWethIdle.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Anvil/fork prove: permissionless poke → Landing +$700k.
contract ProveTakeWethIdle is Script, StdCheats {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant ASK = 700_000e6;
    uint256 constant EQUITY = 380 ether;

    function run() external {
        address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        address keeper = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint256 land0 = IERC20P(USDC).balanceOf(LANDING);

        vm.startBroadcast(deployer);
        CrownTakeWethIdle take =
            new CrownTakeWethIdle(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID, HOT, EQUITY, ASK);
        vm.stopBroadcast();

        deal(WETH, HOT, EQUITY);
        vm.prank(HOT);
        IMorphoAuth(MORPHO).setAuthorization(address(take), true);
        vm.prank(HOT);
        IERC20P(WETH).approve(address(take), type(uint256).max);

        require(take.ready(), "not ready");

        vm.broadcast(keeper);
        take.poke();

        uint256 delta = IERC20P(USDC).balanceOf(LANDING) - land0;
        console2.log("Landing delta", delta);
        require(delta == ASK, "LANDING_MISS");
        console2.log("POKE_PROVE_OK");
    }
}
