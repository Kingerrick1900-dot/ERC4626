// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
}

interface IVaultV2P {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function isAllocator(address) external view returns (bool);
    function adapters(uint256) external view returns (address);
}

interface IMorphoP {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice Read-only go/no-go before ATTACK. No broadcast. No keys required for checks.
/// @dev Exit code conceptually: prints READY=1 or READY=0. King must see READY=1.
contract PreflightWarElephant is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", uint256(9_000_000e6));
        address seeder = vm.envOr("SEEDER", address(0));
        address recoverer = vm.envOr("RECOVERER", address(0));

        uint256 fails;
        console2.log("=== WAR ELEPHANT PREFLIGHT ===");
        console2.log("borrowUsdc", borrowUsdc);

        // Roles
        if (IVaultV2P(VAULT).owner() != LANDING) {
            console2.log("FAIL owner != landing");
            fails++;
        } else {
            console2.log("OK owner=landing");
        }
        if (IVaultV2P(VAULT).curator() != HOT) {
            console2.log("FAIL curator != hot");
            fails++;
        } else {
            console2.log("OK curator=hot");
        }
        if (IVaultV2P(VAULT).asset() != USDC) {
            console2.log("FAIL vault asset");
            fails++;
        }
        if (IVaultV2P(VAULT).adapters(0) != ADAPTER) {
            console2.log("FAIL adapter mismatch");
            fails++;
        } else {
            console2.log("OK adapter");
        }
        if (IVaultV2P(VAULT).forceDeallocatePenalty(ADAPTER) != 0.01e18) {
            console2.log("WARN penalty != 1% (feed may set 0 briefly)");
            console2.log("penalty", IVaultV2P(VAULT).forceDeallocatePenalty(ADAPTER));
        } else {
            console2.log("OK penalty=1%");
        }

        // Market params
        (address loan, address coll, address ora, address irm, uint256 lltv) =
            IMorphoP(MORPHO).idToMarketParams(MARKET_ID);
        if (loan != USDC || coll != RSS || ora != ORACLE || irm != IRM || lltv != 0.77e18) {
            console2.log("FAIL market params");
            fails++;
        } else {
            console2.log("OK market params");
        }

        // Hot inventory
        uint256 rssBal = IERC20P(RSS).balanceOf(HOT);
        uint256 ethBal = HOT.balance;
        console2.log("hotRSS", rssBal);
        console2.log("hotETH_wei", ethBal);
        if (rssBal < 18_000_000e18) {
            console2.log("FAIL RSS low");
            fails++;
        } else {
            console2.log("OK RSS");
        }
        if (ethBal < 0.02 ether) {
            console2.log("FAIL gas ETH < 0.02");
            fails++;
        } else {
            console2.log("OK gas ETH");
        }

        // LTV
        if (borrowUsdc * 1e18 > (rssBal * 7000 * 1e6) / 10_000) {
            console2.log("FAIL LTV soft 70%");
            fails++;
        } else {
            console2.log("OK LTV soft 70%");
        }

        // Hot must be flat before attack
        (, uint128 bor, uint128 col) = IMorphoP(MORPHO).position(MARKET_ID, HOT);
        if (bor != 0 || col != 0) {
            console2.log("FAIL hot already has Morpho position - recover first");
            fails++;
        } else {
            console2.log("OK hot Morpho flat");
        }
        if (IVaultV2P(VAULT).balanceOf(HOT) != 0) {
            console2.log("WARN hot already has vault shares");
        }

        // Seeder / recoverer auth if provided
        if (seeder != address(0)) {
            if (!IMorphoP(MORPHO).isAuthorized(HOT, seeder)) {
                console2.log("FAIL seeder not Morpho-authorized");
                fails++;
            } else {
                console2.log("OK seeder authorized");
            }
            if (seeder.code.length == 0) {
                console2.log("FAIL seeder no code");
                fails++;
            }
        } else {
            console2.log("WARN SEEDER not set - run PREP first");
        }
        if (recoverer != address(0)) {
            if (!IMorphoP(MORPHO).isAuthorized(HOT, recoverer)) {
                console2.log("FAIL recoverer not authorized");
                fails++;
            } else {
                console2.log("OK recoverer authorized");
            }
        } else {
            console2.log("WARN RECOVERER not set - deploy before full size");
        }

        // Custom surface reminder
        console2.log("NOTE custom code is thin wrapper; Morpho+VaultV2 are audited upstream");
        console2.log("NOTE Base sequencer: use private/paid RPC; no DEX swap in path (low sandwich surface)");
        console2.log("NOTE rotate hot if key was ever shared in chat before $9M");

        if (fails == 0) {
            console2.log("READY=1");
        } else {
            console2.log("READY=0");
            console2.log("fails", fails);
        }
    }
}
