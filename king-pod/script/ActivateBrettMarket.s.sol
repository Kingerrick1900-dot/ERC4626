// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorpho {
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

    function reallocate(MarketAllocation[] calldata allocations) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function totalAssets() external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
}

interface IMorphoView {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Activate BRETT on yRSS: BRETT-first queue + reallocate free/idle USDC into BRETT.
/// @dev RSS book is 100% util — cannot pull from there. Idle + cbBTC dust → BRETT.
contract ActivateBrettMarket is Script {
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
    address constant BRETT_ORACLE = 0x3378E48fF1e6bEf07d4d7F6Bb1e87C38A58D2619;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant BRETT_LLTV = 625000000000000000;

    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        (address cbLoan, address cbColl, address cbOrc, address cbIrm, uint256 cbLltv) =
            IMorphoView(MORPHO).idToMarketParams(CBBTC_M);

        (uint256 brettBefore,,) = IMorphoView(MORPHO).position(BRETT_M, YRSS);
        (uint128 rssSup,, uint128 rssBor,,,) = IMorphoView(MORPHO).market(RSS_M);
        console2.log("totalAssets", IMetaMorpho(YRSS).totalAssets());
        console2.log("rssMarketFree", uint256(rssSup) > uint256(rssBor) ? uint256(rssSup) - uint256(rssBor) : 0);
        console2.log("brettSharesBefore", brettBefore);

        IMetaMorpho.MarketParams memory brettMp = IMetaMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: BRETT,
            oracle: BRETT_ORACLE,
            irm: IRM,
            lltv: BRETT_LLTV
        });
        IMetaMorpho.MarketParams memory cbMp = IMetaMorpho.MarketParams({
            loanToken: cbLoan,
            collateralToken: cbColl,
            oracle: cbOrc,
            irm: cbIrm,
            lltv: cbLltv
        });

        vm.startBroadcast(pk);

        // BRETT first — new depositor USDC hits BRETT immediately (King is curator)
        bytes32[] memory queue = new bytes32[](4);
        queue[0] = BRETT_M;
        queue[1] = RSS_M;
        queue[2] = CBBTC_M;
        queue[3] = WETH_M;
        IMetaMorpho(YRSS).setSupplyQueue(queue);

        // Withdraw all from cbBTC (dust) + push idle + withdrawn into BRETT
        IMetaMorpho.MarketAllocation[] memory allocs = new IMetaMorpho.MarketAllocation[](2);
        allocs[0] = IMetaMorpho.MarketAllocation({marketParams: cbMp, assets: 0});
        allocs[1] = IMetaMorpho.MarketAllocation({marketParams: brettMp, assets: type(uint256).max});
        IMetaMorpho(YRSS).reallocate(allocs);

        vm.stopBroadcast();

        (uint256 brettAfter,,) = IMorphoView(MORPHO).position(BRETT_M, YRSS);
        (uint128 bSup,,,,,) = IMorphoView(MORPHO).market(BRETT_M);
        console2.log("brettSharesAfter", brettAfter);
        console2.log("brettMarketSupply", uint256(bSup));
        console2.logBytes32(IMetaMorpho(YRSS).supplyQueue(0));
    }
}
