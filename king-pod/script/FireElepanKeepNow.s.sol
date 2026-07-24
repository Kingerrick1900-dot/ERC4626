// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanKeepDraw} from "../src/CrownElepanKeepDraw.sol";

interface IERC20N {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface ICdpN {
    function maxWithdrawable() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function withdraw(uint256 amount) external;
}

interface IMorphoN {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @notice Fulfill Morpho KEEP now: drain thin eUSD/USDC → CDP ELE → blue supply → borrow Landing.
/// @dev KING_GO=1 FIRE_ELE_KEEP=1. No yELE. No recycle.
contract FireElepanKeepNow is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CDP = 0x46b1D159b3a2694e7b70F550b7d5dEf6df451174;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ELE_KEEP", uint256(0)) == 1, "NEED FIRE_ELE_KEEP=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address existing = vm.envOr("KEEP_DRAW", address(0));
        bool drainUni = vm.envOr("DRAIN_UNI", uint256(1)) == 1;
        uint256 pullBps = vm.envOr("CDP_PULL_BPS", uint256(9500));

        uint256 landBefore = IERC20N(USDC).balanceOf(LANDING);
        console2.log("landBefore", landBefore);
        console2.log("hotUsdc", IERC20N(USDC).balanceOf(HOT));

        vm.startBroadcast(pk);

        if (drainUni) {
            _drainUni();
        }

        uint256 maxW = ICdpN(CDP).maxWithdrawable();
        uint256 pull = (maxW * pullBps) / 10_000;
        if (pull > 0) {
            ICdpN(CDP).withdraw(pull);
            console2.log("cdpPulled", pull);
            console2.log("hfAfterPull", ICdpN(CDP).healthFactor());
        }

        CrownElepanKeepDraw drawer;
        if (existing == address(0)) {
            drawer = new CrownElepanKeepDraw(
                GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
            );
            console2.log("keepDraw", address(drawer));
        } else {
            drawer = CrownElepanKeepDraw(existing);
            console2.log("keepDrawExisting", existing);
        }

        if (!IMorphoN(MORPHO).isAuthorized(HOT, address(drawer))) {
            IMorphoN(MORPHO).setAuthorization(address(drawer), true);
        }

        uint256 supplyUsdc = IERC20N(USDC).balanceOf(HOT);
        uint256 postEle = IERC20N(ELEPAN).balanceOf(HOT);

        if (supplyUsdc > 0) IERC20N(USDC).approve(address(drawer), type(uint256).max);
        if (postEle > 0) IERC20N(ELEPAN).approve(address(drawer), type(uint256).max);

        (uint128 s0,, uint128 b0,,,) = IMorphoN(MORPHO).market(ELE_USDC);
        uint256 idle0 = uint256(s0) - uint256(b0);
        console2.log("idleBefore", idle0);
        console2.log("supplyUsdc", supplyUsdc);
        console2.log("postEle", postEle);

        if (supplyUsdc > 0 || idle0 > 0) {
            drawer.drawKeep(supplyUsdc, postEle, 0);
        } else if (postEle > 0) {
            IERC20N(ELEPAN).approve(MORPHO, postEle);
            IMorphoN(MORPHO).supplyCollateral(
                IMorphoN.MarketParams({
                    loanToken: USDC,
                    collateralToken: ELEPAN,
                    oracle: ORACLE,
                    irm: IRM,
                    lltv: LLTV
                }),
                postEle,
                HOT,
                ""
            );
            console2.log("collArmedOnly", postEle);
        }

        vm.stopBroadcast();

        uint256 landAfter = IERC20N(USDC).balanceOf(LANDING);
        (, uint128 bor, uint128 coll) = IMorphoN(MORPHO).position(ELE_USDC, HOT);
        (uint128 s1,, uint128 b1,,,) = IMorphoN(MORPHO).market(ELE_USDC);
        console2.log("landAfter", landAfter);
        console2.log("landDelta", landAfter - landBefore);
        console2.log("morphoColl", uint256(coll));
        console2.log("morphoBorrowShares", uint256(bor));
        console2.log("marketIdle", uint256(s1) - uint256(b1));
        console2.log("KEEP_OK", landAfter > landBefore ? uint256(1) : uint256(0));
    }

    function _drainUni() internal {
        uint256 eusdBal = IERC20N(EUSD).balanceOf(HOT);
        uint256 drainEusd = vm.envOr("DRAIN_EUSD", uint256(100e18));
        if (drainEusd > eusdBal) drainEusd = eusdBal;
        if (drainEusd == 0) return;

        uint256 half = drainEusd / 2;
        IERC20N(EUSD).approve(SWAP_ROUTER, drainEusd);

        if (half > 0) {
            try ISwapRouter02(SWAP_ROUTER).exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: EUSD,
                    tokenOut: USDC,
                    fee: 100,
                    recipient: HOT,
                    amountIn: half,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            ) returns (uint256 out100) {
                console2.log("uni100Out", out100);
            } catch {
                console2.log("uni100Out", uint256(0));
            }
        }

        uint256 left = IERC20N(EUSD).balanceOf(HOT);
        uint256 in500 = half;
        if (in500 > left) in500 = left;
        if (in500 > 0) {
            IERC20N(EUSD).approve(SWAP_ROUTER, in500);
            try ISwapRouter02(SWAP_ROUTER).exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: EUSD,
                    tokenOut: USDC,
                    fee: 500,
                    recipient: HOT,
                    amountIn: in500,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            ) returns (uint256 out500) {
                console2.log("uni500Out", out500);
            } catch {
                console2.log("uni500Out", uint256(0));
            }
        }
    }
}
