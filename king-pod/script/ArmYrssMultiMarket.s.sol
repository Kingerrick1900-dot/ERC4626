// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoArm {
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
}

interface IPublicAllocatorArm {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

/// @notice Arm yRSS with cbBTC+WETH USDC markets so PA can pull maxOut → RSS maxIn.
contract ArmYrssMultiMarket is Script {
    address constant YVAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    // Canonical Base Morpho USDC books
    address constant ORACLE_CBBTC = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant RSS_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    uint256 constant LLTV_RSS = 770000000000000000;

    uint256 constant CAP = 14_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IMetaMorphoArm.MarketParams memory cbBtc = IMetaMorphoArm.MarketParams({
            loanToken: USDC,
            collateralToken: CBBTC,
            oracle: ORACLE_CBBTC,
            irm: IRM,
            lltv: LLTV_86
        });
        IMetaMorphoArm.MarketParams memory weth = IMetaMorphoArm.MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: ORACLE_WETH,
            irm: IRM,
            lltv: LLTV_86
        });
        IMetaMorphoArm.MarketParams memory rss = IMetaMorphoArm.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: RSS_ORACLE,
            irm: IRM,
            lltv: LLTV_RSS
        });

        vm.startBroadcast(pk);

        IMetaMorphoArm(YVAULT).submitCap(cbBtc, CAP);
        IMetaMorphoArm(YVAULT).acceptCap(cbBtc);
        IMetaMorphoArm(YVAULT).submitCap(weth, CAP);
        IMetaMorphoArm(YVAULT).acceptCap(weth);

        // Queue: deep books first (attract deposits), RSS last (PA target)
        bytes32[] memory queue = new bytes32[](3);
        queue[0] = CBBTC_ID;
        queue[1] = WETH_ID;
        queue[2] = RSS_ID;
        IMetaMorphoArm(YVAULT).setSupplyQueue(queue);

        IPublicAllocatorArm.FlowCapsConfig[] memory caps = new IPublicAllocatorArm.FlowCapsConfig[](3);
        caps[0] = IPublicAllocatorArm.FlowCapsConfig({
            id: CBBTC_ID,
            caps: IPublicAllocatorArm.FlowCaps({maxIn: uint128(CAP), maxOut: uint128(CAP)})
        });
        caps[1] = IPublicAllocatorArm.FlowCapsConfig({
            id: WETH_ID,
            caps: IPublicAllocatorArm.FlowCaps({maxIn: uint128(CAP), maxOut: uint128(CAP)})
        });
        caps[2] = IPublicAllocatorArm.FlowCapsConfig({
            id: RSS_ID,
            caps: IPublicAllocatorArm.FlowCaps({maxIn: uint128(CAP), maxOut: uint128(CAP)})
        });
        IPublicAllocatorArm(PA).setFlowCaps(YVAULT, caps);

        vm.stopBroadcast();

        (uint184 cCap,,) = IMetaMorphoArm(YVAULT).config(CBBTC_ID);
        (uint184 wCap,,) = IMetaMorphoArm(YVAULT).config(WETH_ID);
        (uint184 rCap,,) = IMetaMorphoArm(YVAULT).config(RSS_ID);
        console2.log("cbBtcCap", uint256(cCap));
        console2.log("wethCap", uint256(wCap));
        console2.log("rssCap", uint256(rCap));
    }
}
