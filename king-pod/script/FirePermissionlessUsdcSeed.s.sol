// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPermissionlessUsdcSeed} from "../src/CrownPermissionlessUsdcSeed.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Deploy open USDC seed + optionally escrow RSS + optionally send eUSD to Landing.
/// @dev MODE=deploy|escrow|eusd_landing|status
///      FIRE=1 broadcast. ESCROW_RSS / EUSD_AMT for sizes.
contract FirePermissionlessUsdcSeed is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        string memory mode = vm.envOr("MODE", string("deploy"));
        address existing = vm.envOr("SEED", address(0));
        uint256 escrowRss = vm.envOr("ESCROW_RSS", uint256(2_000_000 ether)); // 2M RSS @ $1 = $2M capacity
        uint256 sweetBps = vm.envOr("SWEET_BPS", uint256(300)); // +3% RSS sweetener
        uint256 eusdAmt = vm.envOr("EUSD_AMT", uint256(100_000 ether)); // 100k eUSD interim treasury

        console2.log("=== PERMISSIONLESS USDC SEED ===");
        console2.log("mode", mode);
        console2.log("hot RSS", IERC20S(RSS).balanceOf(HOT));
        console2.log("hot eUSD", IERC20S(EUSD).balanceOf(HOT));
        console2.log("hot USDC", IERC20S(USDC).balanceOf(HOT));
        console2.log("Landing USDC", IERC20S(USDC).balanceOf(LANDING));
        console2.log("Landing eUSD", IERC20S(EUSD).balanceOf(LANDING));

        if (!fire) {
            console2.log("DRY - FIRE=1 MODE=deploy|escrow|eusd_landing");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        if (keccak256(bytes(mode)) == keccak256(bytes("deploy"))) {
            CrownPermissionlessUsdcSeed seed =
                new CrownPermissionlessUsdcSeed(RSS, USDC, LANDING, HOT);
            if (sweetBps > 0) seed.setParams(1e12, sweetBps);
            console2.log("DEPLOYED", address(seed));
            // escrow in same broadcast if ESCROW_RSS > 0
            if (escrowRss > 0) {
                require(IERC20S(RSS).approve(address(seed), escrowRss), "APPROVE");
                seed.depositRss(escrowRss);
                console2.log("ESCROWED", escrowRss);
            }
        } else if (keccak256(bytes(mode)) == keccak256(bytes("escrow"))) {
            require(existing != address(0), "SEED");
            CrownPermissionlessUsdcSeed seed = CrownPermissionlessUsdcSeed(existing);
            require(IERC20S(RSS).approve(existing, escrowRss), "APPROVE");
            seed.depositRss(escrowRss);
            console2.log("ESCROWED", escrowRss);
        } else if (keccak256(bytes(mode)) == keccak256(bytes("eusd_landing"))) {
            // Interim: move eUSD inventory to Landing treasury (not a dump — relocate)
            require(eusdAmt > 0, "AMT");
            require(IERC20S(EUSD).transfer(LANDING, eusdAmt), "EUSD_XFER");
            console2.log("EUSD_TO_LANDING", eusdAmt);
            console2.log("Landing eUSD", IERC20S(EUSD).balanceOf(LANDING));
        } else {
            revert("MODE");
        }

        vm.stopBroadcast();
        console2.log("OK");
    }
}
