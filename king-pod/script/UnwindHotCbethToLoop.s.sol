// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, Route[] calldata routes) external view returns (uint256[] memory amounts);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMetaMorpho {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @notice Unstick hot cbETH carry → repay → withdraw → Aero ETH → send to LOOP ops wallet.
/// @dev Hot is EIP-7702 delegated. Prefer cast one-tx-at-a-time with padded gas, or
///      `forge script --broadcast --slow --gas-estimate-multiplier 200`. Parallel forge
///      batches hit "gapped-nonce / in-flight limit" and under-gas OOG on Base.
contract UnwindHotCbethToLoop is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LOOP = 0x8d3cfbFc6A276f118579517E4d166e94C66F8585;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant ORACLE = 0xb40d93F44411D8C09aD17d7F88195eF9b05cCD96;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;
    bytes32 constant MID = 0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad;
    uint256 constant USDC_FLOOR = 1e6;
    uint256 constant GAS_KEEP = 0.00015 ether;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address king = vm.addr(pk);
        require(king == HOT, "MUST_HOT_TO_UNWIND");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: CBETH,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        (, uint128 borrowShares, uint128 coll) = IMorpho(MORPHO).position(MID, HOT);
        require(borrowShares > 0 || coll > 0, "NO_POS");
        (,, uint128 borrowAssetsTotal, uint128 borrowSharesTotal,,) = IMorpho(MORPHO).market(MID);
        uint256 debt = borrowSharesTotal == 0
            ? 0
            : (uint256(borrowAssetsTotal) * uint256(borrowShares) + uint256(borrowSharesTotal) - 1)
                / uint256(borrowSharesTotal);

        uint256 hotUsdc = IERC20(USDC).balanceOf(HOT);
        // +1 USDC headroom so mid-tx interest cannot undershoot repay transferFrom
        uint256 debtWithBuf = debt + 1e6;
        uint256 maxW = IMetaMorpho(YRSS).maxWithdraw(HOT);
        uint256 need = debtWithBuf > hotUsdc ? debtWithBuf - hotUsdc : 0;
        if (need > maxW) need = maxW; // take all free vault liq; still must cover debt
        console2.log("coll", uint256(coll));
        console2.log("debtUSDC", debt);
        console2.log("needFromYrss", need);
        console2.log("maxWithdraw", maxW);

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: CBETH, to: WETH, stable: false, factory: AERO_FACTORY});

        vm.startBroadcast(pk);

        if (need > 0) {
            IMetaMorpho(YRSS).withdraw(need, HOT, HOT);
        }

        uint256 bal = IERC20(USDC).balanceOf(HOT);
        require(bal >= debt + 1, "USDC_SHORT");
        IERC20(USDC).approve(MORPHO, bal);
        // Re-read shares after vault withdraw (interest may have accrued), close by shares.
        (, uint128 sharesNow,) = IMorpho(MORPHO).position(MID, HOT);
        if (sharesNow > 0) {
            IMorpho(MORPHO).repay(mp, 0, sharesNow, HOT, "");
        }

        (, uint128 b2, uint128 c2) = IMorpho(MORPHO).position(MID, HOT);
        require(b2 == 0, "DEBT_LEFT");
        if (c2 > 0) {
            IMorpho(MORPHO).withdrawCollateral(mp, c2, HOT, HOT);
        }

        uint256 cbBal = IERC20(CBETH).balanceOf(HOT);
        require(cbBal > 0, "NO_CBETH");
        uint256[] memory quoted = IAeroRouter(AERO).getAmountsOut(cbBal, routes);
        uint256 minOut = (quoted[1] * 95) / 100;
        IERC20(CBETH).approve(AERO, cbBal);
        IAeroRouter(AERO).swapExactTokensForETH(cbBal, minOut, routes, HOT, block.timestamp + 20 minutes);

        // Send ETH to loop, keep gas on hot
        uint256 ethBal = HOT.balance;
        require(ethBal > GAS_KEEP, "ETH_DUST");
        uint256 sendAmt = ethBal - GAS_KEEP;
        (bool ok,) = LOOP.call{value: sendAmt}("");
        require(ok, "SEND_LOOP");

        vm.stopBroadcast();

        console2.log("sentETH", sendAmt);
        console2.log("hotEthLeft", HOT.balance);
        console2.log("loopEth", LOOP.balance);
        console2.log("hotUsdc", IERC20(USDC).balanceOf(HOT));
    }
}
