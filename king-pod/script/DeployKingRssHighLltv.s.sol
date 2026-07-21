// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoCreate {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function isLltvEnabled(uint256) external view returns (bool);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Create King's OWN high-LLTV RSS/USDC Blue market (same FixedOracle $1).
/// @dev LIVE-FIRE-LAW: KING_OK=1 and FIRE_MARKET=1 required to broadcast.
///      Default LLTV 91.5%. Set HIGH_LLTV=945000000000000000 for 94.5%.
contract DeployKingRssHighLltv is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "LIVE-FIRE-LAW: need KING_OK=1");
        bool doFire = vm.envOr("FIRE_MARKET", uint256(0)) == 1;

        uint256 lltv = vm.envOr("HIGH_LLTV", LLTV_915);
        require(IMorphoCreate(MORPHO).isLltvEnabled(lltv), "LLTV_NOT_ENABLED");

        IMorphoCreate.MarketParams memory mp = IMorphoCreate.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: lltv
        });
        bytes32 id = keccak256(abi.encode(mp));

        console2.log("=== DEPLOY KING RSS HIGH-LLTV MARKET ===");
        console2.log("lltv", lltv);
        console2.logBytes32(id);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        bool exists = IMorphoCreate(MORPHO).idToMarketParams(id).loanToken == USDC;
        if (exists) {
            console2.log("ALREADY_CREATED");
            (uint128 supply,,,,,) = IMorphoCreate(MORPHO).market(id);
            console2.log("supply", uint256(supply));
            console2.log("READY", uint256(1));
            return;
        }

        if (!doFire) {
            console2.log("DRY: would createMarket. Set FIRE_MARKET=1 + KING_OK=1 to broadcast");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        IMorphoCreate(MORPHO).createMarket(mp);
        vm.stopBroadcast();

        IMorphoCreate.MarketParams memory got = IMorphoCreate(MORPHO).idToMarketParams(id);
        require(got.lltv == lltv && got.oracle == ORACLE, "CREATE_VERIFY");
        console2.log("CREATED");
        console2.log("READY", uint256(1));
    }
}
