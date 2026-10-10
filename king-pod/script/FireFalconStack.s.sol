// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownHotOracle50k} from "../src/CrownHotOracle50k.sol";
import {CrownKRT} from "../src/CrownKRT.sol";
import {CrownGusd} from "../src/CrownGusd.sol";
import {CrownHarvester} from "../src/CrownHarvester.sol";
import {Crown369} from "../src/Crown369.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function isLltvEnabled(uint256) external view returns (bool);
}

interface IERC20F {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_FALCON_STACK=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Deploy oracle+KRT+gUSD+Harvester+369, fire Base 3 markets, spoil-seed eUSD idle.
contract FireFalconStack is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant LLTV_385 = 385000000000000000;

    function run() external {
        require(vm.envOr("FIRE_FALCON_STACK", uint256(0)) == 1, "FIRE_FALCON_STACK");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMorphoF(MORPHO).isLltvEnabled(LLTV_385), "LLTV");

        uint256 seed = vm.envOr("SEED_AMT", uint256(5_000_000e18));
        uint256 eBal = IERC20F(EUSD).balanceOf(HOT);
        if (seed > eBal) seed = eBal;

        vm.startBroadcast(pk);

        CrownHotOracle50k oracle = new CrownHotOracle50k(HOT);
        CrownKRT krt = new CrownKRT(HOT, SAFE);
        CrownGusd gusd = new CrownGusd(HOT);
        // mint bootstrap gUSD inventory for markets/POL later
        gusd.mint(HOT, 1_000_000e18);
        krt.mint(HOT, 1_000_000e18);

        CrownHarvester harvester = new CrownHarvester(MORPHO, HOT, HOT);
        Crown369 c369 = new Crown369(MORPHO, RSS, IRM, LLTV_385, HOT);
        c369.setTokens(address(krt), EUSD, address(gusd), address(oracle));

        // Fire Base 3 markets (KRT / eUSD / gUSD vs RSS @ 38.5%)
        (bytes32 idK, bytes32 idE, bytes32 idG) = c369.fireBase3();

        // Wire harvester to eUSD/RSS 38.5% market and spoil-seed
        harvester.setRailParams(EUSD, RSS, address(oracle), IRM, LLTV_385);
        if (seed > 0) {
            IERC20F(EUSD).approve(address(harvester), seed);
            harvester.seedRail(seed);
        }

        vm.stopBroadcast();

        console2.log("ORACLE", address(oracle));
        console2.log("KRT", address(krt));
        console2.log("GUSD", address(gusd));
        console2.log("HARVESTER", address(harvester));
        console2.log("CROWN369", address(c369));
        console2.log("MKT_KRT", uint256(idK));
        console2.log("MKT_EUSD", uint256(idE));
        console2.log("MKT_GUSD", uint256(idG));
        console2.log("SEEDED_EUSD", seed);
        console2.log("MISSION falcon stack base lit");
    }
}
