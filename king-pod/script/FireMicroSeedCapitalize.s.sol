// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

interface IPool {
    function slot0()
        external
        view
        returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
    function tickSpacing() external view returns (int24);
}

interface IHook {
    function pushObservation(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) external;
}

interface IPor {
    function bumpRound() external;
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80);
}

interface IVault {
    function requestRedeem(uint256 assets, address controller, address owner) external returns (uint256);
    function setOperator(address operator, bool approved) external returns (bool);
}

interface IPsm {
    function seedUsdc(uint256 amt) external;
    function usdcReserve() external view returns (uint256);
}

/// @notice Capitalization fire: Base micro-seed LP + hook obs + PoR bump; Scroll queue seed.
/// @dev KING_GO=1 FIRE_MICRO_BASE=1 | FIRE_MICRO_SCROLL=1
contract FireMicroSeedCapitalize is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant USDC_B = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD_B = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC_S = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant EUSD_S = 0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant POOL_500 = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666;
    address constant HOOK = 0xD439DC646C807BFa704EE726fD9fCcfFde6605a7;
    address constant ELE_POR = 0x3640f1CC913B772EA4D9BDF96a67196590058379;
    address constant GOLD_POR = 0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59;
    address constant VAULT = 0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D;
    address constant PSM = 0x064489A287448674AA1dC6fb740d2F518CBA75dA;
    address constant MAKER = 0xfFEd7981f924Edc652E9b767aCa601505dfa4977;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        if (vm.envOr("FIRE_MICRO_BASE", uint256(0)) == 1) _base();
        if (vm.envOr("FIRE_MICRO_SCROLL", uint256(0)) == 1) _scroll();
    }

    function _base() internal {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 usdcBal = IERC20M(USDC_B).balanceOf(HOT);
        uint256 seedUsdc = usdcBal > 1e6 ? 1e6 : usdcBal; // up to $1
        require(seedUsdc >= 100_000, "NEED_USDC"); // ≥ $0.10
        uint256 seedEusd = seedUsdc * 1e12; // $1 match

        (uint160 sqrtP, int24 tick,,,,,) = IPool(POOL_500).slot0();
        int24 spacing = IPool(POOL_500).tickSpacing();
        int24 aligned = tick / spacing * spacing;
        if (tick < 0 && tick % spacing != 0) aligned -= spacing;
        int24 width = spacing * 10; // ±10 spacings
        int24 tl = aligned - width;
        int24 tu = aligned + width;

        console2.log("tick", uint256(int256(tick)));
        console2.log("seedUsdc", seedUsdc);
        console2.log("seedEusd", seedEusd);

        vm.startBroadcast(pk);

        IERC20M(USDC_B).approve(NPM, seedUsdc);
        IERC20M(EUSD_B).approve(NPM, seedEusd);

        (uint256 tokenId, uint128 liq, uint256 a0, uint256 a1) = INonfungiblePositionManager(NPM).mint(
            INonfungiblePositionManager.MintParams({
                token0: USDC_B,
                token1: EUSD_B,
                fee: 500,
                tickLower: tl,
                tickUpper: tu,
                amount0Desired: seedUsdc,
                amount1Desired: seedEusd,
                amount0Min: 0,
                amount1Min: 0,
                recipient: HOT,
                deadline: block.timestamp + 1 hours
            })
        );

        console2.log("tokenId", tokenId);
        console2.log("liquidity", uint256(liq));
        console2.log("amount0", a0);
        console2.log("amount1", a1);

        // Feed v4 hook reference plane (solver-readable)
        bytes32 hookPoolId = keccak256(abi.encode(USDC_B, EUSD_B, uint24(500), spacing, HOOK));
        IHook(HOOK).pushObservation(hookPoolId, sqrtP, tick);

        // Heartbeat PoR
        IPor(ELE_POR).bumpRound();

        // Leftover USDC dust → Maker PSM seed
        uint256 left = IERC20M(USDC_B).balanceOf(HOT);
        if (left > 0) {
            IERC20M(USDC_B).approve(MAKER, left);
            // seedUsdc on Maker PSM
            (bool ok,) = MAKER.call(abi.encodeWithSignature("seedUsdc(uint256)", left));
            console2.log("makerSeed", ok ? left : 0);
        }

        vm.stopBroadcast();

        (, int256 ans,,,) = IPor(ELE_POR).latestRoundData();
        console2.log("elePorAnswer", uint256(ans));
        console2.log("MICRO_BASE_OK", uint256(1));
    }

    function _scroll() internal {
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");

        // Micro-queue: 1 eUSD into ERC-7540 (solver-visible pending redeem)
        uint256 qAmt = vm.envOr("QUEUE_EUSD", uint256(1e18));
        uint256 usdcOnHot = IERC20M(USDC_S).balanceOf(SCROLL_HOT);

        vm.startBroadcast(pk);

        IPor(GOLD_POR).bumpRound();

        if (usdcOnHot > 0) {
            IERC20M(USDC_S).approve(PSM, usdcOnHot);
            IPsm(PSM).seedUsdc(usdcOnHot);
            console2.log("psmSeeded", usdcOnHot);
        }

        IERC20M(EUSD_S).approve(VAULT, qAmt);
        uint256 reqId = IVault(VAULT).requestRedeem(qAmt, SCROLL_HOT, SCROLL_HOT);
        console2.log("queueRequestId", reqId);
        console2.log("psmUsdc", IPsm(PSM).usdcReserve());

        vm.stopBroadcast();

        (, int256 gans,,,) = IPor(GOLD_POR).latestRoundData();
        console2.log("goldPorAnswer", uint256(gans));
        console2.log("MICRO_SCROLL_OK", uint256(1));
    }
}
