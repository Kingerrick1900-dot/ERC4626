// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {CrownRwaLoop, IMorphoRwa} from "../src/CrownRwaLoop.sol";
import {OceanArb} from "../src/OceanArb.sol";
import {RwaSwapAdapter} from "../src/RwaSwapAdapter.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";

interface IMorphoCreate {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
}

/// @notice Deploy Live Fire Package on Base. DEPLOY_LIVE_FIRE=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Does NOT arm or seed. Pilot cap default 10M. Optional CREATE_MARKET=1.
contract DeployLiveFirePackage is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDY = 0xC6682C8B7cbB363562Bd1FF1C1Ad50d66f5BAEDA;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    uint256 constant LLTV_85 = 850000000000000000;
    uint256 constant PILOT_10M = 10_000_000e6;
    uint256 constant CHAIN_BUDGET_3M = 3_000_000e6;
    uint256 constant USDY_PRICE = 115e22; // ~$1.15

    function run() external {
        require(vm.envOr("DEPLOY_LIVE_FIRE", uint256(0)) == 1, "DEPLOY_LIVE_FIRE");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 pilot = vm.envOr("PILOT_USDC", PILOT_10M);
        require(pilot <= 35_000_000e6, "NO_FAKE_90M");

        vm.startBroadcast(pk);

        CrownColdBuffer cold = new CrownColdBuffer(USDC, HOT, LANDING, HOT);
        MorphoFixedOracle oracle = new MorphoFixedOracle(USDY_PRICE);
        RwaSwapAdapter swapper = new RwaSwapAdapter(USDC, USDY, HOT);
        CrownRwaLoop loop_ = new CrownRwaLoop(USDC, USDY, YRSS, MORPHO, HOT, HOT, pilot);
        OceanArb ocean = new OceanArb(USDC, HOT, HOT, CHAIN_BUDGET_3M);

        IMorphoRwa.MarketParams memory mp = IMorphoRwa.MarketParams({
            loanToken: USDC,
            collateralToken: USDY,
            oracle: address(oracle),
            irm: IRM,
            lltv: LLTV_85
        });

        if (vm.envOr("CREATE_MARKET", uint256(0)) == 1) {
            IMorphoCreate(MORPHO).createMarket(
                IMorphoCreate.MarketParams({
                    loanToken: mp.loanToken,
                    collateralToken: mp.collateralToken,
                    oracle: mp.oracle,
                    irm: mp.irm,
                    lltv: mp.lltv
                })
            );
        }

        bytes32 mid = keccak256(abi.encode(mp));
        loop_.setMarket(mp, mid);
        loop_.setSwapper(address(swapper));
        loop_.setColdBuffer(address(cold));
        loop_.setGate(GATE);
        loop_.setTargetLtvBps(8500);

        ocean.setColdBuffer(address(cold));
        ocean.setGate(GATE);
        ocean.setMinEdgeBps(20);

        cold.setPusher(address(loop_), true);
        cold.setPusher(address(ocean), true);

        // Transfer oracle ownership to HOT (already) — MorphoFixedOracle owner = deployer = HOT

        vm.stopBroadcast();

        console2.log("COLD_BUFFER", address(cold));
        console2.log("USDY_ORACLE", address(oracle));
        console2.log("RWA_SWAPPER", address(swapper));
        console2.log("CROWN_RWA_LOOP", address(loop_));
        console2.log("OCEAN_ARB_BASE", address(ocean));
        console2.log("MARKET_ID");
        console2.logBytes32(mid);
        console2.log("PILOT_USDC", pilot);
        console2.log("ZK_GATE", GATE);
        console2.log("ARMED", false);
        console2.log("NEXT: wire swapper router; seed free USDC; setArmed; FIRE_RWA_PILOT");
    }
}
