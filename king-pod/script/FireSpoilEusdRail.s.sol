// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoS {
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

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice SPOIL: seed Morpho eUSD/RSS market with HOT's funded eUSD — real idle, not flash.
/// @dev FIRE_SPOIL_EUSD_RAIL=1 · ZK_SHIELD=1 · HOT_KEY · WalletGate isProven(HOT+Safe) · bordersSecure
contract FireSpoilEusdRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

    function run() external {
        require(vm.envOr("FIRE_SPOIL_EUSD_RAIL", uint256(0)) == 1, "FIRE_SPOIL_EUSD_RAIL");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 bal = IERC20S(EUSD).balanceOf(HOT);
        uint256 seed = vm.envOr("SEED_AMT", uint256(10_000_000e18));
        if (seed > bal) seed = bal;
        require(seed > 0, "NO_EUSD");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoS(MORPHO).idToMarketParams(EUSD_RSS);
        require(loan == EUSD, "BAD_MARKET");

        console2.log("HOT eUSD bal", bal);
        console2.log("seed", seed);

        vm.startBroadcast(pk);
        IERC20S(EUSD).approve(MORPHO, seed);
        IMorphoS(MORPHO).supply(
            IMorphoS.MarketParams(loan, coll, oracle, irm, lltv), seed, 0, HOT, ""
        );
        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoS(MORPHO).market(EUSD_RSS);
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("idle", uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0);
        console2.log("MISSION spoil eUSD rail seeded");
    }
}
