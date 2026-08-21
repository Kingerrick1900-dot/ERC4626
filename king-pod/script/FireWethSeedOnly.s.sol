// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {CrownPermissionlessWethSeed} from "src/CrownPermissionlessWethSeed.sol";
import {CrownWethIdleRaid} from "src/CrownWethIdleRaid.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice LIVE: deploy raid+seed, escrow RSS. No desk. No raid until WETH arrives.
contract FireWethSeedOnly is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE_RSS = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        uint256 escrowRss = vm.envOr("ESCROW_RSS", uint256(5_000_000 ether));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        console2.log("ETH", HOT.balance);
        console2.log("RSS", IERC20F(RSS).balanceOf(HOT));

        vm.startBroadcast(pk);

        CrownWethIdleRaid raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID);
        IMorphoAuth(MORPHO).setAuthorization(address(raid), true);

        CrownPermissionlessWethSeed seed =
            new CrownPermissionlessWethSeed(RSS, WETH, ORACLE_RSS, ORACLE_WETH, HOT, HOT, 2_000);

        IERC20F(RSS).approve(address(seed), escrowRss);
        seed.depositRss(escrowRss);

        vm.stopBroadcast();

        console2.log("raid", address(raid));
        console2.log("seed", address(seed));
        console2.log("escrowRss", seed.rssEscrow());
        console2.log("quote360WethRss", seed.quoteRssOut(360 ether));
        console2.log("FILL: weth.approve(seed,amt); seed.fill(amt);");
        console2.log("THEN: RAID=1 with WETH_IN on FireWethEngineerRaid");
    }
}
