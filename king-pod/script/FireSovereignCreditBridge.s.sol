// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownKRT} from "../src/CrownKRT.sol";
import {CrownSovereignCredit} from "../src/CrownSovereignCredit.sol";
import {CrownSovereignColdKrt} from "../src/CrownSovereignColdKrt.sol";

interface IAeroFactory {
    function createPool(address tokenA, address tokenB, bool stable) external returns (address);
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
}

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE_SOVEREIGN_CREDIT_BRIDGE=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Bridge: Killer PAR RSS → mint $30M KRT (200% OC) · 20% cold · create KRT/USDC Ocean pool.
///      yRSS is USDC-only — KRT does NOT enter yRSS. Ocean is the door.
contract FireSovereignCreditBridge is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant KILLER = 0x7273ffE28a0aa8323d5c8F3D23793a7fA19ebD17;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant PAR_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant BUILD2_ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;

    uint256 constant MINT_AMT = 30_000_000 ether;

    function run() external {
        require(vm.envOr("FIRE_SOVEREIGN_CREDIT_BRIDGE", uint256(0)) == 1, "FIRE_SOVEREIGN_CREDIT_BRIDGE");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownSovereignCredit credit = new CrownSovereignCredit(
            MORPHO, ZK_WALLET_GATE, BASE_ATTEST, PAR, KILLER, RSS, PAR_ORACLE, SAFE, HOT
        );

        // Credit owns KRT so it can mint; king=Safe for ZK subject.
        CrownKRT krt = new CrownKRT(ZK_WALLET_GATE, BASE_ATTEST, BUILD2_ORACLE, SOVEREIGN_RAIL, SAFE, address(credit));
        credit.wireKrt(address(krt));

        CrownSovereignColdKrt cold = new CrownSovereignColdKrt(address(krt), SAFE, HOT);
        credit.wireCold(address(cold));

        (uint256 collWei, uint256 collUsd6, uint256 maxMint,) = credit.creditCapacity();
        require(collWei > 0, "NO_KILLER_COLL");
        require(MINT_AMT <= maxMint, "OVER_CAP");

        credit.mintAndSplit(HOT, MINT_AMT);

        // Ocean door: create KRT/USDC stable pool (seed USDC when inventory exists).
        address pool = IAeroFactory(AERO_FACTORY).getPool(address(krt), USDC, true);
        if (pool == address(0)) {
            pool = IAeroFactory(AERO_FACTORY).createPool(address(krt), USDC, true);
        }

        vm.stopBroadcast();

        console2.log("CREDIT", address(credit));
        console2.log("KRT", address(krt));
        console2.log("COLD", address(cold));
        console2.log("POOL", pool);
        console2.log("COLL_WEI", collWei);
        console2.log("COLL_USD6", collUsd6);
        console2.log("MAX_MINT", maxMint);
        console2.log("HOT_KRT", IERC20B(address(krt)).balanceOf(HOT));
        console2.log("COLD_KRT", IERC20B(address(krt)).balanceOf(address(cold)));
        console2.log("BRIDGE_NOTE", "yRSS USDC-only - KRT on Ocean pool; USDC seed when seat has USDC");
    }
}
