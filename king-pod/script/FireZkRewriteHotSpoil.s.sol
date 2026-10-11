// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkMorphoRail} from "../src/CrownZkMorphoRail.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoH {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdraw(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20H {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_ZK_REWRITE_HOT_SPOIL=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Minimal rewrite: withdraw unshielded HOT Morpho eUSD → CrownZkMorphoRail.zkSupply → Safe.
contract FireZkRewriteHotSpoil is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

    function run() external {
        require(vm.envOr("FIRE_ZK_REWRITE_HOT_SPOIL", uint256(0)) == 1, "FIRE_ZK_REWRITE_HOT_SPOIL");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoH(MORPHO).idToMarketParams(EUSD_RSS);
        require(loan == EUSD, "BAD_MARKET");

        (uint256 hotShares,,) = IMorphoH(MORPHO).position(EUSD_RSS, HOT);
        require(hotShares > 0, "NO_HOT_SHARES");

        vm.startBroadcast(pk);

        CrownZkMorphoRail zkRail = new CrownZkMorphoRail(MORPHO, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT);
        zkRail.setRailParams(loan, coll, oracle, irm, lltv);

        IMorphoH(MORPHO).withdraw(
            IMorphoH.MarketParams(loan, coll, oracle, irm, lltv), 0, hotShares, HOT, HOT
        );
        uint256 bal = IERC20H(EUSD).balanceOf(HOT);
        require(bal > 0, "WITHDRAW_ZERO");

        IERC20H(EUSD).approve(address(zkRail), bal);
        zkRail.zkSupply(bal, SAFE);
        zkRail.transferOwnership(SAFE);

        vm.stopBroadcast();

        (uint256 hotAfter,,) = IMorphoH(MORPHO).position(EUSD_RSS, HOT);
        (uint256 safeShares,,) = IMorphoH(MORPHO).position(EUSD_RSS, SAFE);
        (uint128 sa,, uint128 ba,,,) = IMorphoH(MORPHO).market(EUSD_RSS);

        console2.log("ZK_RAIL", address(zkRail));
        console2.log("HOT_SHARES_AFTER", hotAfter);
        console2.log("SAFE_SHARES", safeShares);
        console2.log("MARKET_SUPPLY", uint256(sa));
        console2.log("MARKET_BORROW", uint256(ba));
        require(hotAfter == 0, "HOT_STILL_UNSHIELDED");
        console2.log("MISSION ZK REWRITE HOT spoil via CrownZkMorphoRail");
    }
}
