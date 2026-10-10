// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOracle} from "../src/CrownOracle.sol";

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
}

/// @notice Deploy CrownOracle + new RSS/USDC Morpho market on Base.
/// @dev Gate: FIRE_SOVEREIGN_ORACLE=1 · signer must be HOT (HOT_KEY).
/// Env:
///   HOT_KEY — deployer / oracle owner
///   ORACLE_PRICE_MORPHO — optional Morpho-scaled price (default $50,000 → 5e28)
///   ORACLE_PRICE_USD — optional whole USD per RSS (overrides MORPHO if set)
///   SKIP_CREATE_MARKET=1 — deploy oracle only (market already created)
contract DeploySovereignOracle is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant LLTV = 770000000000000000; // 77% — same as live RSS/$1200 book

    /// @dev $50,000 / RSS at Morpho scale (USDC 6 / RSS 18).
    uint256 constant DEFAULT_PRICE_50K = 50000000000000000000000000000;

    function run() external {
        require(vm.envOr("FIRE_SOVEREIGN_ORACLE", uint256(0)) == 1, "FIRE_SOVEREIGN_ORACLE");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 morphoPrice = vm.envOr("ORACLE_PRICE_MORPHO", DEFAULT_PRICE_50K);
        if (vm.envOr("ORACLE_PRICE_USD", uint256(0)) != 0) {
            morphoPrice = vm.envUint("ORACLE_PRICE_USD") * 1e24;
        }

        vm.startBroadcast(pk);

        CrownOracle oracle = new CrownOracle(HOT, morphoPrice);
        console2.log("CrownOracle", address(oracle));
        console2.log("owner", oracle.owner());
        console2.log("price", oracle.price());

        bytes32 marketId;
        if (vm.envOr("SKIP_CREATE_MARKET", uint256(0)) == 0) {
            IMorpho.MarketParams memory mp = IMorpho.MarketParams({
                loanToken: USDC,
                collateralToken: RSS,
                oracle: address(oracle),
                irm: IRM,
                lltv: LLTV
            });
            IMorpho(MORPHO).createMarket(mp);
            marketId = keccak256(abi.encode(mp));
            console2.logBytes32(marketId);
        }

        vm.stopBroadcast();

        if (marketId != bytes32(0)) {
            (address loan, address coll, address orc,, uint256 lltv) = IMorpho(MORPHO).idToMarketParams(marketId);
            require(loan == USDC && coll == RSS && orc == address(oracle), "MKT_VERIFY");
            console2.log("loan", loan);
            console2.log("coll", coll);
            console2.log("oracle", orc);
            console2.log("lltv", lltv);
        }

        console2.log("HANDOFF update deployments/HANDOFF-SOVEREIGN-ORACLE.md with addresses + marketId");
    }
}
