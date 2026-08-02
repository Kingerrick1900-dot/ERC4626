// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
}

/// @notice Extract ELE77 to HF≥1.60 ceiling. Supply USDC dust + max coll → KingVault.
/// @dev KING_GO=1 FIRE_ELE77_EXTRACT=1
contract FireEle77Hf160Extract is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant HF_MIN = 1600000000000000000; // 1.60e18
    uint256 constant ELE_BUFFER = 1e8; // leave 1 ELE

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ELE77_EXTRACT", uint256(0)) == 1, "NEED FIRE_ELE77_EXTRACT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoE.MarketParams memory mp =
            IMorphoE.MarketParams({loanToken: USDC, collateralToken: ELE, oracle: ORACLE, irm: IRM, lltv: LLTV});

        IMorphoE(MORPHO).accrueInterest(mp);

        (uint256 supSh, uint128 borSh, uint128 coll) = IMorphoE(MORPHO).position(ELE77, HOT);
        (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorphoE(MORPHO).market(ELE77);

        uint256 supAssets = uint256(ss) == 0 ? 0 : uint256(sa) * supSh / uint256(ss);
        uint256 borAssets = uint256(bs) == 0 ? 0 : uint256(ba) * uint256(borSh) / uint256(bs);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        uint256 collUsd6 = uint256(coll) / 100;
        uint256 hfBefore = borAssets == 0 ? type(uint256).max : collUsd6 * 1e18 / borAssets;

        // Max coll withdraw for HF >= 1.60: collUsd6 - w >= bor * 1.60
        uint256 minCollUsd6 = (borAssets * 160 + 99) / 100; // ceil
        require(collUsd6 > minCollUsd6, "NO_ROOM");
        uint256 maxCollUsd6 = collUsd6 - minCollUsd6;
        uint256 maxColl = maxCollUsd6 * 100;
        if (maxColl > ELE_BUFFER) maxColl -= ELE_BUFFER;
        else maxColl = 0;

        uint256 supplyPull = idle < 3 ? idle : 3; // market idle ceiling (live ~3 wei)
        if (supplyPull > supAssets) supplyPull = supAssets;

        console2.log("supAssets", supAssets);
        console2.log("borAssets", borAssets);
        console2.log("collBefore", uint256(coll));
        console2.log("idle", idle);
        console2.log("hfBefore", hfBefore);
        console2.log("maxCollWithdraw", maxColl);
        console2.log("supplyPull", supplyPull);
        console2.log("kingVault", KING_VAULT);

        uint256 kvEleBefore = IERC20E(ELE).balanceOf(KING_VAULT);
        uint256 kvUsdcBefore = IERC20E(USDC).balanceOf(KING_VAULT);

        vm.startBroadcast(pk);
        if (supplyPull > 0) {
            IMorphoE(MORPHO).withdraw(mp, supplyPull, 0, HOT, KING_VAULT);
        }
        require(maxColl > 0, "COLL0");
        IMorphoE(MORPHO).withdrawCollateral(mp, maxColl, HOT, KING_VAULT);
        vm.stopBroadcast();

        (, uint128 borSh2, uint128 coll2) = IMorphoE(MORPHO).position(ELE77, HOT);
        (uint128 sa2,, uint128 ba2, uint128 bs2,,) = IMorphoE(MORPHO).market(ELE77);
        uint256 bor2 = uint256(bs2) == 0 ? 0 : uint256(ba2) * uint256(borSh2) / uint256(bs2);
        uint256 collUsd2 = uint256(coll2) / 100;
        uint256 hfAfter = bor2 == 0 ? type(uint256).max : collUsd2 * 1e18 / bor2;

        console2.log("collAfter", uint256(coll2));
        console2.log("borAfter", bor2);
        console2.log("hfAfter", hfAfter);
        console2.log("kvEleDelta", IERC20E(ELE).balanceOf(KING_VAULT) - kvEleBefore);
        console2.log("kvUsdcDelta", IERC20E(USDC).balanceOf(KING_VAULT) - kvUsdcBefore);
        require(hfAfter >= HF_MIN, "HF_BREACH");
        console2.log("ELE77_HF160_EXTRACT_OK", uint256(1));
        sa2; // silence
    }
}
