// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMetaMorphoReal {
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
    function totalAssets() external view returns (uint256);
}

interface IMorphoView {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Curator reallocate: pull yRSS free/idle from deep books → RSS/$1200.
/// @dev KING_OK=1. Creates idle up to yRSS TVL (not $700k alone). Run after ArmYrss1200.
contract ReallocateYrssToRss1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE_1200 = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    bytes32 constant MID_1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant MID_CBBTC = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant MID_WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    error NOT_HOT();
    error NO_GO();

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();

        (address cbLoan, address cbColl, address cbOrc, address cbIrm, uint256 cbLltv) =
            IMorphoView(MORPHO).idToMarketParams(MID_CBBTC);
        (address wLoan, address wColl, address wOrc, address wIrm, uint256 wLltv) =
            IMorphoView(MORPHO).idToMarketParams(MID_WETH);

        IMetaMorphoReal.MarketParams memory rss1200 = IMetaMorphoReal.MarketParams({
            loanToken: USDC, collateralToken: RSS, oracle: ORACLE_1200, irm: IRM, lltv: LLTV
        });
        IMetaMorphoReal.MarketParams memory cbMp = IMetaMorphoReal.MarketParams({
            loanToken: cbLoan, collateralToken: cbColl, oracle: cbOrc, irm: cbIrm, lltv: cbLltv
        });
        IMetaMorphoReal.MarketParams memory wMp = IMetaMorphoReal.MarketParams({
            loanToken: wLoan, collateralToken: wColl, oracle: wOrc, irm: wIrm, lltv: wLltv
        });

        (uint128 s0,, uint128 b0,,,) = IMorphoView(MORPHO).market(MID_1200);
        uint256 idle0 = uint256(s0) > uint256(b0) ? uint256(s0) - uint256(b0) : 0;
        console2.log("yRSS_TVL", IMetaMorphoReal(YRSS).totalAssets());
        console2.log("idleBefore", idle0);

        vm.startBroadcast(pk);
        IMetaMorphoReal.MarketAllocation[] memory allocs = new IMetaMorphoReal.MarketAllocation[](3);
        allocs[0] = IMetaMorphoReal.MarketAllocation({marketParams: cbMp, assets: 0});
        allocs[1] = IMetaMorphoReal.MarketAllocation({marketParams: wMp, assets: 0});
        allocs[2] = IMetaMorphoReal.MarketAllocation({marketParams: rss1200, assets: type(uint256).max});
        IMetaMorphoReal(YRSS).reallocate(allocs);
        vm.stopBroadcast();

        (uint128 s1,, uint128 b1,,,) = IMorphoView(MORPHO).market(MID_1200);
        uint256 idle1 = uint256(s1) > uint256(b1) ? uint256(s1) - uint256(b1) : 0;
        console2.log("idleAfter", idle1);
        console2.log("REALLOC_YRSS_RSS1200_OK", uint256(1));
    }
}
