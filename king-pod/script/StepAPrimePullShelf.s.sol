// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoStepA {
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

interface IMorphoViewA {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @notice STEP A (internal): Stock the PA pull shelf — yRSS USDC into cbBTC/USDC book.
/// @dev Pattern from ActivateBrettMarket.s.sol. Curator-only. No King wallet USDC.
///      After this, FireKingLoanRestore PA-pulls cbBTC → RSS → borrow to wallet.
///      Gates: KING_GO=1 STEP_A=1
contract StepAPrimePullShelf is Script {
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant RSS_ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_RSS = 770000000000000000;

    bytes32 constant RSS_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT_ID = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO");
        require(vm.envOr("STEP_A", uint256(0)) == 1, "NO-STEP-A");

        uint256 tvl = IMetaMorphoStepA(YRSS).totalAssets();
        console2.log("yRSS totalAssets", tvl);
        bool hasTvl = tvl > 1e6;
        if (!hasTvl) {
            console2.log("SHELF EMPTY: setting queue now, skipping reallocate");
        }

        (address cbLoan, address cbColl, address cbOrc, address cbIrm, uint256 cbLltv) =
            IMorphoViewA(MORPHO).idToMarketParams(CBBTC_ID);
        (address wLoan, address wColl, address wOrc, address wIrm, uint256 wLltv) =
            IMorphoViewA(MORPHO).idToMarketParams(WETH_ID);
        (address brLoan, address brColl, address brOrc, address brIrm, uint256 brLltv) =
            IMorphoViewA(MORPHO).idToMarketParams(BRETT_ID);

        IMetaMorphoStepA.MarketParams memory rssMp = IMetaMorphoStepA.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: RSS_ORACLE,
            irm: IRM,
            lltv: LLTV_RSS
        });
        IMetaMorphoStepA.MarketParams memory cbMp = IMetaMorphoStepA.MarketParams({
            loanToken: cbLoan,
            collateralToken: cbColl,
            oracle: cbOrc,
            irm: cbIrm,
            lltv: cbLltv
        });
        IMetaMorphoStepA.MarketParams memory wMp = IMetaMorphoStepA.MarketParams({
            loanToken: wLoan,
            collateralToken: wColl,
            oracle: wOrc,
            irm: wIrm,
            lltv: wLltv
        });
        IMetaMorphoStepA.MarketParams memory brMp = IMetaMorphoStepA.MarketParams({
            loanToken: brLoan,
            collateralToken: brColl,
            oracle: brOrc,
            irm: brIrm,
            lltv: brLltv
        });

        vm.startBroadcast(pk);

        // Deep book first — new deposits + realloc target cbBTC shelf
        bytes32[] memory queue = new bytes32[](4);
        queue[0] = CBBTC_ID;
        queue[1] = WETH_ID;
        queue[2] = RSS_ID;
        queue[3] = BRETT_ID;
        IMetaMorphoStepA(YRSS).setSupplyQueue(queue);

        // Drain RSS/BRETT/WETH allocations → push all into cbBTC (PA maxOut source)
        if (hasTvl) {
            IMetaMorphoStepA.MarketAllocation[] memory allocs = new IMetaMorphoStepA.MarketAllocation[](4);
            allocs[0] = IMetaMorphoStepA.MarketAllocation({marketParams: rssMp, assets: 0});
            allocs[1] = IMetaMorphoStepA.MarketAllocation({marketParams: brMp, assets: 0});
            allocs[2] = IMetaMorphoStepA.MarketAllocation({marketParams: wMp, assets: 0});
            allocs[3] = IMetaMorphoStepA.MarketAllocation({marketParams: cbMp, assets: type(uint256).max});
            IMetaMorphoStepA(YRSS).reallocate(allocs);
        }

        vm.stopBroadcast();

        (uint256 cbSupply,,) = IMorphoViewA(MORPHO).position(CBBTC_ID, YRSS);
        console2.log("STEP_A_DONE cbBtcSupplyShares", cbSupply);
    }
}
