// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoRssOracle} from "../src/MorphoRssOracle.sol";
import {
    SovereignIdleFactory,
    CrownSovereignAmoFleet,
    SupplyAmoBot
} from "../src/fleet/CrownFleetCore.sol";
import {TollBoothAutoSeeder, NoteIssuerAuto} from "../src/fleet/CrownFleetRails.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function mint(address to, uint256 amt) external;
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoF {
    function setAuthorization(address, bool) external;
}

/// @notice Crown Fleet Base: deploy factory/bot/seeder/notes + PRINT toward 1B HOT gUSD.
/// Parallel books via fresh $50k oracle clones. Legacy eUSD AMO ticks print NOW.
/// KING_GO=1 FIRE_FLEET=1 PRIVATE_KEY=… LANDING_PRIVATE_KEY=…
contract FireCrownFleetBase is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant AMO_EUSD = 0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed;
    address constant AMO_GUSD = 0x380E199070A329ADefADB43F1932Da301FFC767d;
    address constant EXIT_GUSD = 0x041416a763bDc02F396bEe05712DacE63B9B0B89;
    bytes32 constant MID_EUSD = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    bytes32 constant MID_GUSD = 0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_FLEET", uint256(0)) == 1, "NEED FIRE_FLEET=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");
        uint256 landPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);

        uint256 tickMint = vm.envOr("TICK_MINT", uint256(100_000_000e18));
        uint256 ticks = vm.envOr("TICKS", uint256(8)); // ~8×100M → push hard toward 1B
        uint256 borrowBps = vm.envOr("BORROW_BPS", uint256(7000));
        uint256 wrapBps = vm.envOr("WRAP_BPS", uint256(9000));
        uint256 openExtra = vm.envOr("OPEN_EXTRA", uint256(1)); // 1 = open 1 new eUSD + 1 new gUSD book

        // ─── 1) DEPLOY CHASSIS ───────────────────────────────────────────────
        vm.startBroadcast(hotPk);
        SovereignIdleFactory factory = new SovereignIdleFactory(MORPHO, RSS, GATE, HOT, LANDING, IRM, LLTV, HOT);
        factory.registerBook(MID_EUSD, EUSD, ORACLE50, AMO_EUSD, address(0), false);
        factory.registerBook(MID_GUSD, GUSD, ORACLE50, AMO_GUSD, EXIT_GUSD, true);
        console2.log("factory", address(factory));
        console2.log("books", factory.bookCount());

        SupplyAmoBot bot = new SupplyAmoBot(EUSD, GUSD, HOT, LANDING, HOT);
        bot.setPrimaryAmo(AMO_EUSD, false);
        bot.setParams(tickMint, borrowBps, wrapBps, 1_000_000_000e18);
        console2.log("bot", address(bot));

        TollBoothAutoSeeder seeder = new TollBoothAutoSeeder(EUSD, USDC, GUSD, PSM, HOT, HOT);
        seeder.setArmed(true);
        console2.log("seeder", address(seeder));
        console2.log("seederCanSeed", seeder.canSeed());

        NoteIssuerAuto notes = new NoteIssuerAuto(
            RSS, PSM, HOT, MORPHO, bytes32(0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88), HOT
        );
        notes.setArmed(true);
        console2.log("notes", address(notes));
        console2.log("borrowCapacity", notes.borrowCapacity());
        console2.log("notesCanIssue", notes.canIssue());

        if (openExtra > 0) {
            MorphoRssOracle o1 = new MorphoRssOracle(50_000);
            MorphoRssOracle o2 = new MorphoRssOracle(50_000);
            (bytes32 mid1, address amo1,) = factory.openBook(EUSD, address(o1), false);
            (bytes32 mid2, address amo2,) = factory.openBook(GUSD, address(o2), true);
            console2.logBytes32(mid1);
            console2.log("fleetAmoEusd", amo1);
            console2.logBytes32(mid2);
            console2.log("fleetAmoGusd", amo2);
            IMorphoF(MORPHO).setAuthorization(amo1, true);
            IMorphoF(MORPHO).setAuthorization(amo2, true);
            // Landing owns fleet AMOs — setOperator(bot) + gate off for first fill later
        }
        vm.stopBroadcast();

        // Landing: infinite approve legacy AMO for print ticks
        vm.startBroadcast(landPk);
        IERC20F(EUSD).approve(AMO_EUSD, type(uint256).max);
        vm.stopBroadcast();

        // ─── 2) PRINT NOW on live eUSD AMO (Base Fed) ───────────────────────
        CrownSovereignAmo amoE = CrownSovereignAmo(AMO_EUSD);
        for (uint256 i = 0; i < ticks; i++) {
            uint256 hotG = IERC20F(GUSD).balanceOf(HOT);
            if (hotG >= 1_000_000_000e18) {
                console2.log("TARGET_1B_HIT", hotG);
                break;
            }

            vm.startBroadcast(hotPk);
            IERC20F(EUSD).mint(LANDING, tickMint);
            amoE.supplyAmo(LANDING, tickMint);
            uint256 idle = amoE.idle();
            uint256 ask = (idle * borrowBps) / 10_000;
            uint256 e0 = IERC20F(EUSD).balanceOf(HOT);
            amoE.borrowEusd(ask, HOT);
            uint256 got = IERC20F(EUSD).balanceOf(HOT) - e0;
            uint256 wrapAmt = (got * wrapBps) / 10_000;
            if (wrapAmt > 0) {
                IERC20F(EUSD).approve(GUSD, wrapAmt);
                CrownGoldUsd(GUSD).wrap(wrapAmt, HOT);
            }
            console2.log("tick", i);
            console2.log("hotGusd", IERC20F(GUSD).balanceOf(HOT));
            console2.log("idle", amoE.idle());
            vm.stopBroadcast();
        }

        (uint256 idleE, uint256 supE, uint256 borE, bool proven) = amoE.book();
        console2.log("eusdIdle", idleE);
        console2.log("eusdSupply", supE);
        console2.log("eusdBorrow", borE);
        console2.log("proven", proven);
        console2.log("hotGusdFinal", IERC20F(GUSD).balanceOf(HOT));
        console2.log("hotEusdFinal", IERC20F(EUSD).balanceOf(HOT));
        console2.log("CROWN_FLEET_BASE_OK", uint256(1));
    }
}
