// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function deposit() external payable;
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function accrueInterest(MarketParams memory) external;
}

interface IExtractorF {
    function borrowIdle(uint256 borrowAmt) external;
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

interface ICdpF {
    function deposit(uint256) external;
    function mint(uint256) external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function maxMintable() external view returns (uint256);
}

interface IPsmF {
    function buyUsdc(uint256 eusdIn, address receiver) external returns (uint256);
    function quoteBuyUsdc(uint256 eusdIn) external view returns (uint256 usdcOut, uint256 feeUsdc);
    function reserves() external view returns (uint256 usdcBal, uint256 eusdBal);
    function paused() external view returns (bool);
}

/// @notice Alpha/Charlie liquidity rail — fires only when Verify gates pass.
/// @dev Modes: SWAP | CDP_PSM | BORROW_IDLE | MORPHO_COLL
///      KING_GO=1 FIRE_LIQ_RAIL=1 RAIL_MODE=SWAP ASSET=WETH ASK_USDC=... MAX_SLIPPAGE_BPS=50
contract FireLiquidityRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EXTRACTOR = 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant PSM = 0x9199E5099C2C46A688F982E377a146Ab6db8060b;
    address constant WETH_CDP = 0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF;
    address constant CBBTC_CDP = 0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant CBBTC_ORACLE = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant UNI_WETH = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant UNI_CBBTC = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_86 = 860000000000000000;
    uint256 constant LLTV_77 = 770000000000000000;
    uint24 constant FEE_500 = 500;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_LIQ_RAIL", uint256(0)) == 1, "NEED FIRE_LIQ_RAIL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        string memory mode = vm.envOr("RAIL_MODE", string("SWAP"));
        string memory asset = vm.envOr("ASSET", string("WETH"));
        uint256 ask = vm.envOr("ASK_USDC", uint256(500_000e6));
        uint256 maxSlipBps = vm.envOr("MAX_SLIPPAGE_BPS", uint256(50));

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        console2.log("mode", mode);
        console2.log("asset", asset);
        console2.log("ask", ask);
        console2.log("landBefore", landBefore);

        // Doctrine: never treat ELE as the swap asset.
        require(_neq(asset, "ELE") && _neq(asset, "RSS"), "ELE_NOT_LIQUIDITY");

        vm.startBroadcast(pk);

        if (_eq(mode, "SWAP")) {
            _requireInventoryCoversAsk(asset, ask);
            _swapToLanding(asset, ask, maxSlipBps);
        } else if (_eq(mode, "CDP_PSM")) {
            _requireInventoryCoversAsk(asset, ask);
            _cdpThenPsm(asset, ask);
        } else if (_eq(mode, "BORROW_IDLE")) {
            _borrowIdle(ask);
        } else if (_eq(mode, "MORPHO_COLL")) {
            _requireInventoryCoversAsk(asset, ask);
            _morphoCollBorrow(asset, ask);
        } else {
            revert("BAD_MODE");
        }

        vm.stopBroadcast();

