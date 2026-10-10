// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoL {
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

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice FIRE_LANDING_EUSD_RAIL=1 · LANDING_PRIVATE_KEY
/// @dev Push Landing's ~1.32B eUSD into Morpho spoil rail; shares to Kingdom Safe.
///      Optional SEED_AMT (default = full Landing balance). Optional ON_BEHALF (default Safe).
contract FireLandingEusdRail is Script {
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    /// @dev Same spoil rail HOT already seeded (~301M idle).
    bytes32 constant EUSD_RSS = 0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599;

    function run() external {
        require(vm.envOr("FIRE_LANDING_EUSD_RAIL", uint256(0)) == 1, "FIRE_LANDING_EUSD_RAIL");
        uint256 pk = vm.envUint("LANDING_PRIVATE_KEY");
        require(vm.addr(pk) == LANDING, "NOT_LANDING");

        uint256 bal = IERC20L(EUSD).balanceOf(LANDING);
        uint256 seed = vm.envOr("SEED_AMT", bal);
        if (seed > bal) seed = bal;
        require(seed > 0, "NO_EUSD");

        address onBehalf = vm.envOr("ON_BEHALF", SAFE);

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoL(MORPHO).idToMarketParams(EUSD_RSS);
        require(loan == EUSD, "BAD_MARKET");

        console2.log("Landing eUSD", bal);
        console2.log("seed", seed);
        console2.log("onBehalf", onBehalf);

        vm.startBroadcast(pk);
        IERC20L(EUSD).approve(MORPHO, seed);
        IMorphoL(MORPHO).supply(
            IMorphoL.MarketParams(loan, coll, oracle, irm, lltv), seed, 0, onBehalf, ""
        );
        vm.stopBroadcast();

        (uint128 sa,, uint128 ba,,,) = IMorphoL(MORPHO).market(EUSD_RSS);
        (uint256 shares,,) = IMorphoL(MORPHO).position(EUSD_RSS, onBehalf);
        console2.log("marketSupply", uint256(sa));
        console2.log("marketBorrow", uint256(ba));
        console2.log("idle", uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0);
        console2.log("onBehalfShares", shares);
        console2.log("MISSION Landing 1B+ eUSD on kingdom Morpho rail");
    }
}
