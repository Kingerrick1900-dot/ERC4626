// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOracle} from "../src/CrownOracle.sol";
import {CrownSovereignMigrate} from "../src/CrownSovereignMigrate.sol";

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

interface IERC20F {
    function approve(address, uint256) external returns (bool);
}

interface IYrssF {
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire: deploy CrownOracle + sovereign market (if needed) + migrate 252k RSS off legacy book.
/// Gate: FIRE_SOVEREIGN_MIGRATE=1 · HOT_KEY → 0x6708…a7d1
/// Env: SOVEREIGN_ORACLE= (skip deploy if set) · ORACLE_PRICE_USD=50000 default
contract FireSovereignMigrate is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant LEGACY_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant LEGACY = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant DEFAULT_PRICE_50K = 50000000000000000000000000000;

    function run() external {
        require(vm.envOr("FIRE_SOVEREIGN_MIGRATE", uint256(0)) == 1, "FIRE_SOVEREIGN_MIGRATE");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 morphoPrice = vm.envOr("ORACLE_PRICE_MORPHO", DEFAULT_PRICE_50K);
        if (vm.envOr("ORACLE_PRICE_USD", uint256(0)) != 0) {
            morphoPrice = vm.envUint("ORACLE_PRICE_USD") * 1e24;
        }

        address oracleAddr = vm.envOr("SOVEREIGN_ORACLE", address(0));

        vm.startBroadcast(pk);

        CrownOracle oracle;
        if (oracleAddr == address(0)) {
            oracle = new CrownOracle(HOT, morphoPrice);
            oracleAddr = address(oracle);
            console2.log("CrownOracle", oracleAddr);
        }

        IMorphoF.MarketParams memory legacyMp =
            IMorphoF.MarketParams(USDC, RSS, LEGACY_ORACLE, IRM, LLTV);
        IMorphoF.MarketParams memory sovMp = IMorphoF.MarketParams(USDC, RSS, oracleAddr, IRM, LLTV);

        if (vm.envOr("SKIP_CREATE_MARKET", uint256(0)) == 0) {
            IMorphoF(MORPHO).createMarket(sovMp);
        }

        bytes32 sovId = keccak256(abi.encode(sovMp));
        console2.logBytes32(sovId);

        CrownSovereignMigrate mig = new CrownSovereignMigrate(
            MORPHO,
            USDC,
            RSS,
            YRSS,
            HOT,
            LEGACY,
            LEGACY_ORACLE,
            sovId,
            oracleAddr,
            IRM,
            LLTV,
            HOT
        );
        console2.log("CrownSovereignMigrate", address(mig));

        IERC20F(USDC).approve(address(mig), type(uint256).max);
        IYrssF(YRSS).approve(address(mig), type(uint256).max);
        IMorphoF(MORPHO).setAuthorization(address(mig), true);
        mig.migrate();

        vm.stopBroadcast();

        console2.log("MISSION legacy cleared; RSS on sovereign market under King oracle");
    }
}
