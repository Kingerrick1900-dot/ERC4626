// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoA {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function isAuthorized(address authorizer, address authorized) external view returns (bool);

    function withdraw(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IZkRail {
    function zkSupply(uint256 assets, address onBehalf) external returns (uint256, uint256);
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_ZK_REWRITE_SAFE_VIA_HOT=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev After ONE Safe tx Morpho.setAuthorization(HOT,true), HOT rewrites Safe book via ZK rail.
///      King does not sign every fire — only the one-time authorize.
contract FireZkRewriteSafeViaHot is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

    function run() external {
        require(vm.envOr("FIRE_ZK_REWRITE_SAFE_VIA_HOT", uint256(0)) == 1, "FIRE_ZK_REWRITE_SAFE_VIA_HOT");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMorphoA(MORPHO).isAuthorized(SAFE, HOT), "SAFE_MUST_AUTHORIZE_HOT_ONCE");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoA(MORPHO).idToMarketParams(EUSD_RSS);
        (uint256 shares,,) = IMorphoA(MORPHO).position(EUSD_RSS, SAFE);
        require(shares > 0, "NO_SAFE_SHARES");

        vm.startBroadcast(pk);
        IMorphoA(MORPHO).withdraw(
            IMorphoA.MarketParams(loan, coll, oracle, irm, lltv), 0, shares, SAFE, HOT
        );
        uint256 bal = IERC20A(EUSD).balanceOf(HOT);
        require(bal > 0, "WITHDRAW_ZERO");
        IERC20A(EUSD).approve(ZK_RAIL, bal);
        IZkRail(ZK_RAIL).zkSupply(bal, SAFE);
        vm.stopBroadcast();

        (uint256 safeAfter,,) = IMorphoA(MORPHO).position(EUSD_RSS, SAFE);
        console2.log("SAFE_SHARES_AFTER", safeAfter);
        console2.log("EUSD_SUPPLIED", bal);
        console2.log("MISSION Safe book rewritten via ZK rail - HOT operator - King signed once");
    }
}
