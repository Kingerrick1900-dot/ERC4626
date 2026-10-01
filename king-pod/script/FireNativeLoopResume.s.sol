// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCuratorNative} from "../src/CrownCuratorNative.sol";
import {CrownPqRegistry} from "../src/CrownPqRegistry.sol";
import {CrownStarkSnarkBridge} from "../src/CrownStarkSnarkBridge.sol";

interface IEusdM {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IAllow {
    function setAllowedBatch(address[] calldata t, bytes4[] calldata s, bool ok) external;
    function owner() external view returns (address);
}

interface ICap {
    function unlockTranche(uint256 amount, bytes32 navRoot) external;
    function canMint(uint256) external view returns (bool);
    function unlockedCapacity() external view returns (uint256);
    function mintCapacity() external view returns (uint256);
}

interface IAttestF {
    function commitPayrollRoot(bytes32 root, bool ok) external;
    function attestLive(bytes32 payloadHash) external;
}

interface IExit {
    function fundInventory(address token, uint256 amt) external;
    function exit(uint256 eusdAmt, address tokenOut, uint256 minOut, bytes32 nfc) external returns (uint256);
}

/// @notice Resume after partial FireNativeLoop (contracts live).
contract FireNativeLoopResume is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant PQ = 0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95;
    address constant BRIDGE = 0x0E88d44F0a6dbD9FF1849DB18278388d74562B07;
    address constant CAP = 0xa372d32ca9Ad06e76Ad5468767D9ae596387E4b3;
    address constant CURATOR = 0x8Cb11A67F9734143195b24D179749534099b7558;
    address constant EXIT = 0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68;
    uint256 constant SLICE = 200_000_000 ether;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 mintAmt = vm.envOr("MINT_EUSD", SLICE);

        vm.startBroadcast(pk);

        CrownPqRegistry pq = CrownPqRegistry(PQ);
        if (pq.activeDilithium() == bytes32(0)) {
            uint256 n = pq.keyCount();
            require(n > 0, "NO_KEY");
            bytes32 id = pq.keyIds(n - 1);
            pq.activate(id);
        }

        bytes32 stark = keccak256(abi.encode("NATIVE-LOOP-RESUME", mintAmt, block.timestamp));
        CrownStarkSnarkBridge(BRIDGE).commitStark(stark, keccak256("native-pi"));
        bytes32 payload = keccak256(abi.encode("STARK-SNARK", stark, keccak256("native-pi"), block.chainid));
        IAttestF(ATTEST).commitPayrollRoot(payload, true);
        IAttestF(ATTEST).attestLive(payload);

        uint256 supply = IEusdM(EUSD).totalSupply();
        uint256 unlocked = ICap(CAP).unlockedCapacity();
        uint256 need = supply + mintAmt;
        if (need > unlocked) ICap(CAP).unlockTranche(need - unlocked, keccak256("nav-native-200m"));

        if (!IEusdM(EUSD).isMinter(CURATOR)) IEusdM(EUSD).setMinter(CURATOR, true);
        CrownCuratorNative(CURATOR).setArmed(true);

        if (IAllow(ALLOWLIST).owner() == HOT) {
            address[] memory t = new address[](4);
            bytes4[] memory s = new bytes4[](4);
            t[0] = CURATOR;
            s[0] = CrownCuratorNative.nfcMintAndDeposit.selector;
            t[1] = CURATOR;
            s[1] = CrownCuratorNative.allocate.selector;
            t[2] = EXIT;
            s[2] = bytes4(keccak256("exit(uint256,address,uint256,bytes32)"));
            t[3] = EXIT;
            s[3] = bytes4(keccak256("fundInventory(address,uint256)"));
            IAllow(ALLOWLIST).setAllowedBatch(t, s, true);
        }

        require(ICap(CAP).canMint(mintAmt), "CAN_MINT");
        bytes32 nfc = keccak256(abi.encode("NFC-NATIVE-MINT-RESUME", mintAmt, block.timestamp));
        CrownCuratorNative(CURATOR).nfcMintAndDeposit(mintAmt, nfc, keccak256("nav-native-200m"));
        try CrownCuratorNative(CURATOR).allocate() {} catch {}

        vm.stopBroadcast();

        console2.log("totalMinted", CrownCuratorNative(CURATOR).totalMinted());
        console2.log("curatorEusd", IEusdM(EUSD).balanceOf(CURATOR));
        console2.log("activeDilithium", pq.activeDilithium() != bytes32(0) ? 1 : 0);
        console2.log("unlocked", ICap(CAP).unlockedCapacity());
    }
}
