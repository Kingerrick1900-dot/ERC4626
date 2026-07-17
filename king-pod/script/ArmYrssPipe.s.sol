// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IOracle1 {
    function setPrice(uint256 newPrice) external;
    function price() external view returns (uint256);
}

interface IMetaMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function setIsAllocator(address allocator, bool isAllocator) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

interface IPublicAllocatorC {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setAdmin(address vault, address newAdmin) external;
    function setFee(address vault, uint256 newFee) external;
    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice Unit C — oracle $1, max yRSS cap, PA allocator + flow caps on RSS market.
/// @dev Broadcast LOCKED until King greenlight + PRIVATE_KEY.
contract ArmYrssPipe is Script {
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant YVAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // $1 / RSS → Morpho scale 1e24
    uint256 constant PRICE_1_USD = 1e24;
    // Max practical cap for RSS market allocation from yRSS (USDC 6 decimals)
    uint256 constant CAP_USDC = 14_000_000e6; // $14M

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IMetaMorphoC.MarketParams memory mp = IMetaMorphoC.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        console2.log("oracleBefore", IOracle1(ORACLE).price());

        vm.startBroadcast(pk);

        // 1) Oracle → $1
        IOracle1(ORACLE).setPrice(PRICE_1_USD);

        // 2) Max yRSS supply cap on RSS market
        IMetaMorphoC(YVAULT).submitCap(mp, CAP_USDC);
        IMetaMorphoC(YVAULT).acceptCap(mp);

        bytes32[] memory queue = new bytes32[](1);
        queue[0] = MARKET_ID;
        IMetaMorphoC(YVAULT).setSupplyQueue(queue);

        // 3) Public Allocator as yRSS allocator + flow caps
        IMetaMorphoC(YVAULT).setIsAllocator(PA, true);
        // King (vault owner) sets PA admin + zero fee + flow caps
        IPublicAllocatorC(PA).setAdmin(YVAULT, vm.addr(pk));
        IPublicAllocatorC(PA).setFee(YVAULT, 0);

        IPublicAllocatorC.FlowCapsConfig[] memory caps = new IPublicAllocatorC.FlowCapsConfig[](1);
        caps[0] = IPublicAllocatorC.FlowCapsConfig({
            id: MARKET_ID,
            caps: IPublicAllocatorC.FlowCaps({maxIn: uint128(CAP_USDC), maxOut: uint128(CAP_USDC)})
        });
        IPublicAllocatorC(PA).setFlowCaps(YVAULT, caps);

        vm.stopBroadcast();

        console2.log("oracleAfter", IOracle1(ORACLE).price());
        (uint184 cap,,) = IMetaMorphoC(YVAULT).config(MARKET_ID);
        console2.log("yRssCap", uint256(cap));
        (uint128 maxIn, uint128 maxOut) = IPublicAllocatorC(PA).flowCaps(YVAULT, MARKET_ID);
        console2.log("paMaxIn", uint256(maxIn));
        console2.log("paMaxOut", uint256(maxOut));
    }
}
