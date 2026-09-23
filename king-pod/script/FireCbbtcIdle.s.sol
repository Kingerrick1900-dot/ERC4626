// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCbbtcIdlePuller} from "../src/CrownCbbtcIdlePuller.sol";

interface IMorphoS {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy + arm CrownCbbtcIdlePuller. Fire pullMillions when HOT holds enough cbBTC.
/// @dev KING_GO=1 FIRE_CBBTC_IDLE=1 forge script script/FireCbbtcIdle.s.sol:FireCbbtcIdle --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireCbbtcIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    // Uniswap SwapRouter02 on Base
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;

    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant CBBTC_MKT = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address l1, address c1, address o1,, uint256 lltv1) = IMorphoS(MORPHO).idToMarketParams(PARK);
        (address l2, address c2, address o2,, uint256 lltv2) = IMorphoS(MORPHO).idToMarketParams(CBBTC_MKT);
        require(l1 == USDC && c1 == RSS, "PARK");
        require(l2 == USDC && c2 == CBBTC, "CBBTC");

        bool doFire = vm.envOr("FIRE_CBBTC_IDLE", uint256(0)) == 1;
        uint256 ask = vm.envOr("IDLE_ASK", uint256(1_500_000e6));

        vm.startBroadcast(pk);

        CrownCbbtcIdlePuller puller =
            new CrownCbbtcIdlePuller(MORPHO, USDC, CBBTC, HOT, ROUTER, uint24(500), HOT);
        puller.setMarkets(RSS, o1, o2, IRM, lltv1, lltv2, PARK, CBBTC_MKT);
        puller.setArmed(true);
        puller.setMinIdleBuffer(ask);

        uint256 collNeed = puller.quoteCollForIdle(ask);
        uint256 kingCb = IERC20S(CBBTC).balanceOf(HOT);
        uint256 maxNow = puller.quoteMaxIdle(kingCb);

        console2.log("CrownCbbtcIdlePuller", address(puller));
        console2.log("ask_usdc", ask);
        console2.log("coll_need_cbbtc_wei", collNeed);
        console2.log("hot_cbbtc", kingCb);
        console2.log("max_pull_now", maxNow);
        console2.log("idle_park", puller.idlePark());
        console2.log("idle_cbbtc_book", puller.idleCbbtcBook());

        if (doFire && kingCb >= collNeed && maxNow >= ask) {
            IERC20S(CBBTC).approve(address(puller), collNeed);
            uint256 got = puller.pullIdle(ask, collNeed);
            console2.log("FIRED_idle_after", got);
            console2.log("total_pulled", puller.totalIdlePulled());
        } else {
            console2.log("ARMED_await_cbbtc", collNeed > kingCb ? collNeed - kingCb : 0);
            console2.log("dust_ladder", "Unlatch+FakeIdle+Ocean+KingRail+CbbtcPuller");
        }

        vm.stopBroadcast();
    }
}
