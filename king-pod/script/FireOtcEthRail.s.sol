// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOtcEthRail} from "../src/CrownOtcEthRail.sol";

interface IERC20F {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IAdvF {
    function unstockKusd(uint256 amt, address to) external;
    function kusdStock() external view returns (uint256);
}

/// @notice Deploy + arm OTC → Ethereum rail. Wintermute/Kraken-size ticket ($500k–$700k).
/// @dev KING_OK=1 FIRE_OTC_ETH=1
///      STOCK_RSS (default 700_000e18) · STOCK_KUSD (default 0; pull from Advance if MOVE_ADV=1)
///      LIVE fill is desk-called: fill(usdc, rssOut, 0, MODE_ETH=2)
contract FireOtcEthRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_OTC_ETH", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 stockRss = vm.envOr("STOCK_RSS", uint256(700_000 ether));
        uint256 stockKusd = vm.envOr("STOCK_KUSD", uint256(0));

        vm.startBroadcast(pk);

        CrownOtcEthRail rail = new CrownOtcEthRail(USDC, RSS, KUSD, TOKEN_MESSENGER, LANDING, HOT);
        console2.log("CrownOtcEthRail", address(rail));
        console2.log("ethMintLanding", LANDING);
        console2.log("ethDomain", uint256(0));
        console2.log("minFill", uint256(500_000e6));

        if (stockRss > 0) {
            uint256 bal = IERC20F(RSS).balanceOf(HOT);
            if (stockRss > bal) stockRss = bal;
            IERC20F(RSS).approve(address(rail), stockRss);
            rail.stockRss(stockRss);
            console2.log("stockedRss", stockRss);
        }

        if (vm.envOr("MOVE_ADV", uint256(0)) == 1) {
            uint256 move = vm.envOr("STOCK_KUSD", uint256(700_000e6));
            uint256 avail = IAdvF(ADV).kusdStock();
            if (move > avail) move = avail;
            if (move > 0) {
                IAdvF(ADV).unstockKusd(move, HOT);
                IERC20F(KUSD).approve(address(rail), move);
                rail.stockKusd(move);
                console2.log("stockedKusdFromAdv", move);
            }
        } else if (stockKusd > 0) {
            IERC20F(KUSD).approve(address(rail), stockKusd);
            rail.stockKusd(stockKusd);
            console2.log("stockedKusd", stockKusd);
        }

        vm.stopBroadcast();

        (uint256 minF, uint256 r, uint256 k, address mintTo, uint32 dom) = rail.quote();
        console2.log("quoteMin", minF);
        console2.log("quoteRss", r);
        console2.log("quoteKusd", k);
        console2.log("quoteMintTo", mintTo);
        console2.log("quoteDomain", uint256(dom));
        console2.log("DESK_CALL", "fill(usdcAmt, usdcAmt*1e12, 0, 2) for ETH CCTP");
        console2.log("OTC_ETH_RAIL_ARMED", uint256(1));
    }
}
