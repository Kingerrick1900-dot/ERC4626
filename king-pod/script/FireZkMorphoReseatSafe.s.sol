// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoR {
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
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IZkRail {
    function zkSupply(uint256 assets, address onBehalf) external returns (uint256, uint256);
    function totalSupplied() external view returns (uint256);
}

interface IERC20R {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Withdraw full Safe Morpho eUSD book → zkSupply under Safe (HOT operator, authorized).
/// @dev V3 migrateFirst100M is AwaitHandoff stub — this is the live custody path.
contract FireZkMorphoReseatSafe is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;
    uint256 constant MAX_MINT_CAPACITY = 100_000_000_000_000e6; // 100T @ 6dp surface

    event WalletMigrated(address indexed wallet, uint256 assets, uint256 railAfter);
    event CapacityCheck(uint256 totalSupplyAfter, uint256 maxCapacity, bool ok);

    function run() external {
        require(vm.envOr("FIRE_ZK_MORPHO_RESEAT", uint256(0)) == 1, "FIRE_ZK_MORPHO_RESEAT");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMorphoR(MORPHO).isAuthorized(SAFE, HOT), "SAFE_MUST_AUTHORIZE_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoR(MORPHO).idToMarketParams(EUSD_RSS);
        (uint256 shares,,) = IMorphoR(MORPHO).position(EUSD_RSS, SAFE);
        require(shares > 0, "NO_SAFE_SHARES");

        uint256 railBefore = IZkRail(ZK_RAIL).totalSupplied();
        console2.log("SAFE_SHARES", shares);
        console2.log("RAIL_BEFORE", railBefore);

        vm.startBroadcast(pk);
        // 1) Full withdraw — all shares, no partial
        IMorphoR(MORPHO).withdraw(
            IMorphoR.MarketParams(loan, coll, oracle, irm, lltv), 0, shares, SAFE, HOT
        );
        uint256 bal = IERC20R(EUSD).balanceOf(HOT);
        require(bal > 0, "WITHDRAW_ZERO");
        // 2) Approve + 3) zkSupply under Safe
        IERC20R(EUSD).approve(ZK_RAIL, bal);
        IZkRail(ZK_RAIL).zkSupply(bal, SAFE);
        vm.stopBroadcast();

        uint256 railAfter = IZkRail(ZK_RAIL).totalSupplied();
        (uint256 safeAfter,,) = IMorphoR(MORPHO).position(EUSD_RSS, SAFE);
        bool capOk = railAfter <= MAX_MINT_CAPACITY * 1e12; // rail is 18dp eUSD; surface is 6dp*100T
        // Capacity surface: 100T eUSD at 18dp = 100_000_000_000_000e18
        uint256 cap18 = 100_000_000_000_000 ether;
        capOk = railAfter <= cap18;

        console2.log("WITHDRAWN_ZK_SUPPLIED", bal);
        console2.log("RAIL_AFTER", railAfter);
        console2.log("SAFE_SHARES_AFTER", safeAfter);
        console2.log("HOT_EUSD", IERC20R(EUSD).balanceOf(HOT));
        console2.log("CAPACITY_OK", capOk ? uint256(1) : uint256(0));
        console2.log("CAPACITY_CEILING", cap18);

        emit WalletMigrated(SAFE, bal, railAfter);
        emit CapacityCheck(railAfter, cap18, capOk);
        require(capOk, "CAP");
        require(safeAfter > 0, "SAFE_NOT_RESEATED");
        require(IERC20R(EUSD).balanceOf(HOT) == 0, "HOT_DUST");
    }
}
