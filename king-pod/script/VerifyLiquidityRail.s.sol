// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20V {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoV {
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IPublicAllocatorV {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IPsmV {
    function reserves() external view returns (uint256 usdcBal, uint256 eusdBal);
    function paused() external view returns (bool);
    function feeBps() external view returns (uint16);
}

interface ICdpV {
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function eusd() external view returns (address);
}

interface IVaultV {
    function totalAssets() external view returns (uint256);
}

/// @notice Read-only Alpha/Bravo/Charlie preflight for WETH/cbBTC liquidity rail.
/// @dev KING_GO=1 forge script script/VerifyLiquidityRail.s.sol:VerifyLiquidityRail --rpc-url $BASE_RPC_URL
contract VerifyLiquidityRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant EXTRACTOR = 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant PSM = 0x9199E5099C2C46A688F982E377a146Ab6db8060b;
    address constant WETH_CDP = 0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF;
    address constant CBBTC_CDP = 0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5;
    address constant UNI_WETH = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant UNI_CBBTC = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK_P = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant STEAK_HY = 0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F;

    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    uint256 constant LLTV_77_WAD = 770000000000000000;
    uint256 constant ASK_DEFAULT = 500_000e6;

    function run() external view {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 ask = vm.envOr("ASK_USDC", ASK_DEFAULT);

        console2.log("=== LIQUIDITY RAIL PREFLIGHT ===");
        console2.log("askUsdc", ask);

        // --- Bravo: ELE treasury ---
        uint256 eleFree = IERC20V(ELE).balanceOf(HOT);
        (, uint128 eleBorrowShares, uint128 eleColl) = IMorphoV(MORPHO).position(ELE77, HOT);
        (uint128 eleSupAssets,, uint128 eleBorAssets,,,) = IMorphoV(MORPHO).market(ELE77);
        uint256 eleIdle = uint256(eleSupAssets) > uint256(eleBorAssets)
            ? uint256(eleSupAssets) - uint256(eleBorAssets)
            : 0;
        // Soft $1 oracle: coll 8dp → USD 6dp = coll * 1e6 / 1e8 = coll / 100
        uint256 collUsd6 = uint256(eleColl) / 100;
        uint256 maxBorrow77 = (collUsd6 * LLTV_77_WAD) / 1e18;
        uint256 headroom = maxBorrow77 > uint256(eleBorAssets) ? maxBorrow77 - uint256(eleBorAssets) : 0;

        console2.log("--- BRAVO ELE ---");
        console2.log("eleFree8dp", eleFree);
        console2.log("ele77Coll8dp", uint256(eleColl));
        console2.log("ele77BorrowAssets", uint256(eleBorAssets));
        console2.log("ele77SupplyAssets", uint256(eleSupAssets));
        console2.log("ele77Idle", eleIdle);
        console2.log("ele77Headroom77", headroom);
        console2.log("ele77BorrowShares", uint256(eleBorrowShares));

        // --- Alpha: WETH/cbBTC inventory + CDPs + Uni depth ---
        uint256 wethBal = IERC20V(WETH).balanceOf(HOT) + HOT.balance; // ETH wrappable
        uint256 cbbtcBal = IERC20V(CBBTC).balanceOf(HOT);
        uint256 uniWethUsdc = IERC20V(USDC).balanceOf(UNI_WETH);
        uint256 uniCbbtcUsdc = IERC20V(USDC).balanceOf(UNI_CBBTC);
        (uint128 wSup,, uint128 wBor,,,) = IMorphoV(MORPHO).market(WETH_M);
        (uint128 bSup,, uint128 bBor,,,) = IMorphoV(MORPHO).market(CBBTC_M);
        uint256 wethIdle = uint256(wSup) > uint256(wBor) ? uint256(wSup) - uint256(wBor) : 0;
        uint256 cbbtcIdle = uint256(bSup) > uint256(bBor) ? uint256(bSup) - uint256(bBor) : 0;

        console2.log("--- ALPHA LIQUIDITY ---");
        console2.log("hotWethPlusEth", wethBal);
        console2.log("hotCbbtc", cbbtcBal);
        console2.log("uniWethUsdcDepth", uniWethUsdc);
        console2.log("uniCbbtcUsdcDepth", uniCbbtcUsdc);
        console2.log("morphoWethIdle", wethIdle);
        console2.log("morphoCbbtcIdle", cbbtcIdle);
        console2.log("wethCdpColl", ICdpV(WETH_CDP).coll());
        console2.log("wethCdpDebt", ICdpV(WETH_CDP).accruedDebt());
        console2.log("cbbtcCdpColl", ICdpV(CBBTC_CDP).coll());
        console2.log("cbbtcCdpDebt", ICdpV(CBBTC_CDP).accruedDebt());
        console2.log("wethCdpEusdOk", ICdpV(WETH_CDP).eusd() == EUSD ? uint256(1) : uint256(0));
        console2.log("cbbtcCdpEusdOk", ICdpV(CBBTC_CDP).eusd() == EUSD ? uint256(1) : uint256(0));

        (uint256 psmUsdc, uint256 psmEusd) = IPsmV(PSM).reserves();
        console2.log("psmUsdc", psmUsdc);
        console2.log("psmEusd", psmEusd);
        console2.log("psmPaused", IPsmV(PSM).paused() ? uint256(1) : uint256(0));
        console2.log("psmFeeBps", uint256(IPsmV(PSM).feeBps()));

        // --- Charlie: PA doors + borrow prudence ---
        console2.log("--- CHARLIE CREDIT ---");
        _logPa("YELE", YELE);
        _logPa("GAUNTLET", GAUNTLET);
        _logPa("STEAK_P", STEAK_P);
        _logPa("STEAK", STEAK);
        _logPa("STEAK_HY", STEAK_HY);

        uint256 landUsdc = IERC20V(USDC).balanceOf(LANDING);
        uint256 hotUsdc = IERC20V(USDC).balanceOf(HOT);
        console2.log("landingUsdc", landUsdc);
        console2.log("hotUsdc", hotUsdc);
        console2.log("extractor", EXTRACTOR);

        // --- Gates ---
        // Inventory must cover ask at conservative prices (ETH~$3000, BTC~$100k) with 20% buffer.
        // Dust ETH/cbBTC must NOT arm a $500k rail.
        uint256 wethUsd6 = (wethBal * 3000e6) / 1e18;
        uint256 cbbtcUsd6 = (cbbtcBal * 100_000e6) / 1e8;
        uint256 inventoryUsd6 = wethUsd6 + cbbtcUsd6;
        bool depthOk = uniWethUsdc >= (ask * 12) / 10 || uniCbbtcUsdc >= (ask * 12) / 10;
        bool inventoryOk = inventoryUsd6 >= (ask * 12) / 10;
        bool psmOk = psmUsdc >= ask;
        bool idleOk = eleIdle >= ask;
        bool headroomOk = headroom >= ask;
        // PA door alone is insufficient — vault must also hold assets that can move.
        uint256 yeleAssets = IERC20V(YELE).balanceOf(HOT);
        uint256 yeleTotal = IVaultV(YELE).totalAssets();
        // Foreign PA doors need maxIn ≥ ask (liquidity lives in those vaults). Kingdom yELE also needs assets.
        bool paDoor = (_maxIn(YELE) >= ask && yeleTotal >= ask) || _maxIn(GAUNTLET) >= ask
            || _maxIn(STEAK_P) >= ask || _maxIn(STEAK) >= ask || _maxIn(STEAK_HY) >= ask;

        bool alphaSwapReady = inventoryOk && depthOk;
        bool alphaPsmReady = inventoryOk && psmOk; // CDP mint then PSM
        bool charlieBorrowReady = idleOk && headroomOk;

        console2.log("inventoryUsd6", inventoryUsd6);
        console2.log("yeleTotalAssets", yeleTotal);
        console2.log("yeleSharesOnHot", yeleAssets);

        console2.log("--- GATES ---");
        console2.log("GATE_DEPTH_OK", depthOk ? uint256(1) : uint256(0));
        console2.log("GATE_INVENTORY_OK", inventoryOk ? uint256(1) : uint256(0));
        console2.log("GATE_PSM_USDC_OK", psmOk ? uint256(1) : uint256(0));
        console2.log("GATE_ELE77_IDLE_OK", idleOk ? uint256(1) : uint256(0));
        console2.log("GATE_ELE77_HEADROOM_OK", headroomOk ? uint256(1) : uint256(0));
        console2.log("GATE_PA_DOOR_OK", paDoor ? uint256(1) : uint256(0));
        console2.log("ALPHA_SWAP_READY", alphaSwapReady ? uint256(1) : uint256(0));
        console2.log("ALPHA_PSM_READY", alphaPsmReady ? uint256(1) : uint256(0));
        console2.log("CHARLIE_BORROW_READY", charlieBorrowReady ? uint256(1) : uint256(0));
        console2.log(
            "RAIL_FIRE_ALLOWED",
            (alphaSwapReady || alphaPsmReady || charlieBorrowReady) ? uint256(1) : uint256(0)
        );
        console2.log("ELE_IS_NOT_LIQUIDITY_INSTRUMENT", uint256(1));
    }

    function _logPa(string memory name, address vault) internal view {
        (uint128 maxIn, uint128 maxOut) = IPublicAllocatorV(PA).flowCaps(vault, ELE77);
        console2.log(name);
        console2.log("  maxIn", uint256(maxIn));
        console2.log("  maxOut", uint256(maxOut));
    }

    function _maxIn(address vault) internal view returns (uint256) {
        (uint128 maxIn,) = IPublicAllocatorV(PA).flowCaps(vault, ELE77);
        return uint256(maxIn);
    }
}
