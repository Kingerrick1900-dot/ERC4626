// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownAaveSleeve} from "../src/CrownAaveSleeve.sol";
import {CrownExitNative} from "../src/CrownExitNative.sol";
import {CrownEusdSleeve} from "../src/CrownEusdSleeve.sol";
import {CrownCuratorNative} from "../src/CrownCuratorNative.sol";

interface ICold {
    function armOutflow(bool armed) external;
    function setRedemptionSink(address sink) external;
    function releaseToSink(uint256 amount, bytes32 reason) external;
    function balance() external view returns (uint256);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Finish Path C: seed Exit from Cold (Kingdom liquidity) → exit eUSD→USDC to HOT → Aave supply slice.
contract FireNativeLoopFinish is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    address constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant AAVE_EUSD_SLEEVE = 0x3c55Ef84eE345e05B60039512daEd331a4d5C441; // park sleeve holding 50M eUSD
    address constant CURATOR = 0x8Cb11A67F9734143195b24D179749534099b7558;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 coldBal = ICold(COLD).balance();
        require(coldBal > 0, "NO_COLD");

        // eUSD needed at default rate 1e12 (1e18 eUSD per 1e6 USDC)
        uint256 eusdNeed = coldBal * 1e12;
        // Keep ≥50% of exited USDC on HOT for scoreboard; rest → Aave
        uint256 aaveShare = coldBal / 2;
        uint256 hotKeep = coldBal - aaveShare;

        vm.startBroadcast(pk);

        CrownAaveSleeve aave = new CrownAaveSleeve(USDC, AAVE_POOL, HOT, HOT);

        // 1) Kingdom cold → Exit inventory (hunt/cold liquidity, not outside beg)
        ICold(COLD).armOutflow(true);
        ICold(COLD).setRedemptionSink(EXIT);
        ICold(COLD).releaseToSink(coldBal, keccak256("EXIT-SEED"));

        // Exit already holds USDC; fundInventory not needed if released to EXIT directly —
        // but Exit.fundInventory expects transferFrom. releaseToSink sent USDC to EXIT address = inventory.
        // CrownExitNative.inventory reads balanceOf — OK without fundInventory event path.

        // 2) Pull matching eUSD from Aave-class eUSD park sleeve → HOT
        CrownEusdSleeve(AAVE_EUSD_SLEEVE).pull(HOT, eusdNeed);

        // 3) Exit eUSD → USDC to HOT
        IERC20b(EUSD).approve(EXIT, eusdNeed);
        bytes32 nfc = keccak256(abi.encode("NFC-EXIT-FINISH", coldBal, block.timestamp));
        uint256 out = CrownExitNative(EXIT).exit(eusdNeed, USDC, coldBal, nfc);
        require(out >= coldBal, "OUT");

        // 4) Real Aave supply (half); remainder stays HOT for scoreboard
        IERC20b(USDC).approve(address(aave), aaveShare);
        aave.fundFrom(HOT, aaveShare);
        aave.supply(aaveShare);

        vm.stopBroadcast();

        console2.log("CrownAaveSleeve", address(aave));
        console2.log("exitedUsdc", out);
        console2.log("hotUsdc", IERC20b(USDC).balanceOf(HOT));
        console2.log("aaveSleeveUsdcHeld", IERC20b(USDC).balanceOf(address(aave)));
        console2.log("hotKeepTarget", hotKeep);
        console2.log("curatorMinted", CrownCuratorNative(CURATOR).totalMinted());
        console2.log("exitEusdHeld", IERC20b(EUSD).balanceOf(EXIT));
    }
}
