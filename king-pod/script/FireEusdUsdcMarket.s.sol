// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFrozenFixedOracle} from "../src/MorphoFrozenFixedOracle.sol";

interface IMorphoCreate {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function isLltvEnabled(uint256) external view returns (bool);
    function isIrmEnabled(address) external view returns (bool);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Companion to RSS/$1200 market: Kingdom eUSD collateral → USDC loan @ frozen $1.
/// @dev Existing Morpho markets are immutable — this CREATES a new market (cannot patch 1200).
///      FIRE_EUSD_MKT=1 to broadcast. Does not seed USDC (market stays empty until seeded).
contract FireEusdUsdcMarket is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a; // Kingdom Elepan USD
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // 77%
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    // eUSD 18dp / USDC 6dp — $1 → 1e24 Morpho scale
    uint256 constant PRICE_1 = 1e24;

    function run() external {
        require(vm.envOr("FIRE_EUSD_MKT", uint256(0)) == 1, "NEED FIRE_EUSD_MKT=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        console2.log("=== eUSD/USDC FROZEN $1 MARKET ===");
        console2.log("collateral eUSD", EUSD);
        console2.log("loan USDC", USDC);
        console2.log("irm enabled", IMorphoCreate(MORPHO).isIrmEnabled(IRM) ? 1 : 0);
        console2.log("lltv enabled", IMorphoCreate(MORPHO).isLltvEnabled(LLTV) ? 1 : 0);

        vm.startBroadcast(pk);

        MorphoFrozenFixedOracle oracle = new MorphoFrozenFixedOracle(PRICE_1);
        console2.log("ORACLE", address(oracle));
        require(oracle.price() == PRICE_1, "PRICE");

        IMorphoCreate.MarketParams memory mp = IMorphoCreate.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });

        bytes32 id = keccak256(abi.encode(mp));
        // idempotent: skip create if already exists
        (address loan,,,,) = IMorphoCreate(MORPHO).idToMarketParams(id);
        if (loan == address(0)) {
            IMorphoCreate(MORPHO).createMarket(mp);
        }

        (address l, address c, address o, address irm, uint256 lltv) =
            IMorphoCreate(MORPHO).idToMarketParams(id);
        require(l == USDC && c == EUSD && o == address(oracle), "PARAMS");
        console2.logBytes32(id);
        console2.log("loan", l);
        console2.log("coll", c);
        console2.log("oracle", o);
        console2.log("irm", irm);
        console2.log("lltv", lltv);
        console2.log("EUSD_USDC_MARKET_OK");

        vm.stopBroadcast();
    }
}
