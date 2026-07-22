// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssLbp} from "../src/CrownRssLbp.sol";
import {CrownPcvController} from "../src/CrownPcvController.sol";

interface IERC20P {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice PCV 700k seed blueprint — deploy controller + LBP, fund PCV, seed LBP, post Morpho book.
/// @dev KING_OK=1 FIRE_PCV_SEED=1
///      PCV_RSS default 200_000e18 (floor 100k + 50k LBP + 50k Morpho book)
///      LBP_RSS default 50_000e18 · LBP_USDC default 1e6 · DURATION default 172800 (48h)
contract FirePcvSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant OTC_ETH = 0x683886A3911323e92A6C764c3331CAC168D0029E;
    address constant MULTI = 0xbC47996a7B34F049DF4701116BA7936F360a7242;
    address constant VAULT_V2 = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_PCV_SEED", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 pcvRss = vm.envOr("PCV_RSS", uint256(200_000 ether));
        uint256 lbpRss = vm.envOr("LBP_RSS", uint256(50_000 ether));
        uint256 lbpUsdc = vm.envOr("LBP_USDC", uint256(1e6));
        uint64 duration = uint64(vm.envOr("DURATION", uint256(172_800))); // 48h
        uint256 morphoBook = vm.envOr("MORPHO_BOOK", uint256(50_000 ether));

        vm.startBroadcast(pk);

        CrownRssLbp lbp = new CrownRssLbp(RSS, USDC, LANDING, HOT);
        CrownPcvController pcv = new CrownPcvController(
            RSS, USDC, GATE, MORPHO, LANDING, HOT, ORACLE, IRM, HOT
        );
        pcv.setRails(address(lbp), OTC_ETH, MULTI, VAULT_V2);

        // Transfer LBP ownership ops stay HOT; PCV calls lbp.seed as owner — need pcv to own lbp OR
        // seed via king approving both. Blueprint: PCV seeds LBP — transfer LBP owner to PCV.
        lbp.transferOwnership(address(pcv));

        IERC20P(RSS).approve(address(pcv), pcvRss);
        pcv.depositPcv(pcvRss);

        // USDC for LBP from hot (ops floor kept by using at most hot-1e6 if needed)
        uint256 hotUsdc = IERC20P(USDC).balanceOf(HOT);
        if (lbpUsdc > hotUsdc) lbpUsdc = hotUsdc;
        if (lbpUsdc > 0) {
            IERC20P(USDC).approve(address(pcv), lbpUsdc);
        }
        pcv.seedLbpFromPcv(lbpRss, lbpUsdc, duration);

        if (morphoBook > 0) {
            pcv.postMorphoBook(morphoBook);
        }

        vm.stopBroadcast();

        console2.log("CrownRssLbp", address(lbp));
        console2.log("CrownPcvController", address(pcv));
        console2.log("pcvRssDeposited", pcvRss);
        console2.log("lbpRss", lbpRss);
        console2.log("lbpUsdc", lbpUsdc);
        console2.log("morphoBook", morphoBook);
        console2.log("durationSec", uint256(duration));
        console2.log("vaultV2_curator_live", VAULT_V2);
        console2.log("otcEthRail", OTC_ETH);
        console2.log("multiStableRail", MULTI);
        console2.log("PCV_SEED_OK", uint256(1));
        console2.log("NOTE", "King commands - no borrow. RFQ fills USDC. LBP discovers price.");
    }
}
