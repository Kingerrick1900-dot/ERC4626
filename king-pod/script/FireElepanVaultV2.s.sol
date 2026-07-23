// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @dev Minimal interfaces — Morpho Vault V2 on Base (no vault-v2 lib required).
interface IVaultV2Factory {
    function createVaultV2(address owner, address asset, bytes32 salt) external returns (address);
}

interface IAdapterFactory {
    function createMorphoMarketV1AdapterV2(address vault) external returns (address);
}

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function deposit() external payable;
}

interface IMorphoM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IVaultV2 {
    function setCurator(address) external;
    function setOwner(address) external;
    function submit(bytes memory data) external;
    function setIsAllocator(address, bool) external;
    function setAdapterRegistry(address) external;
    function addAdapter(address) external;
    function increaseAbsoluteCap(bytes memory idData, uint256) external;
    function increaseRelativeCap(bytes memory idData, uint256) external;
    function abdicate(bytes4) external;
    function setLiquidityAdapterAndData(address adapter, bytes memory data) external;
    function setForceDeallocatePenalty(address adapter, uint256 penalty) external;
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function asset() external view returns (address);
}

interface IPublicAllocatorV {
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
}

/// @notice Elepan Vault V2: adapter registry → MorphoMarketV1Adapter → Elepan/WETH liquidity.
/// @dev KING_GO=1 FIRE_V2=1. Bootstrap timelock=0 path (VaultV2 factory). Needs ~0.001+ ETH.
contract FireElepanVaultV2 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_W = 0xF927B35E62A0111Da1A5D4Da63FA57E473B525E5;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant V2_FACTORY = 0x4501125508079A99ebBebCE205DeC9593C2b5857;
    address constant ADAPTER_FACTORY = 0x9a1B378C43BA535cDB89934230F0D3890c51C0EB;
    address constant ADAPTER_REGISTRY = 0x5C2531Cbd2cf112Cf687da3Cd536708aDd7DB10a;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    bytes32 constant MARKET_WETH = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;
    uint256 constant LLTV = 770000000000000000;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 constant PENALTY = 0.01e18;
    uint256 constant DEAD_AMT = 1e9; // 1e9 wei WETH

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_V2", uint256(0)) == 1, "NEED FIRE_V2=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        (address loan, address coll, address ora, address irm, uint256 lltv) =
            IMorphoM(MORPHO).idToMarketParams(MARKET_WETH);
        require(loan == WETH && coll == ELEPAN && ora == ORACLE_W && irm == IRM && lltv == LLTV, "MARKET");

        IMorphoM.MarketParams memory mp = IMorphoM.MarketParams({
            loanToken: WETH, collateralToken: ELEPAN, oracle: ORACLE_W, irm: IRM, lltv: LLTV
        });

        vm.startBroadcast(pk);

        bytes32 salt = keccak256(abi.encodePacked("king-elepan-weth-v2", HOT, uint256(1)));
        address vault = IVaultV2Factory(V2_FACTORY).createVaultV2(HOT, WETH, salt);
        IVaultV2 v = IVaultV2(vault);
        v.setCurator(HOT);

        address adapter = IAdapterFactory(ADAPTER_FACTORY).createMorphoMarketV1AdapterV2(vault);

        // 1) Adapter registry (+ abdicate after set)
        bytes memory adapterIdData = abi.encode("this", adapter);
        v.submit(abi.encodeCall(v.setIsAllocator, (HOT, true)));
        v.submit(abi.encodeCall(v.setAdapterRegistry, (ADAPTER_REGISTRY)));
        v.submit(abi.encodeCall(v.addAdapter, (adapter)));
        v.submit(abi.encodeCall(v.increaseAbsoluteCap, (adapterIdData, type(uint128).max)));
        v.submit(abi.encodeCall(v.increaseRelativeCap, (adapterIdData, 1e18)));
        v.submit(abi.encodeCall(v.abdicate, (IVaultV2.setAdapterRegistry.selector)));

        v.setIsAllocator(HOT, true);
        v.setAdapterRegistry(ADAPTER_REGISTRY);
        v.addAdapter(adapter);
        v.increaseAbsoluteCap(adapterIdData, type(uint128).max);
        v.increaseRelativeCap(adapterIdData, 1e18);
        v.abdicate(IVaultV2.setAdapterRegistry.selector);

        // 5) Liquidity adapter = Elepan/WETH market
        bytes memory liquidityData = abi.encode(mp);
        v.setLiquidityAdapterAndData(adapter, liquidityData);

        bytes memory collId = abi.encode("collateralToken", ELEPAN);
        v.submit(abi.encodeCall(v.increaseAbsoluteCap, (collId, type(uint128).max)));
        v.submit(abi.encodeCall(v.increaseRelativeCap, (collId, 1e18)));
        v.increaseAbsoluteCap(collId, type(uint128).max);
        v.increaseRelativeCap(collId, 1e18);

        bytes memory mktId = abi.encode("this/marketParams", adapter, mp);
        v.submit(abi.encodeCall(v.increaseAbsoluteCap, (mktId, type(uint128).max)));
        v.submit(abi.encodeCall(v.increaseRelativeCap, (mktId, 1e18)));
        v.increaseAbsoluteCap(mktId, type(uint128).max);
        v.increaseRelativeCap(mktId, 1e18);

        v.submit(abi.encodeCall(v.setForceDeallocatePenalty, (adapter, PENALTY)));
        v.setForceDeallocatePenalty(adapter, PENALTY);

        // 3) PA allocator on V2 (if supported as allocator)
        v.submit(abi.encodeCall(v.setIsAllocator, (PA, true)));
        v.setIsAllocator(PA, true);

        // 6) Dead deposit (requires WETH on hot)
        if (IERC20M(WETH).balanceOf(HOT) < DEAD_AMT) {
            IERC20M(WETH).deposit{value: DEAD_AMT}();
        }
        IERC20M(WETH).approve(vault, DEAD_AMT);
        v.deposit(DEAD_AMT, DEAD);

        vm.stopBroadcast();

        console2.log("VaultV2 yELEPAN-WETH", vault);
        console2.log("Adapter", adapter);
        console2.log("Registry", ADAPTER_REGISTRY);
        console2.log("owner", v.owner());
        console2.log("curator", v.curator());
        console2.log("NOTE: PA flow caps are MetaMorpho-specific; V2 uses absolute/relative caps above");
    }
}
