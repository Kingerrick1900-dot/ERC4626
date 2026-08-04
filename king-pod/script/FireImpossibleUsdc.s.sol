// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownImpossibleUsdcMachine} from "../src/CrownImpossibleUsdcMachine.sol";
import {CrownPermissionlessUsdcSeed} from "../src/CrownPermissionlessUsdcSeed.sol";

interface IERC20I {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IAeroPairI {
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

/// @notice Do the impossible — max open fill + DEX extract + eUSD treasury to Landing.
/// @dev MODE=arm|extract|eusd|status  FIRE=1
contract FireImpossibleUsdc is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant SEED = 0x08DD633247F79740708d145A3A8964a8c9Ee501a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_PAIR = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        string memory mode = vm.envOr("MODE", string("arm"));
        address existingMachine = vm.envOr("MACHINE", address(0));
        uint256 extraEscrow = vm.envOr("EXTRA_ESCROW_RSS", uint256(3_000_000 ether));
        uint256 sweetBps = vm.envOr("SWEET_BPS", uint256(2000)); // +20% max
        uint256 eusdAmt = vm.envOr("EUSD_AMT", uint256(700_000 ether));
        uint256 rssSell = vm.envOr("RSS_SELL", uint256(100_000 ether)); // drain aero depth

        console2.log("=== DO THE IMPOSSIBLE ===");
        console2.log("mode", mode);
        console2.log("Landing USDC", IERC20I(USDC).balanceOf(LANDING));
        console2.log("Landing eUSD", IERC20I(EUSD).balanceOf(LANDING));
        console2.log("hot RSS", IERC20I(RSS).balanceOf(HOT));
        console2.log("hot eUSD", IERC20I(EUSD).balanceOf(HOT));
        console2.log("seed escrow", CrownPermissionlessUsdcSeed(SEED).rssEscrow());
        console2.log("seed sweet", CrownPermissionlessUsdcSeed(SEED).sweetenerBps());
        console2.log("aero quote", IAeroPairI(AERO_PAIR).getAmountOut(rssSell, RSS));

        if (!fire) {
            console2.log("DRY - FIRE=1 MODE=arm|extract|eusd|all");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        address machineAddr = existingMachine;

        if (
            keccak256(bytes(mode)) == keccak256(bytes("arm"))
                || keccak256(bytes(mode)) == keccak256(bytes("all"))
        ) {
            CrownPermissionlessUsdcSeed seed = CrownPermissionlessUsdcSeed(SEED);
            seed.setParams(1e12, sweetBps);
            console2.log("SWEETENER_SET", sweetBps);
            if (extraEscrow > 0) {
                require(IERC20I(RSS).approve(SEED, extraEscrow), "APPROVE");
                seed.depositRss(extraEscrow);
                console2.log("EXTRA_ESCROW", extraEscrow);
            }
            if (machineAddr == address(0)) {
                CrownImpossibleUsdcMachine machine = new CrownImpossibleUsdcMachine(
                    MORPHO, AERO_ROUTER, AERO_PAIR, AERO_FACTORY, USDC, RSS, LANDING, SEED, HOT
                );
                machineAddr = address(machine);
            }
            console2.log("MACHINE", machineAddr);
        }

        // extractDex = RSS dump into Aero depth. NOT default — loan-dont-dump.
        // Only MODE=extract (explicit). Scales when pool deepens.
        if (keccak256(bytes(mode)) == keccak256(bytes("extract"))) {
            if (machineAddr == address(0)) {
                CrownImpossibleUsdcMachine m = new CrownImpossibleUsdcMachine(
                    MORPHO, AERO_ROUTER, AERO_PAIR, AERO_FACTORY, USDC, RSS, LANDING, SEED, HOT
                );
                machineAddr = address(m);
                console2.log("MACHINE", machineAddr);
            }
            uint256 quote = IAeroPairI(AERO_PAIR).getAmountOut(rssSell, RSS);
            require(quote > 0, "NO_DEPTH");
            require(IERC20I(RSS).approve(machineAddr, rssSell), "APPROVE_RSS");
            uint256 got = CrownImpossibleUsdcMachine(machineAddr).extractDex(rssSell, quote * 95 / 100);
            console2.log("EXTRACTED_USDC", got);
            console2.log("Landing USDC", IERC20I(USDC).balanceOf(LANDING));
        }

        if (
            keccak256(bytes(mode)) == keccak256(bytes("eusd"))
                || keccak256(bytes(mode)) == keccak256(bytes("all"))
        ) {
            uint256 bal = IERC20I(EUSD).balanceOf(HOT);
            uint256 amt = eusdAmt < bal ? eusdAmt : bal;
            if (amt > 0) {
                require(IERC20I(EUSD).transfer(LANDING, amt), "EUSD");
                console2.log("EUSD_TO_LANDING", amt);
            }
            console2.log("Landing eUSD", IERC20I(EUSD).balanceOf(LANDING));
        }

        vm.stopBroadcast();
        console2.log("Landing USDC final", IERC20I(USDC).balanceOf(LANDING));
        console2.log("OK");
    }
}
