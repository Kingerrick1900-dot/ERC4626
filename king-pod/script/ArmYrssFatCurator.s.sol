// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IPublicAllocator {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice Fat-curator: enable BRETT market on yRSS + PA flow + queue RSS first then BRETT.
/// @dev Env: PRIVATE_KEY, BRETT_ORACLE, BRETT_MARKET_ID (bytes32 hex)
contract ArmYrssFatCurator is Script {
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant RSS_LLTV = 770000000000000000;
    uint256 constant BRETT_LLTV = 625000000000000000;
    bytes32 constant RSS_MARKET = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // Fat caps — Kingdom controls flow; depositors fund the books
    uint256 constant RSS_CAP = 14_000_000e6;
    uint256 constant BRETT_CAP = 2_000_000e6;
    uint128 constant FLOW = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address brettOracle = vm.envAddress("BRETT_ORACLE");
        bytes32 brettMarket = vm.envBytes32("BRETT_MARKET_ID");

        IMetaMorpho.MarketParams memory brettMp = IMetaMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: BRETT,
            oracle: brettOracle,
            irm: IRM,
            lltv: BRETT_LLTV
        });

        // Preserve live queue (cbBTC, WETH, RSS) and append BRETT moat
        bytes32 q0 = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
        bytes32 q1 = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

        vm.startBroadcast(pk);

        // RSS already capped live — only add BRETT niche
        IMetaMorpho(YRSS).submitCap(brettMp, BRETT_CAP);
        IMetaMorpho(YRSS).acceptCap(brettMp);

        bytes32[] memory queue = new bytes32[](4);
        queue[0] = q0;
        queue[1] = q1;
        queue[2] = RSS_MARKET;
        queue[3] = brettMarket;
        IMetaMorpho(YRSS).setSupplyQueue(queue);

        IPublicAllocator.FlowCapsConfig[] memory caps = new IPublicAllocator.FlowCapsConfig[](1);
        caps[0] = IPublicAllocator.FlowCapsConfig({
            id: brettMarket, caps: IPublicAllocator.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPublicAllocator(PA).setFlowCaps(YRSS, caps);

        vm.stopBroadcast();

        (uint184 c0, bool e0,) = IMetaMorpho(YRSS).config(RSS_MARKET);
        (uint184 c1, bool e1,) = IMetaMorpho(YRSS).config(brettMarket);
        console2.log("RSS enabled", e0);
        console2.log("RSS cap", uint256(c0));
        console2.log("BRETT enabled", e1);
        console2.log("BRETT cap", uint256(c1));
    }
}
