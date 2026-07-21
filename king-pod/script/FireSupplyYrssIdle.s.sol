// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IYrssS {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function totalAssets() external view returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;
}

interface IMorphoS {
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Push idle yRSS USDC into Morpho books (RSS77 + BRETT split).
contract FireSupplyYrssIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant BRETT_ORACLE = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_SUPPLY", uint256(0)) == 1, "FIRE_SUPPLY=1");

        uint256 tvl = IYrssS(YRSS).totalAssets();
        uint256 brettPct = vm.envOr("BRETT_BPS", uint256(3000)); // 30% BRETT / 70% RSS default
        uint256 toBrett = (tvl * brettPct) / 10_000;
        uint256 toRss = tvl - toBrett;

        IYrssS.MarketParams memory rssMp =
            IYrssS.MarketParams(USDC, RSS, RSS_ORACLE, IRM, 770000000000000000);
        IYrssS.MarketParams memory brettMp =
            IYrssS.MarketParams(USDC, BRETT, BRETT_ORACLE, IRM, 625000000000000000);

        console2.log("yrssTvl", tvl);
        console2.log("toRss", toRss);
        console2.log("toBrett", toBrett);

        vm.startBroadcast(pk);
        IYrssS.MarketAllocation[] memory a = new IYrssS.MarketAllocation[](2);
        a[0] = IYrssS.MarketAllocation({marketParams: rssMp, assets: toRss});
        a[1] = IYrssS.MarketAllocation({marketParams: brettMp, assets: toBrett});
        IYrssS(YRSS).reallocate(a);
        vm.stopBroadcast();

        (uint128 rs,,,,,) = IMorphoS(MORPHO).market(RSS77);
        (uint128 bs,,,,,) = IMorphoS(MORPHO).market(BRETT_M);
        console2.log("rssSupply", uint256(rs));
        console2.log("brettSupply", uint256(bs));
        console2.log("SUPPLY_OK", uint256(1));
    }
}
