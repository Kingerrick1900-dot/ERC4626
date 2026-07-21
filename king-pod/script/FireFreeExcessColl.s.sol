// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoW {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20W {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Free RSS locked against dust debt. Leave cushion. KING_OK to broadcast.
contract FireFreeExcessColl is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant LLTV = 770000000000000000;
    uint256 constant KEEP_RSS = 500 ether; // cushion for ~$300 debt

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        // Remediation of scribe-left dust lock — still gate
        require(vm.envOr("KING_OK", uint256(0)) == 1, "need KING_OK=1");
        bool doFire = vm.envOr("FIRE_FREE_COLL", uint256(0)) == 1;

        IMorphoW.MarketParams memory mp = IMorphoW.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        (, uint128 bor, uint128 coll) = IMorphoW(MORPHO).position(ID, HOT);
        (,, uint128 borAssets,,,) = IMorphoW(MORPHO).market(ID);

        uint256 debtApprox = uint256(bor) * uint256(borAssets) / uint256(bor); // = borAssets if sole borrower
        // safer: if king owns all borrow shares
        (, , uint128 totBorShares,,,) = IMorphoW(MORPHO).market(ID);
        // market returns supplyAssets, supplyShares, borrowAssets, borrowShares
        (uint128 sA, uint128 sS, uint128 bA, uint128 bS,,) = IMorphoW(MORPHO).market(ID);
        uint256 debt = uint256(bS) == 0 ? 0 : uint256(bor) * uint256(bA) / uint256(bS);

        uint256 collAmt = uint256(coll);
        require(collAmt > KEEP_RSS, "NO EXCESS");
        uint256 wd = collAmt - KEEP_RSS;

        console2.log("debtUsdcApprox", debt);
        console2.log("collBefore", collAmt);
        console2.log("withdraw", wd);
        console2.log("keep", KEEP_RSS);

        if (!doFire) {
            console2.log("DRY - set FIRE_FREE_COLL=1");
            return;
        }

        uint256 rssBefore = IERC20W(RSS).balanceOf(HOT);
        vm.startBroadcast(pk);
        IMorphoW(MORPHO).withdrawCollateral(mp, wd, HOT, HOT);
        vm.stopBroadcast();
        (, , uint128 collAfter) = IMorphoW(MORPHO).position(ID, HOT);
        console2.log("collAfter", uint256(collAfter));
        console2.log("rssGained", IERC20W(RSS).balanceOf(HOT) - rssBefore);
        console2.log("READY", uint256(1));
    }
}
