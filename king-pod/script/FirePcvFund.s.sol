// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IPcvF {
    function depositPcv(uint256 amt) external;
    function seedLbpFromPcv(uint256 rssAmt, uint256 usdcAmt, uint64 durationSec) external;
    function postMorphoBook(uint256 rssColl) external;
    function pcvRss() external view returns (uint256);
    function lbp() external view returns (address);
    function setRails(address, address, address, address) external;
}

interface ILbpF {
    function live() external view returns (bool);
    function rssReserve() external view returns (uint256);
}

interface IERC20F {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fund already-deployed PCV + seed LBP + Morpho book (no redeploy).
/// @dev KING_OK=1 FIRE_PCV_FUND=1
contract FirePcvFund is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Latest successful CREATE pair from FirePcvSeed broadcast
    address constant PCV = 0x1B61Da8F654569F48AC7E2752BD3d8016ED4fcb9;
    address constant LBP = 0x70dcAb53a156936A9fBAf7785176BebDfd057012;
    address constant OTC_ETH = 0x683886A3911323e92A6C764c3331CAC168D0029E;
    address constant MULTI = 0xbC47996a7B34F049DF4701116BA7936F360a7242;
    address constant VAULT_V2 = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_PCV_FUND", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 pcvRss = vm.envOr("PCV_RSS", uint256(200_000 ether));
        uint256 lbpRss = vm.envOr("LBP_RSS", uint256(50_000 ether));
        uint256 lbpUsdc = vm.envOr("LBP_USDC", uint256(1e6));
        uint64 duration = uint64(vm.envOr("DURATION", uint256(172_800)));
        uint256 morphoBook = vm.envOr("MORPHO_BOOK", uint256(50_000 ether));

        require(IPcvF(PCV).lbp() == LBP, "LBP_MISMATCH");

        uint256 hotUsdc = IERC20F(USDC).balanceOf(HOT);
        if (lbpUsdc > hotUsdc) lbpUsdc = hotUsdc;

        vm.startBroadcast(pk);
        IPcvF(PCV).setRails(LBP, OTC_ETH, MULTI, VAULT_V2);
        IERC20F(RSS).approve(PCV, pcvRss);
        IPcvF(PCV).depositPcv(pcvRss);
        if (lbpUsdc > 0) IERC20F(USDC).approve(PCV, lbpUsdc);
        IPcvF(PCV).seedLbpFromPcv(lbpRss, lbpUsdc, duration);
        if (morphoBook > 0) IPcvF(PCV).postMorphoBook(morphoBook);
        vm.stopBroadcast();

        console2.log("PCV", PCV);
        console2.log("LBP", LBP);
        console2.log("pcvRss", IPcvF(PCV).pcvRss());
        console2.log("lbpLive", ILbpF(LBP).live());
        console2.log("lbpRssReserve", ILbpF(LBP).rssReserve());
        console2.log("PCV_FUND_OK", uint256(1));
    }
}
