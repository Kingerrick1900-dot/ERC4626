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
}

/// @notice Create RSS/USDC Morpho Blue market @ frozen $1200 oracle. RSS only — no Elepan.
/// @dev FIRE=1 broadcast. PRICE defaults to 1200e24.
contract FireRss1200Market is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // 77%
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    // $1200 per RSS in Morpho price scale
    uint256 constant PRICE_1200 = 1200 * 1e24; // 1.2e27

    function run() external {
        require(RSS != ELEPAN, "ELEPAN");
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        uint256 price = vm.envOr("PRICE", PRICE_1200);

        console2.log("=== RSS $1200 FROZEN MARKET ===");
        console2.log("collateral RSS", RSS);
        console2.log("loan USDC", USDC);
        console2.log("price", price);
        console2.log("lltv", LLTV);
        console2.log("irm enabled", IMorphoCreate(MORPHO).isIrmEnabled(IRM) ? 1 : 0);
        console2.log("lltv enabled", IMorphoCreate(MORPHO).isLltvEnabled(LLTV) ? 1 : 0);

        if (!fire) {
            console2.log("DRY - FIRE=1 to deploy oracle + createMarket");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        MorphoFrozenFixedOracle oracle = new MorphoFrozenFixedOracle(price);
        console2.log("ORACLE", address(oracle));
        console2.log("oracle.price", oracle.price());
        require(oracle.price() == price, "PRICE_MISMATCH");

        IMorphoCreate.MarketParams memory mp = IMorphoCreate.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV
        });
        require(mp.collateralToken != ELEPAN, "ELEPAN");

        IMorphoCreate(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));
        console2.logBytes32(id);

        (address loan, address coll, address orc, address irm, uint256 lltv) =
            IMorphoCreate(MORPHO).idToMarketParams(id);
        console2.log("loan", loan);
        console2.log("coll", coll);
        console2.log("orc", orc);
        console2.log("irm", irm);
        console2.log("lltv", lltv);
        require(coll == RSS && coll != ELEPAN, "COLL");
        require(orc == address(oracle), "ORC");
        require(loan == USDC, "LOAN");

        vm.stopBroadcast();
        console2.log("RSS_1200_MARKET_OK");
    }
}
