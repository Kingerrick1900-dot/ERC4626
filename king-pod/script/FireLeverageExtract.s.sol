// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IMorphoF {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPaf {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
    function fee(address vault) external view returns (uint256);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkF {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256 value, uint256 ts, uint256 flag);
    function minThreshold() external view returns (uint256);
}

interface IMetaF {
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

/// @notice KING_GO=1 FIRE_LEVERAGE=1 — PA pull (if real maxIn+source) + borrow idle → Landing.
/// @dev Use --slow on EIP-7702 hot. Optional PA_VAULT PULL_USDC.
contract FireLeverageExtract is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    uint256 constant LLTV_86 = 860000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK_PRIME = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant MOONWELL = 0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_LEVERAGE", uint256(0)) == 1, "NEED FIRE_LEVERAGE=1");
        require(IZkF(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkF(GATE).attestations(HOT);
        require(attest >= IZkF(GATE).minThreshold(), "BELOW_THRESHOLD");
        console2.log("zkAttestUsdc6", attest);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address vault = vm.envOr("PA_VAULT", address(0));
        uint256 pull = vm.envOr("PULL_USDC", uint256(0));
        bool armOnly = vm.envOr("ARM_ONLY", uint256(0)) == 1;
        bool wantPa = vm.envOr("FORCE_PA", uint256(0)) == 1 || pull > 0 || vault != address(0);

        _logCaps();

        // Foreign curators first. yELE maxIn alone is not enough — needs enabled source market liquidity.
        if (wantPa && vault == address(0)) {
            vault = _firstForeignMaxIn();
            if (vault == address(0)) {
                (, bool wethOn,) = IMetaF(YELE).config(WETH_USDC);
                (uint128 yIn,) = IPaf(PA).flowCaps(YELE, ELE_USDC);
                if (wethOn && yIn > 0) vault = YELE;
            }
            console2.log("autoVault", vault);
        }

        if (vault != address(0) && pull == 0) {
            (uint128 maxIn,) = IPaf(PA).flowCaps(vault, ELE_USDC);
            pull = uint256(maxIn);
        }
        if (vault != address(0) && pull > 0) {
            (uint128 maxIn,) = IPaf(PA).flowCaps(vault, ELE_USDC);
            require(maxIn > 0, "MAXIN_0");
            if (pull > uint256(maxIn)) pull = uint256(maxIn);
        } else {
            pull = 0;
            vault = address(0);
        }

        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("idleBefore", idle);
        console2.log("pull", pull);
        console2.log("vault", vault);
        console2.log("armOnly", armOnly ? uint256(1) : uint256(0));

        if (!armOnly) {
            require(pull > 0 || idle > 1e6, "NO_PA_NO_IDLE");
        }

        uint256 landBefore = IERC20F(USDC).balanceOf(LAND);
        (, , uint128 coll) = IMorphoF(MORPHO).position(ELE_USDC, HOT);
        console2.log("coll", uint256(coll));
        console2.log("landBefore", landBefore);
        // Soft headroom at $1 ELE: collUSD*0.77 - debt
        uint256 collUsd = uint256(coll) / 100;
        uint256 debtUsd = uint256(ba); // approx when util matched; refine via shares if needed
        uint256 headroom = collUsd * 77 / 100 > debtUsd ? collUsd * 77 / 100 - debtUsd : 0;
        console2.log("lltvHeadroomUsdc6", headroom);

        vm.startBroadcast(pk);
        address existing = vm.envOr("EXTRACTOR", address(0));
        CrownLeverageExtractor x = existing == address(0)
            ? new CrownLeverageExtractor(HOT, LAND)
            : CrownLeverageExtractor(payable(existing));
        console2.log("extractor", address(x));
        if (!IMorphoF(MORPHO).isAuthorized(HOT, address(x))) {
            IMorphoF(MORPHO).setAuthorization(address(x), true);
        }

        uint256 freeEle = IERC20F(ELE).balanceOf(HOT);
        if (freeEle > 0) {
            IERC20F(ELE).approve(address(x), type(uint256).max);
            x.depositCollateral(freeEle);
        }

        if (!armOnly) {
            if (pull > 0) {
                uint256 fee = IPaf(PA).fee(vault);
                x.reallocateAndBorrow{value: fee}(vault, x.wethUsdcParams(), uint128(pull), 0);
            } else {
                x.borrowIdle(0);
            }
        } else {
            console2.log("ARMED_WAIT_PA_OR_IDLE", uint256(1));
        }
        vm.stopBroadcast();

        uint256 landAfter = IERC20F(USDC).balanceOf(LAND);
        (uint128 sa2,, uint128 ba2,,,) = IMorphoF(MORPHO).market(ELE_USDC);
        console2.log("idleAfter", uint256(sa2) > uint256(ba2) ? uint256(sa2) - uint256(ba2) : 0);
        console2.log("landAfter", landAfter);
        console2.log("landDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("LEVERAGE_EXTRACT_OK", uint256(1));
    }

    function _firstForeignMaxIn() internal view returns (address) {
        address[4] memory vs = [GAUNTLET, STEAK_PRIME, STEAK, MOONWELL];
        for (uint256 i; i < vs.length; i++) {
            (uint128 maxIn,) = IPaf(PA).flowCaps(vs[i], ELE_USDC);
            if (maxIn > 0) return vs[i];
        }
        return address(0);
    }

    function _logCaps() internal view {
        console2.log("Gauntlet maxIn", uint256(_maxIn(GAUNTLET)));
        console2.log("SteakPrime maxIn", uint256(_maxIn(STEAK_PRIME)));
        console2.log("Steak maxIn", uint256(_maxIn(STEAK)));
        console2.log("Moonwell maxIn", uint256(_maxIn(MOONWELL)));
        console2.log("yELE maxIn", uint256(_maxIn(YELE)));
        (, bool wethOn,) = IMetaF(YELE).config(WETH_USDC);
        console2.log("yELE wethEnabled", wethOn ? uint256(1) : uint256(0));
    }

    function _maxIn(address v) internal view returns (uint128 maxIn) {
        (maxIn,) = IPaf(PA).flowCaps(v, ELE_USDC);
    }
}
