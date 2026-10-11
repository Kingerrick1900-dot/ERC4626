// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function deposit() external payable;
}

interface ISwapRouter02P {
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

interface ICreditP {
    function supply(uint256 amt) external;
    function setOperator(address op, bool allowed) external;
    function operatorBorrowTo(address to, uint256 amt) external;
    function maxBorrow(address user) external view returns (uint256);
    function operator(address) external view returns (bool);
    function totalSupplyUsdc() external view returns (uint256);
    function totalDebt() external view returns (uint256);
}

interface IQuoterV2P {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160, uint32, uint256);
}

/// @notice Finish path: desk MATIC -> native USDC -> Credit supply -> borrow to HOT (Polygon).
/// Gate: FIRE_POLY_USDC=1. Leaves 0.2 MATIC gas on desk.
contract FirePolyEthToUsdcCredit is Script {
    address constant DESK = 0x31511861a519D6b814Eb20b4A0bcc391e76177dF;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant QUOTER = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address constant CREDIT = 0xe8EF9f6d240A2B8eF4D4e24Ffc360d6E4C703B18;
    uint24 constant FEE = 500;
    uint256 constant GAS_RESERVE = 0.55 ether; // cover Polygon gas for wrap+swap+supply+borrow

    function run() external {
        require(vm.envOr("FIRE_POLY_USDC", uint256(0)) == 1, "FIRE_POLY_USDC");
        uint256 pk = vm.envUint("POLY_KEY");
        require(vm.addr(pk) == DESK, "NOT_DESK");

        uint256 ethBal = DESK.balance;
        require(ethBal > GAS_RESERVE + 0.01 ether, "LOW_ETH");
        uint256 swapEth = ethBal - GAS_RESERVE;

        (uint256 quoted,,,) = IQuoterV2P(QUOTER).quoteExactInputSingle(
            IQuoterV2P.QuoteExactInputSingleParams({
                tokenIn: WMATIC, tokenOut: USDC, amountIn: swapEth, fee: FEE, sqrtPriceLimitX96: 0
            })
        );
        uint256 minOut = (quoted * 95) / 100; // 5% slip - thin MATIC book
        console2.log("swapMatic", swapEth);
        console2.log("quotedUsdc", quoted);
        console2.log("minOut", minOut);

        vm.startBroadcast(pk);

        IERC20P(WMATIC).deposit{value: swapEth}();
        IERC20P(WMATIC).approve(ROUTER, swapEth);
        uint256 out = ISwapRouter02P(ROUTER).exactInputSingle(
            ISwapRouter02P.ExactInputSingleParams({
                tokenIn: WMATIC,
                tokenOut: USDC,
                fee: FEE,
                recipient: DESK,
                amountIn: swapEth,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            })
        );
        console2.log("usdcOut", out);

        uint256 usdcBal = IERC20P(USDC).balanceOf(DESK);
        IERC20P(USDC).approve(CREDIT, usdcBal);
        ICreditP(CREDIT).supply(usdcBal);
        console2.log("supplied", usdcBal);

        if (!ICreditP(CREDIT).operator(DESK)) {
            ICreditP(CREDIT).setOperator(DESK, true);
        }
        uint256 maxB = ICreditP(CREDIT).maxBorrow(HOT);
        uint256 free = ICreditP(CREDIT).totalSupplyUsdc() - ICreditP(CREDIT).totalDebt();
        uint256 ask = maxB < free ? maxB : free;
        console2.log("maxBorrow", maxB);
        console2.log("free", free);
        if (ask > 0) {
            ICreditP(CREDIT).operatorBorrowTo(HOT, ask);
            console2.log("borrowedToHot", ask);
        }

        vm.stopBroadcast();

        console2.log("deskEthLeft", DESK.balance);
        console2.log("hotUsdcPoly", IERC20P(USDC).balanceOf(HOT));
        console2.log("MISSION poly ETH to USDC Credit fired");
    }
}
