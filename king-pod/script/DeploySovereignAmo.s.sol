// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoRssEusdOracle} from "../src/MorphoRssEusdOracle.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownDepthAttest} from "../src/CrownDepthAttest.sol";

interface IMorphoDeploy {
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
}

/// @notice Deploy RSS/eUSD/$1200 market + Sovereign AMO + depth scribe.
contract DeploySovereignAmo is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    bytes32 constant USDC_MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        MorphoRssEusdOracle oracle = new MorphoRssEusdOracle();
        console2.log("oracle", address(oracle));
        console2.log("oraclePrice", oracle.priceValue());

        IMorphoDeploy.MarketParams memory mp = IMorphoDeploy.MarketParams({
            loanToken: EUSD,
            collateralToken: RSS,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });

        IMorphoDeploy(MORPHO).createMarket(mp);
        bytes32 mid = keccak256(abi.encode(mp));
        console2.logBytes32(mid);

        CrownSovereignAmo amo = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, GATE, HOT, LANDING, mid, address(oracle), IRM, LLTV, HOT
        );
        console2.log("amo", address(amo));

        CrownDepthAttest scribe = new CrownDepthAttest(MORPHO, mid, USDC_MID, HOT);
        console2.log("scribe", address(scribe));

        vm.stopBroadcast();

        (address loan,,,,) = IMorphoDeploy(MORPHO).idToMarketParams(mid);
        console2.log("loan", loan);
        require(loan == EUSD, "MKT_FAIL");
    }
}
