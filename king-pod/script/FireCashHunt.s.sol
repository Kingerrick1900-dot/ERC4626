// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IMorphoH {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPah {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function fee(address vault) external view returns (uint256);
}

interface IMetah {
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function isAllocator(address) external view returns (bool);
}

interface IERC20H {
    function balanceOf(address) external view returns (uint256);
}

interface IZkH {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

/// @notice Hunt real USDC: vault WETH supply + maxOut + ELE maxIn → PA pull → borrow Landing.
/// @dev KING_GO=1 FIRE_CASH=1 — fires only when a door is fully open. SCAN_ONLY=1 logs ranks.
contract FireCashHunt is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant EXTRACTOR = 0x3734658F1b86bD0EE86b5ac15015fE98B7Ad8947;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK_PRIME = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant MOONWELL = 0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;
    address constant SPARK = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;
    address constant YEARN = 0xef417a2512C5a41f69AE4e021648b69a7CdE5D03;
    address constant GCORE = 0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CASH", uint256(0)) == 1, "NEED FIRE_CASH=1");
        bool scanOnly = vm.envOr("SCAN_ONLY", uint256(0)) == 1;
        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));

        (uint128 sa,, uint128 ba,,,) = IMorphoH(MORPHO).market(WETH_USDC);
        uint256 wethIdle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        (uint128 esa,, uint128 eba,,,) = IMorphoH(MORPHO).market(ELE_USDC);
        uint256 eleIdle = uint256(esa) > uint256(eba) ? uint256(esa) - uint256(eba) : 0;
        console2.log("wethIdle", wethIdle);
        console2.log("eleIdle", eleIdle);
        console2.log("ask", ask);

        address best;
        uint256 bestPull;
        address[7] memory vaults = [GAUNTLET, STEAK_PRIME, STEAK, MOONWELL, SPARK, YEARN, GCORE];
        for (uint256 i; i < vaults.length; i++) {
            (uint256 pullable, uint256 wethAssets, uint128 maxIn, uint128 maxOut, bool eleOn, bool paOn) =
                _rank(vaults[i], ask, wethIdle);
            console2.log("--- vault", vaults[i]);
            console2.log("wethAssets", wethAssets);
            console2.log("maxIn", uint256(maxIn));
            console2.log("maxOut", uint256(maxOut));
            console2.log("eleOn", eleOn ? uint256(1) : uint256(0));
            console2.log("paAlloc", paOn ? uint256(1) : uint256(0));
            console2.log("pullable", pullable);
            if (pullable > bestPull) {
                bestPull = pullable;
                best = vaults[i];
            }
        }
        console2.log("best", best);
        console2.log("bestPull", bestPull);

        if (scanOnly) {
            console2.log("SCAN_ONLY", uint256(1));
            return;
        }

        require(IZkH(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkH(GATE).attestations(HOT);
        require(attest >= IZkH(GATE).minThreshold(), "BELOW_THRESHOLD");
        // Only fire a real door — never broadcast a known empty pull.
        require(best != address(0) && bestPull >= ask, "NO_CASH_DOOR");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 landBefore = IERC20H(USDC).balanceOf(LAND);
        vm.startBroadcast(pk);
        address existing = vm.envOr("EXTRACTOR", EXTRACTOR);
        CrownLeverageExtractor x = existing.code.length > 0
            ? CrownLeverageExtractor(payable(existing))
            : new CrownLeverageExtractor(HOT, LAND);
        console2.log("extractor", address(x));
        if (!IMorphoH(MORPHO).isAuthorized(HOT, address(x))) {
            IMorphoH(MORPHO).setAuthorization(address(x), true);
        }
        uint256 fee = IPah(PA).fee(best);
        uint256 pull = bestPull > ask ? ask : bestPull;
        x.reallocateAndBorrow{value: fee}(best, x.wethUsdcParams(), uint128(pull), 0);
        vm.stopBroadcast();

        uint256 landAfter = IERC20H(USDC).balanceOf(LAND);
        console2.log("landDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("CASH_HUNT_OK", uint256(1));
    }

    function _rank(address vault, uint256 ask, uint256 wethIdle)
        internal
        view
        returns (uint256 pullable, uint256 wethAssets, uint128 maxIn, uint128 maxOut, bool eleOn, bool paOn)
    {
        (uint256 shares,,) = IMorphoH(MORPHO).position(WETH_USDC, vault);
        (uint128 sa, uint128 ss,,,,) = IMorphoH(MORPHO).market(WETH_USDC);
        wethAssets = ss == 0 ? 0 : (uint256(sa) * shares) / uint256(ss);
        (maxIn,) = IPah(PA).flowCaps(vault, ELE_USDC);
        (, maxOut) = IPah(PA).flowCaps(vault, WETH_USDC);
        (, eleOn,) = IMetah(vault).config(ELE_USDC);
        paOn = IMetah(vault).isAllocator(PA);

        if (!eleOn || !paOn || maxIn == 0 || maxOut == 0 || wethAssets == 0) return (0, wethAssets, maxIn, maxOut, eleOn, paOn);
        pullable = ask;
        if (pullable > uint256(maxIn)) pullable = maxIn;
        if (pullable > uint256(maxOut)) pullable = maxOut;
        if (pullable > wethAssets) pullable = wethAssets;
        if (pullable > wethIdle) pullable = wethIdle;
    }
}
