// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoSeed {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

/// @notice Seed EVERY Kingdom-owned Blue market with $1 USDC supply.
/// @dev KING_OK=1 + FIRE_SEED=1 to broadcast.
///      PRE: hot must hold >= $3 USDC (send $2 from Landing first).
contract SeedKingdomMarketsOneUsdc is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant ORACLE_RSS = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant ORACLE_BRETT = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    uint256 constant ONE = 1e6;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_625 = 625000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "LIVE-FIRE-LAW: need KING_OK=1");
        bool doFire = vm.envOr("FIRE_SEED", uint256(0)) == 1;
        uint256 highLltv = vm.envOr("HIGH_LLTV", LLTV_915);

        IMorphoSeed.MarketParams memory rss77 = IMorphoSeed.MarketParams(USDC, RSS, ORACLE_RSS, IRM, LLTV_77);
        IMorphoSeed.MarketParams memory brett = IMorphoSeed.MarketParams(USDC, BRETT, ORACLE_BRETT, IRM, LLTV_625);
        IMorphoSeed.MarketParams memory rssHi = IMorphoSeed.MarketParams(USDC, RSS, ORACLE_RSS, IRM, highLltv);

        bytes32 id77 = keccak256(abi.encode(rss77));
        bytes32 idBrett = keccak256(abi.encode(brett));
        bytes32 idHi = keccak256(abi.encode(rssHi));

        console2.log("=== SEED $1 EVERY KINGDOM MARKET ===");
        console2.logBytes32(id77);
        console2.logBytes32(idBrett);
        console2.logBytes32(idHi);
        console2.log("hotUsdc", IERC20S(USDC).balanceOf(HOT));
        console2.log("landUsdc", IERC20S(USDC).balanceOf(LANDING));
        console2.log("PRE: send $2 USDC Landing->hot so hot >= $3");
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(IMorphoSeed(MORPHO).idToMarketParams(idHi).loanToken == USDC, "HIGH_LLTV_MARKET_MISSING");

        if (!doFire) {
            console2.log("DRY: would supply $1 x3");
            console2.log("READY", uint256(0));
            return;
        }

        require(IERC20S(USDC).balanceOf(HOT) >= 3 * ONE, "NEED_3_USDC_ON_HOT");

        vm.startBroadcast(pk);
        IERC20S(USDC).approve(MORPHO, 3 * ONE);
        IMorphoSeed(MORPHO).supply(rss77, ONE, 0, HOT, "");
        IMorphoSeed(MORPHO).supply(brett, ONE, 0, HOT, "");
        IMorphoSeed(MORPHO).supply(rssHi, ONE, 0, HOT, "");
        vm.stopBroadcast();

        (uint128 s77,,,,,) = IMorphoSeed(MORPHO).market(id77);
        (uint128 sB,,,,,) = IMorphoSeed(MORPHO).market(idBrett);
        (uint128 sH,,,,,) = IMorphoSeed(MORPHO).market(idHi);
        console2.log("supplyRss77", uint256(s77));
        console2.log("supplyBrett", uint256(sB));
        console2.log("supplyRssHigh", uint256(sH));
        require(s77 >= ONE && sB >= ONE && sH >= ONE, "SEED_VERIFY");
        console2.log("SEEDED");
        console2.log("READY", uint256(1));
    }
}
