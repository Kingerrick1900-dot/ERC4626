// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCuratorNative} from "../src/CrownCuratorNative.sol";
import {CrownExitNative} from "../src/CrownExitNative.sol";
import {CrownEusdSleeve} from "../src/CrownEusdSleeve.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";
import {CrownAmericaCapacity} from "../src/CrownAmericaCapacity.sol";

interface IEusdM {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IAllow {
    function setAllowedBatch(address[] calldata t, bytes4[] calldata s, bool ok) external;
    function owner() external view returns (address);
}

interface ICap {
    function unlockTranche(uint256 amount, bytes32 navRoot) external;
    function setAttest(address) external;
    function canMint(uint256) external view returns (bool);
    function unlockedCapacity() external view returns (uint256);
}

/// @notice Deploy native curator + exit; arm PQ/Stark/capacity; NFC mint 200M eUSD; allocate; scoreboard.
contract FireNativeLoop is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant OCEAN = 0xab21623705493538e7e86aacc79c0297427dc3b2;
    address constant PQ_LIVE = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant BRIDGE_LIVE = 0x0E88d44F0a6dbD9FF1849DB18278388d74562B07;
    address constant CAP_LIVE = 0xa372d32ca9Ad06e76Ad5468767D9ae596387E4b3;

    uint256 constant SLICE = 200_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        bool doMint = vm.envOr("NATIVE_MINT", uint256(1)) == 1;
        uint256 mintAmt = vm.envOr("MINT_EUSD", SLICE);

        vm.startBroadcast(pk);

        CrownCuratorNative curator = new CrownCuratorNative(EUSD, HOT, HOT);
        CrownExitNative exit = new CrownExitNative(EUSD, HOT, USDC, CBBTC, WETH, HOT);
        CrownEusdSleeve pendle = new CrownEusdSleeve(EUSD, HOT, "Pendle-PT-sleeve");
        CrownEusdSleeve aave = new CrownEusdSleeve(EUSD, HOT, "Aave-class-sleeve");

        curator.setArmor(ATTEST, PQ_LIVE, CAP_LIVE);
        curator.setStrategies(OCEAN, address(pendle), address(aave));
        curator.setWeights(5000, 2500, 2500);
        exit.setArmor(ATTEST, PQ_LIVE);

        // Dilithium active (pub hash only)
        bytes32 dilHash = keccak256(abi.encode("KE-Sov-Dilithium3-root", block.chainid));
        bytes32 dilId = CrownPqRegistry(PQ_LIVE).register(CrownPqRegistry.Alg.Dilithium3, dilHash, "king-root");
        CrownPqRegistry(PQ_LIVE).activate(dilId);

        // Stark bind
        bytes32 stark = keccak256(abi.encode("NATIVE-LOOP", mintAmt, block.timestamp));
        CrownStarkSnarkBridge(BRIDGE_LIVE).commitStark(stark, keccak256("native-pi"));
        CrownStarkSnarkBridge(BRIDGE_LIVE).bindToAttest(stark);

        // Capacity unlock 200M
        ICap(CAP_LIVE).unlockTranche(mintAmt, keccak256("nav-native-200m"));

        // Vault is minter for mint-to-self
        IEusdM(EUSD).setMinter(address(curator), true);
        curator.setArmed(true);

        // KAR allow
        if (IAllow(ALLOWLIST).owner() == HOT) {
            address[] memory t = new address[](4);
            bytes4[] memory s = new bytes4[](4);
            t[0] = address(curator);
            s[0] = CrownCuratorNative.nfcMintAndDeposit.selector;
            t[1] = address(curator);
            s[1] = CrownCuratorNative.allocate.selector;
            t[2] = address(exit);
            s[2] = CrownExitNative.exit.selector;
            t[3] = address(exit);
            s[3] = CrownExitNative.fundInventory.selector;
            IAllow(ALLOWLIST).setAllowedBatch(t, s, true);
        }

        bytes32 nfc = keccak256(abi.encode("NFC-NATIVE-MINT", mintAmt, block.timestamp));
        if (doMint) {
            require(ICap(CAP_LIVE).canMint(mintAmt), "CAN_MINT");
            curator.nfcMintAndDeposit(mintAmt, nfc, keccak256("nav-native-200m"));
            // allocate may fail on Ocean non-4626 — try
            try curator.allocate() {} catch {}
        }

        vm.stopBroadcast();

        console2.log("CrownCuratorNative", address(curator));
        console2.log("CrownExitNative", address(exit));
        console2.log("PendleSleeve", address(pendle));
        console2.log("AaveSleeve", address(aave));
        console2.log("totalMinted", curator.totalMinted());
        console2.log("curatorEusd", IEusdM(EUSD).balanceOf(address(curator)));
        console2.log("unlocked", ICap(CAP_LIVE).unlockedCapacity());
        console2.log("dilithium", uint256(CrownPqRegistry(PQ_LIVE).activeDilithium() != bytes32(0) ? 1 : 0));
    }
}
