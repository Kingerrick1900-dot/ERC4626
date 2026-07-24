// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

interface IMetaMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function reallocate(MarketAllocation[] calldata allocations) external;
    function skim(address token) external;
}

interface IAero {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

/// @dev Path A: flash-repay ELE/USDC → yELE reallocate+skim → repay flash (clean books, ELE free).
///      Path B: flash-unwind ELE/WETH + ELE/cbBTC → WETH coll on WETH/USDC → borrow USDC → Landing.
contract CrownOpsFive {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant ELE_ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant WETH_ELE_ORACLE = 0xF927B35E62A0111Da1A5D4Da63FA57E473B525E5;
    address constant CBBTC_ELE_ORACLE = 0x08DEeEF782B81C8CDD2e11bF5a54982f3A11C94d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACT = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant ELE_WETH = 0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44;
    bytes32 constant ELE_CBBTC = 0x28d57b898122465e0260881973440823f1a380d64f16af56d982b47e5aeffa25;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    address public immutable king;
    address public immutable landing;

    uint256 private mode; // 1=ele cleanse, 2=weth unwind, 3=cbbtc unwind
    bool private locking;

    constructor(address king_, address landing_) {
        king = king_;
        landing = landing_;
    }

    /// @notice Clean ELE/USDC self-seed via yELE skim (no Landing key).
    function cleanseEle() external {
        require(msg.sender == king, "KING");
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, ELE, ELE_ORACLE, IRM, LLTV_77);
        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = IMorpho(MORPHO).position(ELE_USDC, king);
        require(borShares > 0, "NO_DEBT");
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(ELE_USDC);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs) + 5e6;
        mode = 1;
        locking = true;
        IMorpho(MORPHO).flashLoan(USDC, flashAmt, abi.encode(uint256(borShares), uint256(coll), flashAmt));
        locking = false;
        mode = 0;
        uint256 ele = IERC20(ELE).balanceOf(address(this));
        if (ele > 0) IERC20(ELE).transfer(king, ele);
        uint256 dust = IERC20(USDC).balanceOf(address(this));
        if (dust > 0) IERC20(USDC).transfer(landing, dust);
    }

    /// @notice Unwind ELE/WETH self-seed → free WETH to this contract.
    function unwindEleWeth() external {
        require(msg.sender == king, "KING");
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(WETH, ELE, WETH_ELE_ORACLE, IRM, LLTV_77);
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorpho(MORPHO).position(ELE_WETH, king);
        require(borShares > 0, "NO_WETH_DEBT");
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(ELE_WETH);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs) + 1e12;
        mode = 2;
        locking = true;
        IMorpho(MORPHO).flashLoan(WETH, flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll), flashAmt));
        locking = false;
        mode = 0;
        uint256 ele = IERC20(ELE).balanceOf(address(this));
        if (ele > 0) IERC20(ELE).transfer(king, ele);
    }

    /// @notice Unwind ELE/cbBTC → swap cbBTC to WETH → this holds WETH.
    function unwindEleCbBtc() external {
        require(msg.sender == king, "KING");
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(CBBTC, ELE, CBBTC_ELE_ORACLE, IRM, LLTV_77);
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = IMorpho(MORPHO).position(ELE_CBBTC, king);
        require(borShares > 0, "NO_BTC_DEBT");
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(ELE_CBBTC);
        uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs) + 10;
        mode = 3;
        locking = true;
        IMorpho(MORPHO).flashLoan(CBBTC, flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll), flashAmt));
        locking = false;
        mode = 0;
        uint256 ele = IERC20(ELE).balanceOf(address(this));
        if (ele > 0) IERC20(ELE).transfer(king, ele);
        // swap freed cbBTC dust to WETH if any leftover after repay
        uint256 btc = IERC20(CBBTC).balanceOf(address(this));
        if (btc > 0) {
            IERC20(CBBTC).approve(AERO, btc);
            IAero.Route[] memory routes = new IAero.Route[](1);
            routes[0] = IAero.Route({from: CBBTC, to: WETH, stable: false, factory: AERO_FACT});
            try IAero(AERO).swapExactTokensForTokens(btc, 0, routes, address(this), block.timestamp + 600) {} catch {}
        }
    }

    /// @notice Post all WETH on WETH/USDC and borrow max idle USDC → Landing.
    function borrowUsdcToLanding() external {
        require(msg.sender == king, "KING");
        uint256 wethBal = IERC20(WETH).balanceOf(address(this));
        require(wethBal > 0, "NO_WETH");
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86);
        IERC20(WETH).approve(MORPHO, wethBal);
        IMorpho(MORPHO).supplyCollateral(mp, wethBal, king, "");

        (uint128 sa,, uint128 ba,,,) = IMorpho(MORPHO).market(WETH_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        // max by LLTV ~86% of coll; oracle-priced approx use 80% of idle cap and health
        uint256 ask = idle > 1e6 ? idle - 1e6 : 0;
        // conservative: borrow min(idle, rough 80% of weth value via trying)
        if (ask > 0) {
            // try full ask; Morpho reverts if unhealthy
            IMorpho(MORPHO).borrow(mp, ask, 0, king, landing);
        }
        uint256 left = IERC20(USDC).balanceOf(address(this));
        if (left > 0) IERC20(USDC).transfer(landing, left);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO && locking, "CB");
        if (mode == 1) {
            (uint256 borShares, uint256 coll, uint256 flashAmt) = abi.decode(data, (uint256, uint256, uint256));
            require(assets == flashAmt, "AMT");
            IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, ELE, ELE_ORACLE, IRM, LLTV_77);
            IERC20(USDC).approve(MORPHO, type(uint256).max);
            IMorpho(MORPHO).repay(mp, 0, borShares, king, "");
            if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, coll, king, address(this));

            IMetaMorpho.MarketParams memory ymp = IMetaMorpho.MarketParams(USDC, ELE, ELE_ORACLE, IRM, LLTV_77);
            IMetaMorpho.MarketAllocation[] memory allocs = new IMetaMorpho.MarketAllocation[](1);
            allocs[0] = IMetaMorpho.MarketAllocation({marketParams: ymp, assets: 0});
            IMetaMorpho(YELE).reallocate(allocs);
            IMetaMorpho(YELE).skim(USDC);

            require(IERC20(USDC).balanceOf(address(this)) >= flashAmt, "SHORT");
            IERC20(USDC).approve(MORPHO, flashAmt);
        } else if (mode == 2) {
            (uint256 supShares, uint256 borShares, uint256 coll, uint256 flashAmt) =
                abi.decode(data, (uint256, uint256, uint256, uint256));
            require(assets == flashAmt, "AMT");
            IMorpho.MarketParams memory mp = IMorpho.MarketParams(WETH, ELE, WETH_ELE_ORACLE, IRM, LLTV_77);
            IERC20(WETH).approve(MORPHO, type(uint256).max);
            IMorpho(MORPHO).repay(mp, 0, borShares, king, "");
            if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, coll, king, address(this));
            if (supShares > 0) IMorpho(MORPHO).withdraw(mp, 0, supShares, king, address(this));
            require(IERC20(WETH).balanceOf(address(this)) >= flashAmt, "SHORT_W");
            IERC20(WETH).approve(MORPHO, flashAmt);
        } else if (mode == 3) {
            (uint256 supShares, uint256 borShares, uint256 coll, uint256 flashAmt) =
                abi.decode(data, (uint256, uint256, uint256, uint256));
            require(assets == flashAmt, "AMT");
            IMorpho.MarketParams memory mp = IMorpho.MarketParams(CBBTC, ELE, CBBTC_ELE_ORACLE, IRM, LLTV_77);
            IERC20(CBBTC).approve(MORPHO, type(uint256).max);
            IMorpho(MORPHO).repay(mp, 0, borShares, king, "");
            if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, coll, king, address(this));
            if (supShares > 0) IMorpho(MORPHO).withdraw(mp, 0, supShares, king, address(this));
            require(IERC20(CBBTC).balanceOf(address(this)) >= flashAmt, "SHORT_B");
            IERC20(CBBTC).approve(MORPHO, flashAmt);
        } else {
            revert("MODE");
        }
    }
}
