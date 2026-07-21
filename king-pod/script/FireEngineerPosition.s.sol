// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory) external;
    function supply(MarketParams memory, uint256, uint256, address, bytes memory) external returns (uint256, uint256);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function isLltvEnabled(uint256) external view returns (bool);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setSupplyQueue(bytes32[] calldata) external;
}

interface IPAE {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address, FlowCapsConfig[] calldata) external;
}

interface IERC20Approve {
    function approve(address, uint256) external returns (bool);
}

/// @notice Full engineer-position package for King review dry-run / OK fire.
/// @dev LIVE-FIRE-LAW: KING_OK=1 + FIRE_ENGINEER=1 required for broadcast.
///      Steps: create high-LLTV RSS market → $1 seed all Kingdom markets → arm yRSS/PA.
///      BEFORE FIRE: send $2 USDC from Landing → hot (need $3 total for three $1 seeds).
contract FireEngineerPosition is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant ORACLE_RSS = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant ONE = 1e6;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_625 = 625000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;
    uint256 constant CAP = 14_000_000e6;
    uint256 constant PA_DEFAULT = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "LIVE-FIRE-LAW: need KING_OK=1");
        bool doFire = vm.envOr("FIRE_ENGINEER", uint256(0)) == 1;
        uint256 highLltv = vm.envOr("HIGH_LLTV", LLTV_915);
        uint256 paCap = vm.envOr("PA_CAP", PA_DEFAULT);
        require(IMorphoE(MORPHO).isLltvEnabled(highLltv), "LLTV");

        IMorphoE.MarketParams memory rss77 = IMorphoE.MarketParams(USDC, RSS, ORACLE_RSS, IRM, LLTV_77);
        IMorphoE.MarketParams memory brett = IMorphoE.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_625);
        IMorphoE.MarketParams memory rssHi = IMorphoE.MarketParams(USDC, RSS, ORACLE_RSS, IRM, highLltv);
        bytes32 idHi = keccak256(abi.encode(rssHi));

        uint256 hot = IERC20E(USDC).balanceOf(HOT);
        uint256 land = IERC20E(USDC).balanceOf(LANDING);

        console2.log("=== FIRE ENGINEER POSITION (King package) ===");
        console2.log("highLltv", highLltv);
        console2.logBytes32(idHi);
        console2.log("hotUsdc", hot);
        console2.log("landUsdc", land);
        console2.log("needSeedUsdc", 3 * ONE);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));
        console2.log("PRE_REQ: send $2 USDC Landing->hot before fire if hot < $3");

        if (!doFire) {
            console2.log("DRY-RUN COMPLETE - review PRE-DEPLOY-ENGINEER-POSITION.md");
            console2.log("Set FIRE_ENGINEER=1 + KING_OK=1 to broadcast create+seed+arm");
            console2.log("READY", uint256(0));
            return;
        }

        require(hot >= 3 * ONE, "NEED_3_USDC_ON_HOT: send from Landing first");

        vm.startBroadcast(pk);

        // 1) Create high-LLTV market if missing
        if (IMorphoE(MORPHO).idToMarketParams(idHi).loanToken != USDC) {
            IMorphoE(MORPHO).createMarket(rssHi);
            console2.log("createdHighLltv");
        } else {
            console2.log("highLltvExists");
        }

        // 2) Seed $1 each
        IERC20Approve(USDC).approve(MORPHO, 3 * ONE);
        IMorphoE(MORPHO).supply(rss77, ONE, 0, HOT, "");
        IMorphoE(MORPHO).supply(brett, ONE, 0, HOT, "");
        IMorphoE(MORPHO).supply(rssHi, ONE, 0, HOT, "");

        // 3) Arm yRSS
        IMetaMorphoE.MarketParams memory mpHi = IMetaMorphoE.MarketParams(USDC, RSS, ORACLE_RSS, IRM, highLltv);
        IMetaMorphoE(YRSS).submitCap(mpHi, CAP);
        IMetaMorphoE(YRSS).acceptCap(mpHi);

        bytes32[] memory queue = new bytes32[](5);
        queue[0] = idHi;
        queue[1] = RSS77;
        queue[2] = BRETT_M;
        queue[3] = CBBTC;
        queue[4] = WETH;
        IMetaMorphoE(YRSS).setSupplyQueue(queue);

        IPAE.FlowCapsConfig[] memory caps = new IPAE.FlowCapsConfig[](3);
        caps[0] = IPAE.FlowCapsConfig(idHi, IPAE.FlowCaps(uint128(paCap), uint128(paCap)));
        caps[1] = IPAE.FlowCapsConfig(RSS77, IPAE.FlowCaps(uint128(paCap), uint128(paCap)));
        caps[2] = IPAE.FlowCapsConfig(BRETT_M, IPAE.FlowCaps(uint128(paCap), uint128(paCap)));
        IPAE(PA).setFlowCaps(YRSS, caps);

        vm.stopBroadcast();

        (uint128 s77,,,,,) = IMorphoE(MORPHO).market(RSS77);
        (uint128 sB,,,,,) = IMorphoE(MORPHO).market(BRETT_M);
        (uint128 sH,,,,,) = IMorphoE(MORPHO).market(idHi);
        console2.log("supplyRss77", uint256(s77));
        console2.log("supplyBrett", uint256(sB));
        console2.log("supplyRssHigh", uint256(sH));
        require(sH >= ONE && sB >= ONE, "SEED_FAIL");
        console2.log("ENGINEER_POSITION_LIVE");
        console2.log("READY", uint256(1));
    }
}
