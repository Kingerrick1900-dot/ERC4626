// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoUniV3Oracle} from "../src/MorphoUniV3Oracle.sol";

interface IMorpho {
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
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Oracle-moat: BRETT/USDC Morpho Blue market with UniV3 TWAP oracle.
/// @dev BRETT has Chainlink-grade on-chain Uni depth and (pre-deploy) zero Morpho markets.
contract DeployBrettUsdcMarket is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    // UniV3 BRETT/USDC 1% — live liquidity + cardinality
    address constant POOL = 0xBF0A0C12E7C0610002F6Aa6E609755EDe42D6A4d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    // Conservative LLTV for volatile collateral
    uint256 constant LLTV = 625000000000000000; // 62.5%
    uint32 constant TWAP_SEC = 1800; // 30m

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        MorphoUniV3Oracle oracle = new MorphoUniV3Oracle(POOL, BRETT, USDC, TWAP_SEC, 18, 6);
        uint256 px = oracle.price();
        console2.log("oracle", address(oracle));
        console2.log("oraclePrice", px);

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: BRETT,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });

        IMorpho(MORPHO).createMarket(mp);
        vm.stopBroadcast();

        bytes32 id = keccak256(abi.encode(mp));
        console2.logBytes32(id);
        (address loan, address coll, address orc,, uint256 lltv) = IMorpho(MORPHO).idToMarketParams(id);
        console2.log("loan", loan);
        console2.log("coll", coll);
        console2.log("orc", orc);
        console2.log("lltv", lltv);
    }
}
