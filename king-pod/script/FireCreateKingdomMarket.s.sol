// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoFactory {
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address metaMorpho);
}

interface IMetaMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setCurator(address) external;
    function setIsAllocator(address, bool) external;
    function setFeeRecipient(address) external;
    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setSupplyQueue(bytes32[] calldata) external;
    function timelock() external view returns (uint256);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
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

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

interface IMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory) external;
    function idToMarketParams(bytes32)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice CREATE the market — do not wait. Timelock-0 vault → instant WETH+ELE caps.
/// @dev KING_GO=1 FIRE_CREATE_MARKET=1
///      Bypasses yELE pending acceptCap (~38h). PA reallocateTo still needs vault USDC supply.
contract FireCreateKingdomMarket is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant ELE_USDC_77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC_86 = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;
    uint256 constant CAP = 50_000_000e6;
    uint128 constant FLOW = 700_000e6;
    uint256 constant MIN_ETH = 2e14; // keep gas

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CREATE_MARKET", uint256(0)) == 1, "NEED FIRE_CREATE_MARKET=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(HOT.balance >= MIN_ETH, "GAS_FLOOR");

        bytes32 salt = keccak256(abi.encodePacked("KingdomElepanUSDC-v1", HOT, block.chainid));

        IMetaMorphoC.MarketParams memory eleMp =
            IMetaMorphoC.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMetaMorphoC.MarketParams memory wethMp =
            IMetaMorphoC.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86);

        vm.startBroadcast(pk);

        // Optional: ensure Morpho Blue markets exist (permissionless if IRM/LLTV enabled).
        _ensureMarket(IMorphoC.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77));
        _ensureMarket(IMorphoC.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86));

        address vault = IMetaMorphoFactory(FACTORY).createMetaMorpho(
            HOT,
            0, // TIMELOCK 0 — acceptCap is instant (curator create-market path)
            USDC,
            "Kingdom Elepan USDC",
            "yELE-K",
            salt
        );
        console2.log("vault", vault);

        IMetaMorphoC mm = IMetaMorphoC(vault);
        mm.setCurator(HOT);
        mm.setIsAllocator(HOT, true);
        mm.setIsAllocator(PA, true);
        mm.setFeeRecipient(LAND);

        // Instant enable — no 38h wait.
        mm.submitCap(wethMp, CAP);
        mm.acceptCap(wethMp);
        mm.submitCap(eleMp, CAP);
        mm.acceptCap(eleMp);

        bytes32[] memory q = new bytes32[](2);
        q[0] = WETH_USDC_86;
        q[1] = ELE_USDC_77;
        mm.setSupplyQueue(q);

        IPublicAllocatorC.FlowCapsConfig[] memory caps = new IPublicAllocatorC.FlowCapsConfig[](2);
        caps[0] = IPublicAllocatorC.FlowCapsConfig({
            id: WETH_USDC_86, caps: IPublicAllocatorC.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        caps[1] = IPublicAllocatorC.FlowCapsConfig({
            id: ELE_USDC_77, caps: IPublicAllocatorC.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPublicAllocatorC(PA).setFlowCaps(vault, caps);

        vm.stopBroadcast();

        require(mm.timelock() == 0, "TL");
        (, bool wethOn,) = mm.config(WETH_USDC_86);
        (, bool eleOn,) = mm.config(ELE_USDC_77);
        require(wethOn && eleOn, "CAPS");
        console2.log("wethOn", wethOn ? uint256(1) : uint256(0));
        console2.log("eleOn", eleOn ? uint256(1) : uint256(0));
        console2.log("landingFeeRecipient", LAND);
        console2.log("CREATE_MARKET_OK", uint256(1));
    }

    function _ensureMarket(IMorphoC.MarketParams memory mp) internal {
        bytes32 id = keccak256(abi.encode(mp));
        (address loan,,,,) = IMorphoC(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoC(MORPHO).createMarket(mp);
            console2.log("createdBlueMarket");
            console2.logBytes32(id);
        }
    }
}
