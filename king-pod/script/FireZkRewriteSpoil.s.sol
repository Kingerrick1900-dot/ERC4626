// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkMorphoRail} from "../src/CrownZkMorphoRail.sol";
import {CrownHotOracle50kZk} from "../src/CrownHotOracle50kZk.sol";
import {CrownHarvesterZk} from "../src/CrownHarvesterZk.sol";
import {CrownKRT} from "../src/CrownKRT.sol";
import {CrownGusd} from "../src/CrownGusd.sol";
import {Crown369} from "../src/Crown369.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoRW {
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

    function isLltvEnabled(uint256) external view returns (bool);
}

interface IERC20RW {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_ZK_REWRITE_SPOIL=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev REWRITE unshielded HOT Morpho eUSD through CrownZkMorphoRail + deploy ZK Falcon stack.
contract FireZkRewriteSpoil is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;
    uint256 constant LLTV_385 = 385000000000000000;

    function run() external {
        require(vm.envOr("FIRE_ZK_REWRITE_SPOIL", uint256(0)) == 1, "FIRE_ZK_REWRITE_SPOIL");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoRW(MORPHO).idToMarketParams(EUSD_RSS);
        require(loan == EUSD, "BAD_MARKET");

        (uint256 hotShares,,) = IMorphoRW(MORPHO).position(EUSD_RSS, HOT);
        require(hotShares > 0, "NO_HOT_SHARES");
        require(IMorphoRW(MORPHO).isLltvEnabled(LLTV_385), "LLTV");

        vm.startBroadcast(pk);

        CrownZkMorphoRail zkRail = new CrownZkMorphoRail(MORPHO, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT);
        zkRail.setRailParams(loan, coll, oracle, irm, lltv);

        // Withdraw ALL HOT shares from unshielded Morpho book
        IMorphoRW(MORPHO).withdraw(
            IMorphoRW.MarketParams(loan, coll, oracle, irm, lltv), 0, hotShares, HOT, HOT
        );
        uint256 bal = IERC20RW(EUSD).balanceOf(HOT);
        require(bal > 0, "WITHDRAW_ZERO");

        // Resupply through on-chain ZK rail -> Safe
        IERC20RW(EUSD).approve(address(zkRail), bal);
        zkRail.zkSupply(bal, SAFE);

        // ZK Falcon stack
        CrownHotOracle50kZk zOracle = new CrownHotOracle50kZk(HOT, ZK_WALLET_GATE, BASE_ATTEST);
        CrownKRT krt = new CrownKRT(HOT, SAFE);
        CrownGusd gusd = new CrownGusd(HOT);
        gusd.mint(HOT, 1_000_000e18);
        krt.mint(HOT, 1_000_000e18);
        CrownHarvesterZk harv = new CrownHarvesterZk(MORPHO, ZK_WALLET_GATE, BASE_ATTEST, HOT, SAFE);
        Crown369 c369 = new Crown369(MORPHO, RSS, IRM, LLTV_385, HOT);
        c369.setTokens(address(krt), EUSD, address(gusd), address(zOracle));
        (bytes32 idK, bytes32 idE, bytes32 idG) = c369.fireBase3();
        harv.setRailParams(EUSD, RSS, address(zOracle), IRM, LLTV_385);

        zOracle.transferOwnership(SAFE);
        krt.transferOwnership(SAFE);
        gusd.transferOwnership(SAFE);
        harv.transferOwnership(SAFE);
        c369.transferOwnership(SAFE);
        zkRail.transferOwnership(SAFE);

        vm.stopBroadcast();

        (uint256 hotAfter,,) = IMorphoRW(MORPHO).position(EUSD_RSS, HOT);
        (uint256 safeShares,,) = IMorphoRW(MORPHO).position(EUSD_RSS, SAFE);
        (uint128 sa,, uint128 ba,,,) = IMorphoRW(MORPHO).market(EUSD_RSS);

        console2.log("ZK_RAIL", address(zkRail));
        console2.log("ZK_ORACLE", address(zOracle));
        console2.log("ZK_HARVESTER", address(harv));
        console2.log("ZK_KRT", address(krt));
        console2.log("ZK_GUSD", address(gusd));
        console2.log("ZK_CROWN369", address(c369));
        console2.log("MKT_KRT", uint256(idK));
        console2.log("MKT_EUSD", uint256(idE));
        console2.log("MKT_GUSD", uint256(idG));
        console2.log("HOT_SHARES_AFTER", hotAfter);
        console2.log("SAFE_SHARES", safeShares);
        console2.log("MARKET_SUPPLY", uint256(sa));
        console2.log("MARKET_BORROW", uint256(ba));
        require(hotAfter == 0, "HOT_STILL_ON_UNSHIELDED");
        console2.log("MISSION ZK REWRITE live - HOT spoil via CrownZkMorphoRail - Falcon ZK - Safe owns");
    }
}
