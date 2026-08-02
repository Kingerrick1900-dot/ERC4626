// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoPa {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function config(bytes32 id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IPublicAllocatorPa {
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
    function admin(address vault) external view returns (address);
}

/// @notice Open kingdom PA doors for ELE77 draws. KING_GO=1 FIRE_OPEN_PA=1
/// @dev yELE: WETH maxOut + ELE77 maxIn (was WETH maxOut=0 — PA blocked).
///      yRSS: enable ELE77 + flow caps WETH/cbBTC maxOut → ELE77 maxIn (timelock 0).
contract FireOpenPaEle77 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant ELE_ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant CBBTC_ORACLE = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // Size to headroom phase (~$28.7M) and vault ELE77 cap ($14M on yELE).
    uint128 constant FLOW = 28_700_000e6;
    uint256 constant YELE_ELE_CAP = 14_000_000e6;
    uint256 constant YRSS_ELE_CAP = 14_000_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_OPEN_PA", uint256(0)) == 1, "NEED FIRE_OPEN_PA=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IPublicAllocatorPa(PA).admin(YELE) == HOT, "YELE_PA_ADMIN");
        require(IPublicAllocatorPa(PA).admin(YRSS) == HOT, "YRSS_PA_ADMIN");

        IMetaMorphoPa.MarketParams memory eleMp = IMetaMorphoPa.MarketParams({
            loanToken: USDC, collateralToken: ELE, oracle: ELE_ORACLE, irm: IRM, lltv: LLTV_77
        });

        vm.startBroadcast(pk);

        // --- yELE PA: open WETH→ELE77 pipe ---
        IPublicAllocatorPa.FlowCapsConfig[] memory yeleCaps = new IPublicAllocatorPa.FlowCapsConfig[](2);
        yeleCaps[0] = IPublicAllocatorPa.FlowCapsConfig({
            id: ELE77, caps: IPublicAllocatorPa.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        yeleCaps[1] = IPublicAllocatorPa.FlowCapsConfig({
            id: WETH_M, caps: IPublicAllocatorPa.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPublicAllocatorPa(PA).setFlowCaps(YELE, yeleCaps);
        console2.log("YELE_PA_CAPS_SET", uint256(1));

        // --- yRSS: enable ELE77 (timelock 0) + PA caps ---
        (, bool eleOn,) = IMetaMorphoPa(YRSS).config(ELE77);
        if (!eleOn) {
            IMetaMorphoPa(YRSS).submitCap(eleMp, YRSS_ELE_CAP);
            IMetaMorphoPa(YRSS).acceptCap(eleMp);
            console2.log("YRSS_ELE77_ENABLED", uint256(1));
        } else {
            console2.log("YRSS_ELE77_ALREADY", uint256(1));
        }

        // Keep deep books first; ELE77 last as PA target
        bytes32[] memory q = new bytes32[](4);
        q[0] = CBBTC_M;
        q[1] = WETH_M;
        q[2] = RSS77;
        q[3] = ELE77;
        // Only set queue if markets enabled — skip if cbBTC/WETH missing
        (, bool wOn,) = IMetaMorphoPa(YRSS).config(WETH_M);
        (, bool bOn,) = IMetaMorphoPa(YRSS).config(CBBTC_M);
        if (wOn && bOn) {
            IMetaMorphoPa(YRSS).setSupplyQueue(q);
            console2.log("YRSS_QUEUE_SET", uint256(1));
        }

        IPublicAllocatorPa.FlowCapsConfig[] memory yrssCaps = new IPublicAllocatorPa.FlowCapsConfig[](3);
        yrssCaps[0] = IPublicAllocatorPa.FlowCapsConfig({
            id: ELE77, caps: IPublicAllocatorPa.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        yrssCaps[1] = IPublicAllocatorPa.FlowCapsConfig({
            id: WETH_M, caps: IPublicAllocatorPa.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        yrssCaps[2] = IPublicAllocatorPa.FlowCapsConfig({
            id: CBBTC_M, caps: IPublicAllocatorPa.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPublicAllocatorPa(PA).setFlowCaps(YRSS, yrssCaps);
        console2.log("YRSS_PA_CAPS_SET", uint256(1));

        vm.stopBroadcast();

        (uint128 yeIn, uint128 yeOut) = IPublicAllocatorPa(PA).flowCaps(YELE, ELE77);
        (uint128 ywIn, uint128 ywOut) = IPublicAllocatorPa(PA).flowCaps(YELE, WETH_M);
        (uint128 reIn, uint128 reOut) = IPublicAllocatorPa(PA).flowCaps(YRSS, ELE77);
        (uint128 rwIn, uint128 rwOut) = IPublicAllocatorPa(PA).flowCaps(YRSS, WETH_M);
        (, bool yrssEle,) = IMetaMorphoPa(YRSS).config(ELE77);

        console2.log("yELE_ELE77_maxIn", uint256(yeIn));
        console2.log("yELE_ELE77_maxOut", uint256(yeOut));
        console2.log("yELE_WETH_maxIn", uint256(ywIn));
        console2.log("yELE_WETH_maxOut", uint256(ywOut));
        console2.log("yRSS_ELE77_maxIn", uint256(reIn));
        console2.log("yRSS_ELE77_maxOut", uint256(reOut));
        console2.log("yRSS_WETH_maxOut", uint256(rwOut));
        console2.log("yRSS_ELE77_enabled", yrssEle ? uint256(1) : uint256(0));
        console2.log("OPEN_PA_ELE77_OK", yeIn >= 500_000e6 && ywOut >= 500_000e6 && reIn >= 500_000e6 ? uint256(1) : uint256(0));
        // silence unused
        ywIn;
        reOut;
        rwIn;
        YELE_ELE_CAP;
    }
}
