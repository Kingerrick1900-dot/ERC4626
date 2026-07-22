// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deposit() external payable; // WETH
    function withdraw(uint256) external; // WETH
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function accrueInterest(MarketParams memory marketParams) external;
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
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

interface IYrssF {
    function maxRedeem(address) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

/// @notice King order: FREE ALL Morpho-locked RSS to hot.
/// @dev Pays ~$1 dust debt by swapping a sliver of hot ETH/WETH → USDC (UniV3), then repay + withdrawCollateral.
///      Does NOT touch V1 KingPair (no release path). Does NOT re-lock.
contract FireFreeAllMorphoDust is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481; // SwapRouter02 Base
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // Keep ETH for gas; wrap/swap the rest toward ≥ $1.05 USDC
    uint256 constant ETH_GAS_RESERVE = 0.00012 ether;
    uint256 constant WETH_TO_SWAP = 0.00055 ether;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FREE_ALL", uint256(0)) == 1, "NEED FREE_ALL=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoF.MarketParams memory mp =
            IMorphoF.MarketParams({loanToken: USDC, collateralToken: RSS, oracle: ORACLE, irm: IRM, lltv: LLTV});

        (, uint128 borBefore, uint128 collBefore) = IMorphoF(MORPHO).position(RSS_M, HOT);
        console2.log("borSharesBefore", uint256(borBefore));
        console2.log("collBefore", uint256(collBefore));
        console2.log("rssBefore", IERC20F(RSS).balanceOf(HOT));
        console2.log("ethBefore", HOT.balance);
        console2.log("wethBefore", IERC20F(WETH).balanceOf(HOT));

        vm.startBroadcast(pk);

        IMorphoF(MORPHO).accrueInterest(mp);
        (, uint128 bor, uint128 coll) = IMorphoF(MORPHO).position(RSS_M, HOT);

        if (bor > 0) {
            (,, uint128 tba, uint128 tbs,,) = IMorphoF(MORPHO).market(RSS_M);
            uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
            console2.log("debtUsdc", debt);

            // Ensure enough WETH to swap
            uint256 wethBal = IERC20F(WETH).balanceOf(HOT);
            if (wethBal < WETH_TO_SWAP) {
                uint256 need = WETH_TO_SWAP - wethBal;
                require(HOT.balance >= need + ETH_GAS_RESERVE, "ETH_LOW");
                IERC20F(WETH).deposit{value: need}();
            }

            uint256 swapIn = IERC20F(WETH).balanceOf(HOT);
            if (swapIn > WETH_TO_SWAP) swapIn = WETH_TO_SWAP;
            require(swapIn >= WETH_TO_SWAP, "WETH_SHORT");

            IERC20F(WETH).approve(SWAP_ROUTER, swapIn);
            uint256 usdcOut = ISwapRouter02(SWAP_ROUTER).exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: USDC,
                    fee: 500,
                    recipient: HOT,
                    amountIn: swapIn,
                    amountOutMinimum: debt, // at least cover debt
                    sqrtPriceLimitX96: 0
                })
            );
            console2.log("usdcFromSwap", usdcOut);
            require(IERC20F(USDC).balanceOf(HOT) >= debt, "USDC_SHORT");

            IERC20F(USDC).approve(MORPHO, type(uint256).max);
            IMorphoF(MORPHO).repay(mp, 0, bor, HOT, "");
        }

        (, , uint128 collNow) = IMorphoF(MORPHO).position(RSS_M, HOT);
        if (collNow > 0) {
            IMorphoF(MORPHO).withdrawCollateral(mp, collNow, HOT, HOT);
        }

        // Dust yRSS → USDC if now liquid (do not recycle)
        uint256 maxR = IYrssF(YRSS).maxRedeem(HOT);
        if (maxR > 0) {
            IYrssF(YRSS).redeem(maxR, HOT, HOT);
        }

        vm.stopBroadcast();

        (, uint128 borAfter, uint128 collAfter) = IMorphoF(MORPHO).position(RSS_M, HOT);
        console2.log("borSharesAfter", uint256(borAfter));
        console2.log("collAfter", uint256(collAfter));
        console2.log("rssAfter", IERC20F(RSS).balanceOf(HOT));
        console2.log("usdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("ethAfter", HOT.balance);
        console2.log("yrssSharesAfter", IYrssF(YRSS).balanceOf(HOT));
        console2.log("FREE_ALL_DONE", collAfter == 0 && borAfter == 0 ? uint256(1) : uint256(0));
    }
}
