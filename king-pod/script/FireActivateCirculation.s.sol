// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20a {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IVault {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice Activation — Kingdom is its own first lender + first borrower. No new contracts. No outreach.
/// 1) HOT USDC → ySYNTH (prove deposit / fill)
/// 2) HOT eUSD → Morpho collateral on synth market
/// 3) Borrow max idle USDC → HOT (prove loop)
contract FireActivateCirculation is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
        bytes32 mid = keccak256(abi.encode(mp));

        uint256 usdcBal = IERC20a(USDC).balanceOf(HOT);
        // Keep 1 wei dust out of gas-panic; deposit rest into ySYNTH as first Kingdom lender
        uint256 lendAmt = usdcBal > 1 ? usdcBal : 0;

        // Collateral: enough eUSD for full market idle borrow at 86% LTV (+ buffer)
        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorpho(MORPHO).market(mid);
        uint256 idle = uint256(supplyAssets) > uint256(borrowAssets) ? uint256(supplyAssets) - uint256(borrowAssets) : 0;
        // After deposit, idle grows by lendAmt (vault allocates to market)
        uint256 idleAfter = idle + lendAmt;
        // coll needed @ 86%: borrow * 1e18 / lltv  (eUSD 18dp, USDC 6dp, oracle $1 → 1e12 eUSD wei per 1 USDC)
        // borrow USDC raw * 1e12 = eUSD wei at $1; / 0.86
        uint256 eusdForBorrow = (idleAfter * 1e12 * 1e18) / LLTV;
        uint256 eusdColl = eusdForBorrow + 1e18; // +1 eUSD buffer
        if (eusdColl < 10e18) eusdColl = 10e18;

        vm.startBroadcast(pk);

        if (lendAmt > 0) {
            IERC20a(USDC).approve(YSYNTH, lendAmt);
            IVault(YSYNTH).deposit(lendAmt, HOT);
        }

        IERC20a(EUSD).approve(MORPHO, eusdColl);
        IMorpho(MORPHO).supplyCollateral(mp, eusdColl, HOT, "");

        (supplyAssets,, borrowAssets,,,) = IMorpho(MORPHO).market(mid);
        idle = uint256(supplyAssets) > uint256(borrowAssets) ? uint256(supplyAssets) - uint256(borrowAssets) : 0;
        require(idle > 0, "NO_IDLE");
        // borrow 99% of idle to leave 1% util buffer for rounding
        uint256 borrowAmt = (idle * 99) / 100;
        if (borrowAmt == 0) borrowAmt = idle;
        IMorpho(MORPHO).borrow(mp, borrowAmt, 0, HOT, HOT);

        vm.stopBroadcast();

        console2.log("ACTIVATION", "circulation");
        console2.log("lentUsdcToYsynth", lendAmt);
        console2.log("eusdCollateral", eusdColl);
        console2.log("borrowedUsdc", borrowAmt);
        console2.log("hotUsdc", IERC20a(USDC).balanceOf(HOT));
        console2.log("ysynthTA", IVault(YSYNTH).totalAssets());
        (, uint128 bShares, uint128 coll) = IMorpho(MORPHO).position(mid, HOT);
        console2.log("posBorrowShares", uint256(bShares));
        console2.log("posCollateral", uint256(coll));
    }
}