        uint256 landAfter = IERC20F(USDC).balanceOf(LANDING);
        console2.log("landAfter", landAfter);
        console2.log("landDelta", landAfter - landBefore);
        require(landAfter > landBefore, "NO_LANDING_FILL");
        console2.log("LIQ_RAIL_OK", uint256(1));
    }

    function _requireInventoryCoversAsk(string memory asset, uint256 ask) internal view {
        bool isWeth = _eq(asset, "WETH");
        uint256 bal = isWeth ? (IERC20F(WETH).balanceOf(HOT) + (HOT.balance > 0.002 ether ? HOT.balance - 0.002 ether : 0))
            : IERC20F(CBBTC).balanceOf(HOT);
        uint256 usd6 = isWeth ? (bal * 3000e6) / 1e18 : (bal * 100_000e6) / 1e8;
        require(usd6 >= (ask * 12) / 10, "INVENTORY_LT_ASK");
    }

    function _swapToLanding(string memory asset, uint256 ask, uint256 maxSlipBps) internal {
        bool isWeth = _eq(asset, "WETH");
        address tokenIn = isWeth ? WETH : CBBTC;
        address pool = isWeth ? UNI_WETH : UNI_CBBTC;
        uint256 depth = IERC20F(USDC).balanceOf(pool);
        require(depth >= (ask * 12) / 10, "DEPTH");

        if (isWeth && IERC20F(WETH).balanceOf(HOT) == 0 && HOT.balance > 0) {
            // Keep gas floor 0.002 ETH.
            uint256 gasFloor = 0.002 ether;
            require(HOT.balance > gasFloor, "ETH_GAS");
            IERC20F(WETH).deposit{value: HOT.balance - gasFloor}();
        }

        uint256 bal = IERC20F(tokenIn).balanceOf(HOT);
        require(bal > 0, "NO_INVENTORY");

        // Conservative: swap full balance; require out ≥ ask after slippage floor.
        uint256 minOut = ask - ((ask * maxSlipBps) / 10_000);
        // If ask is target floor and balance may yield more/less — require minOut met.
        IERC20F(tokenIn).approve(ROUTER, bal);
        uint256 out = ISwapRouter02(ROUTER).exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: USDC,
                fee: FEE_500,
                recipient: LANDING,
                amountIn: bal,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            })
        );
        console2.log("swappedIn", bal);
        console2.log("usdcToLanding", out);
        require(out >= minOut, "SLIPPAGE");
    }

    function _cdpThenPsm(string memory asset, uint256 ask) internal {
        require(!IPsmF(PSM).paused(), "PSM_PAUSED");
        (uint256 psmUsdc,) = IPsmF(PSM).reserves();
        require(psmUsdc >= ask, "PSM_USDC");

        bool isWeth = _eq(asset, "WETH");
        address token = isWeth ? WETH : CBBTC;
        address cdp = isWeth ? WETH_CDP : CBBTC_CDP;

        if (isWeth && IERC20F(WETH).balanceOf(HOT) == 0 && HOT.balance > 0.002 ether) {
            IERC20F(WETH).deposit{value: HOT.balance - 0.002 ether}();
        }
        uint256 bal = IERC20F(token).balanceOf(HOT);
        require(bal > 0, "NO_INVENTORY");

        IERC20F(token).approve(cdp, bal);
        ICdpF(cdp).deposit(bal);
        uint256 mintAmt = ICdpF(cdp).maxMintable();
        // Cap mint to ask (18dp eUSD ≈ ask USDC 6dp * 1e12)
        uint256 wantEusd = ask * 1e12;
        if (mintAmt > wantEusd) mintAmt = wantEusd;
        require(mintAmt > 0, "MINT0");
        ICdpF(cdp).mint(mintAmt);
        require(ICdpF(cdp).healthFactor() >= ICdpF(cdp).safetyFloor(), "HF");

        (uint256 expectOut,) = IPsmF(PSM).quoteBuyUsdc(mintAmt);
        require(expectOut >= ask - 1e6, "QUOTE");
        IERC20F(EUSD).approve(PSM, mintAmt);
        uint256 usdcOut = IPsmF(PSM).buyUsdc(mintAmt, LANDING);
        console2.log("cdpMinted", mintAmt);
        console2.log("psmUsdcOut", usdcOut);
        require(usdcOut + 1e6 >= ask, "PSM_SHORT");
    }

    function _borrowIdle(uint256 ask) internal {
        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(ELE77);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        require(idle >= ask, "NO_IDLE");

        (, , uint128 coll) = IMorphoF(MORPHO).position(ELE77, HOT);
        uint256 collUsd6 = uint256(coll) / 100; // $1 soft
        uint256 max77 = (collUsd6 * LLTV_77) / 1e18;
        require(max77 >= uint256(ba) + ask, "NO_HEADROOM");

        IExtractorF(EXTRACTOR).borrowIdle(ask);
        console2.log("borrowIdle", ask);
    }

    function _morphoCollBorrow(string memory asset, uint256 ask) internal {
        bool isWeth = _eq(asset, "WETH");
        address token = isWeth ? WETH : CBBTC;
        address oracle = isWeth ? WETH_ORACLE : CBBTC_ORACLE;

        if (isWeth && IERC20F(WETH).balanceOf(HOT) == 0 && HOT.balance > 0.002 ether) {
            IERC20F(WETH).deposit{value: HOT.balance - 0.002 ether}();
        }
        uint256 bal = IERC20F(token).balanceOf(HOT);
        require(bal > 0, "NO_INVENTORY");

        IMorphoF.MarketParams memory mp =
            IMorphoF.MarketParams({loanToken: USDC, collateralToken: token, oracle: oracle, irm: IRM, lltv: LLTV_86});
        IMorphoF(MORPHO).accrueInterest(mp);
        IERC20F(token).approve(MORPHO, bal);
        IMorphoF(MORPHO).supplyCollateral(mp, bal, HOT, "");
        // Soft 60% of LLTV for Charlie prudence
        // Exact max depends on oracle — borrow ask only; Morpho reverts if unsafe.
        IMorphoF(MORPHO).borrow(mp, ask, 0, HOT, LANDING);
        console2.log("morphoCollPosted", bal);
        console2.log("morphoBorrowedToLanding", ask);
    }

    function _eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _neq(string memory a, string memory b) internal pure returns (bool) {
        return !_eq(a, b);
    }
}
