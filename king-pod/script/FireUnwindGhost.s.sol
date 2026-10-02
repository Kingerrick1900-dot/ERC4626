// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnwindGhost} from "../src/CrownUnwindGhost.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20u {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownUnwindGhost + unwind ghost loop in chunks. No new loop. Recover position.
contract FireUnwindGhost is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;
    bytes32 constant SYNTH = 0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;

    // Chunk size — gas-safe. Override with CHUNK_USDC.
    uint256 constant DEFAULT_CHUNK = 10_000_000e6; // $10M

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 chunk = vm.envOr("CHUNK_USDC", DEFAULT_CHUNK);
        uint256 maxFires = vm.envOr("MAX_FIRES", uint256(25));
        address existing = vm.envOr("UNWINDER", address(0));

        (uint256 supShares, uint128 borShares, uint128 coll) = IMorphoAuth(MORPHO).position(SYNTH, HOT);
        console2.log("FIRE", "unwind-ghost");
        console2.log("supShares", supShares);
        console2.log("borShares", uint256(borShares));
        console2.log("coll", uint256(coll));
        console2.log("hotUsdcBefore", IERC20u(USDC).balanceOf(HOT));
        console2.log("hotEusdBefore", IERC20u(EUSD).balanceOf(HOT));
        console2.log("chunk", chunk);

        vm.startBroadcast(pk);

        CrownUnwindGhost u;
        if (existing == address(0)) {
            u = new CrownUnwindGhost(MORPHO, USDC, EUSD, HOT, ORACLE, IRM, LLTV, HOT);
        } else {
            u = CrownUnwindGhost(existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(u))) {
            IMorphoAuth(MORPHO).setAuthorization(address(u), true);
        }

        uint256 fires;
        while (fires < maxFires) {
            uint256 debt = u.borrowAssetsOf(HOT);
            if (debt < 1e6) break;
            uint256 amt = debt < chunk ? debt : chunk;
            // leave $1 dust buffer on last chunk rounding — repay exact debt if small
            u.unwind(amt);
            unchecked {
                ++fires;
            }
            console2.log("fire", fires);
            console2.log("debtLeft", u.borrowAssetsOf(HOT));
        }

        u.skimUsdc();
        u.skimEusd();

        vm.stopBroadcast();

        (supShares, borShares, coll) = IMorphoAuth(MORPHO).position(SYNTH, HOT);
        console2.log("CrownUnwindGhost", address(u));
        console2.log("fires", fires);
        console2.log("totalRepaid", u.totalRepaid());
        console2.log("totalWithdrawn", u.totalWithdrawn());
        console2.log("totalCollFreed", u.totalCollFreed());
        console2.log("supSharesAfter", supShares);
        console2.log("borSharesAfter", uint256(borShares));
        console2.log("collAfter", uint256(coll));
        console2.log("hotUsdcAfter", IERC20u(USDC).balanceOf(HOT));
        console2.log("hotEusdAfter", IERC20u(EUSD).balanceOf(HOT));
    }
}
