// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownParallelSettlement} from "../src/china/CrownParallelSettlement.sol";
import {CrownRoyalCardNFC} from "../src/china/CrownRoyalCardNFC.sol";
import {CrownCIPSCorridor} from "../src/china/CrownCIPSCorridor.sol";
import {CrownStealthRouter} from "../src/china/CrownStealthRouter.sol";
import {CrownMultiAssetHunter} from "../src/CrownMultiAssetHunter.sol";

interface IHuntAdmin {
    function setHunter(address h, bool ok) external;
    function setTarget(address t, bool ok) external;
    function hunter(address) external view returns (bool);
}

interface IPayAdmin {
    function setMerchant(address m, bool ok) external;
}

/// @notice Fire CN builds — Polygon commerce trio + Base stealth hunt router.
contract FireCnBuilds is Script {
    // Polygon
    address constant POLY_EUSD = 0xd8A639BbD49e02eA590569D548d578e8345baf50;
    address constant POLY_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant POLY_PAY = 0x2FAEd8D83f61d157419b33F7938aDCd9F2c4f629;
    address constant POLY_OPEN = 0xe3e165C8823d35966C85353D5A4f257623417a7c;
    address constant POLY_ATTEST = 0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211;
    // Base hunt
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant HUNT = 0xc4c63f8CD4182452f665e338F87b4d31aeF04516;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function runPolygon() external {
        uint256 pk = vm.envUint("POLY_KEY");
        address desk = vm.addr(pk);
        vm.startBroadcast(pk);

        CrownParallelSettlement par = new CrownParallelSettlement(POLY_EUSD, desk);
        par.setModules(POLY_ATTEST, desk);

        CrownRoyalCardNFC nfc = new CrownRoyalCardNFC(POLY_EUSD, desk);
        nfc.setModules(POLY_PAY, POLY_ATTEST, desk);
        // Live PayAdapter may lack setPuller — NFC falls back if puller unset

        CrownCIPSCorridor cips = new CrownCIPSCorridor(POLY_EUSD, POLY_USDC, desk);
        cips.setModules(POLY_OPEN, POLY_ATTEST, desk);
        IPayAdmin(POLY_PAY).setMerchant(desk, true);

        vm.stopBroadcast();
        console2.log("Parallel", address(par));
        console2.log("RoyalCardNFC", address(nfc));
        console2.log("CIPSCorridor", address(cips));
    }

    function runBaseStealth() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        vm.startBroadcast(pk);

        CrownStealthRouter stealth =
            new CrownStealthRouter(HUNT, HOT, WETH, CBBTC, USDC, HOT);
        stealth.setAttest(BASE_ATTEST);

        // 3 bots (reuse MultiAssetHunter pattern as stealth bot EOAs via contracts)
        CrownMultiAssetHunter b1 = new CrownMultiAssetHunter(HUNT, HOT, WETH, CBBTC, USDC, HOT);
        CrownMultiAssetHunter b2 = new CrownMultiAssetHunter(HUNT, HOT, WETH, CBBTC, USDC, HOT);
        CrownMultiAssetHunter b3 = new CrownMultiAssetHunter(HUNT, HOT, WETH, CBBTC, USDC, HOT);

        stealth.setBot(address(b1), true);
        stealth.setBot(address(b2), true);
        stealth.setBot(address(b3), true);
        // Also allow stealth itself as hunt caller path via owner — arm stealth as hunter
        IHuntAdmin(HUNT).setHunter(address(stealth), true);
        IHuntAdmin(HUNT).setHunter(address(b1), true);
        IHuntAdmin(HUNT).setHunter(address(b2), true);
        IHuntAdmin(HUNT).setHunter(address(b3), true);

        vm.stopBroadcast();
        console2.log("StealthRouter", address(stealth));
        console2.log("bot1", address(b1));
        console2.log("bot2", address(b2));
        console2.log("bot3", address(b3));
    }
}
