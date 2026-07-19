// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSelfSeedV2} from "../src/CrownSelfSeedV2.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IVaultV2S {
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function isAllocator(address) external view returns (bool);
}

/// @notice War elephant - PREP always; ATTACK only with KING_GO=1 and FIRE_ATTACK=1.
/// @dev Default run = deploy/reuse seeder + Morpho auth + RSS approve. Does NOT borrow.
contract FireWarElephant is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "signer must be hot");

        bool kingGo = vm.envOr("KING_GO", uint256(0)) == 1;
        bool fireAttack = vm.envOr("FIRE_ATTACK", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", uint256(9_000_000e6));
        // Allow micro ladder sizes; default remains $9M when unset
        if (borrowUsdc == 0) borrowUsdc = 9_000_000e6;
        address existing = vm.envOr("SEEDER", address(0));

        uint256 rssBal = IERC20S(RSS).balanceOf(HOT);
        console2.log("=== WAR ELEPHANT PREP ===");
        console2.log("rssBal", rssBal);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("vault", VAULT);
        console2.log("landing(cold)", LANDING);
        console2.log("kingGo", kingGo ? uint256(1) : uint256(0));
        console2.log("fireAttack", fireAttack ? uint256(1) : uint256(0));

        // Soft LTV check (view only)
        require(borrowUsdc * 1e18 <= (rssBal * 7000 * 1e6) / 10_000, "LTV: need more RSS or smaller borrow");

        vm.startBroadcast(pk);

        CrownSelfSeedV2 seeder;
        if (existing == address(0)) {
            seeder = new CrownSelfSeedV2(MORPHO, USDC, RSS, VAULT, HOT, MARKET_ID, ORACLE, IRM, LLTV, HOT);
            console2.log("seeder deployed", address(seeder));
        } else {
            seeder = CrownSelfSeedV2(existing);
            console2.log("seeder reused", existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoAuth(MORPHO).setAuthorization(address(seeder), true);
            console2.log("morpho auth granted");
        }

        if (IERC20S(RSS).allowance(HOT, address(seeder)) < rssBal) {
            IERC20S(RSS).approve(address(seeder), type(uint256).max);
            console2.log("rss approved");
        }

        if (kingGo && fireAttack) {
            console2.log("FIRE ATTACK - King go");
            seeder.attack(0, borrowUsdc); // full RSS, sized borrow
        } else {
            console2.log("ARMED - no attack (need KING_GO=1 FIRE_ATTACK=1)");
        }

        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MARKET_ID, HOT);
        uint256 shares = IVaultV2S(VAULT).balanceOf(HOT);
        console2.log("post hotBorrow", uint256(bor));
        console2.log("post hotColl", uint256(coll));
        console2.log("post vaultShares", shares);
        console2.log("post vaultAssets", IVaultV2S(VAULT).convertToAssets(shares));
        console2.log("vaultTVL", IVaultV2S(VAULT).totalAssets());
        console2.log("SEEDER", address(seeder));
    }
}
