// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IVaultY {
    function totalAssets() external view returns (uint256);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address) external view returns (bool);
    function feeRecipient() external view returns (address);
    function fee() external view returns (uint96);
    function supplyQueue(uint256) external view returns (bytes32);
    function withdrawQueue(uint256) external view returns (bytes32);
    function withdrawQueueLength() external view returns (uint256);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function reallocate(MarketAllocation[] calldata allocations) external;
}

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

interface IMorphoY {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice PREP: report yRSS curator allocation + optional reallocate to cbBTC/WETH.
/// @dev Default no broadcast. LIVE_ARMED=1 KING_GO=1 FIRE_YRSS_CURATOR=1 to reallocate.
contract FireYrssCuratorPrep is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant RSS915 = 0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126;
    bytes32 constant CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    bytes32 constant ELE = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        bool liveArmed = vm.envOr("LIVE_ARMED", uint256(0)) == 1;
        bool kingGo = vm.envOr("KING_GO", uint256(0)) == 1;
        bool fire = vm.envOr("FIRE_YRSS_CURATOR", uint256(0)) == 1;
        bool doBroadcast = liveArmed && kingGo && fire;

        IVaultY v = IVaultY(YRSS);
        console2.log("=== yRSS CURATOR PREP ===");
        console2.log("totalAssets", v.totalAssets());
        console2.log("owner", v.owner());
        console2.log("curator", v.curator());
        console2.log("allocatorHot", v.isAllocator(HOT) ? uint256(1) : uint256(0));
        console2.log("feeRecipient", v.feeRecipient());
        console2.log("feeToLanding", v.feeRecipient() == LANDING ? uint256(1) : uint256(0));
        console2.log("feeWad", uint256(v.fee()));

        _logMarket("RSS77", RSS77);
        _logMarket("RSS915", RSS915);
        _logMarket("cbBTC", CBBTC);
        _logMarket("WETH", WETH);
        _logMarket("BRETT", BRETT);
        _logMarket("ELE", ELE);

        console2.log("supplyQueue");
        for (uint256 i; i < 8; i++) {
            try v.supplyQueue(i) returns (bytes32 id) {
                console2.log(i, uint256(id));
            } catch {
                break;
            }
        }

        console2.log("--- CUSTOMIZE TARGET (when TVL real) ---");
        console2.log("1 reallocate BRETT -> cbBTC then WETH");
        console2.log("2 keep fee Landing");
        console2.log("3 do NOT list ELE for KEEP recycle");
        console2.log("4 Morpho loan separate: borrowPortion -> Landing");

        if (!doBroadcast) {
            console2.log("PREP_ONLY_OK", uint256(1));
            console2.log("NO_BROADCAST", uint256(1));
            return;
        }

        // Only meaningful once TVL >> dust; still gated.
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(v.isAllocator(HOT), "NOT_ALLOCATOR");

        uint256 tvl = v.totalAssets();
        require(tvl >= 1_000e6, "TVL_DUST: fund vault before reallocate");

        // Target: pull BRETT to 0; park in cbBTC then WETH catcher pattern via reallocate
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoY(MORPHO).idToMarketParams(BRETT);
        (address loan2, address coll2, address oracle2, address irm2, uint256 lltv2) =
            IMorphoY(MORPHO).idToMarketParams(CBBTC);
        (address loan3, address coll3, address oracle3, address irm3, uint256 lltv3) =
            IMorphoY(MORPHO).idToMarketParams(WETH);

        MarketAllocation[] memory alloc = new MarketAllocation[](3);
        alloc[0] = MarketAllocation({
            marketParams: MarketParams(loan, coll, oracle, irm, lltv),
            assets: 0
        });
        alloc[1] = MarketAllocation({
            marketParams: MarketParams(loan2, coll2, oracle2, irm2, lltv2),
            assets: (tvl * 60) / 100
        });
        alloc[2] = MarketAllocation({
            marketParams: MarketParams(loan3, coll3, oracle3, irm3, lltv3),
            assets: type(uint256).max // catcher
        });

        vm.startBroadcast(pk);
        v.reallocate(alloc);
        vm.stopBroadcast();
        console2.log("YRSS_REALLOC_CBBTC_WETH_OK", uint256(1));
    }

    function _logMarket(string memory name, bytes32 id) internal view {
        (uint184 cap, bool en,) = IVaultY(YRSS).config(id);
        (uint256 shares,,) = IMorphoY(MORPHO).position(id, YRSS);
        (uint128 sa, uint128 ss,,,,) = IMorphoY(MORPHO).market(id);
        uint256 assets;
        if (shares > 0 && ss > 0) assets = (uint256(sa) * shares) / uint256(ss);
        console2.log(name);
        console2.log(" enabled", en ? uint256(1) : uint256(0));
        console2.log(" cap", uint256(cap));
        console2.log(" vaultAssets", assets);
    }
}
