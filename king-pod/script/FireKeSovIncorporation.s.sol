// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRicardian} from "../src/CrownRicardian.sol";

interface IAllowlist {
    function setAllowed(address target, bytes4 selector, bool ok) external;
    function setAllowedBatch(address[] calldata targets, bytes4[] calldata selectors, bool ok) external;
    function isAllowed(address target, bytes4 selector) external view returns (bool);
    function owner() external view returns (address);
}

interface IPublicAllocator {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IVaultAdmin {
    function setTarget(address target, bool on) external;
}

/// @notice Deploy CrownRicardian, open KAR to KE-Sov rails, raise owned PA maxIn, open 3 offers.
contract FireKeSovIncorporation is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;
    address constant PAY = 0xA6D5C5257aCA0028D98a2f2244792Ba68f09f3B1;
    address constant PSM_FILLER = 0xe93737c5275CEa3A90cEB0A28A7A0873dc107150;
    address constant VAULT = 0xc3f2ACe4161B82dbceE08Ea636467D2C3bD72458;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant RSS1 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // CrownRicardian selectors
    bytes4 constant SEL_OPEN = CrownRicardian.openOffer.selector;
    bytes4 constant SEL_STATUS = CrownRicardian.setOfferStatus.selector;
    bytes4 constant SEL_BIND = CrownRicardian.bindProse.selector;
    bytes4 constant SEL_MARK = CrownRicardian.markIncorporated.selector;
    // PayAdapter pay(address,uint256) — live KAR SEL_PAY
    bytes4 constant SEL_PAY = 0x5e5571ac;

    uint128 constant FLOW = 5_000_000e6; // $5M owned PA gate

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        // Prose hash from LEGAL-PROSE.md content committed in-repo (recomputed in test).
        bytes32 proseHash = vm.envOr(
            "PROSE_HASH",
            bytes32(0xfb464c9b1b982e7a319b57242d0369397aeaac85d2202886e4915c587d986dca)
        );
        string memory proseURI = "ipfs://ke-sov/LEGAL-PROSE.md";
        // Prefer repo-relative URI annotation
        proseURI = "deployments/ke-sov/LEGAL-PROSE.md";

        uint256 ask = vm.envOr("OFFER_USDC", uint256(700_000e6));

        vm.startBroadcast(pk);

        CrownRicardian ric = new CrownRicardian(HOT, LANDING, proseHash, proseURI);

        // KAR: open KE-Sov Ricardian + ensure PayAdapter merchant path for Landing
        IAllowlist al = IAllowlist(ALLOWLIST);
        require(al.owner() == HOT, "AL_OWNER");
        address[] memory t = new address[](5);
        bytes4[] memory s = new bytes4[](5);
        t[0] = address(ric);
        s[0] = SEL_OPEN;
        t[1] = address(ric);
        s[1] = SEL_STATUS;
        t[2] = address(ric);
        s[2] = SEL_BIND;
        t[3] = address(ric);
        s[3] = SEL_MARK;
        t[4] = PAY;
        s[4] = SEL_PAY;
        al.setAllowedBatch(t, s, true);

        // Spend vault: allow PSM filler + Ricardian as targets if admin is HOT
        try IVaultAdmin(VAULT).setTarget(address(ric), true) {} catch {}
        try IVaultAdmin(VAULT).setTarget(PSM_FILLER, true) {} catch {}

        // Owned PA: foreign-facing gate on Kingdom markets (not Gauntlet storage)
        IPublicAllocator.FlowCapsConfig[] memory caps = new IPublicAllocator.FlowCapsConfig[](2);
        caps[0] = IPublicAllocator.FlowCapsConfig({
            id: PARK, caps: IPublicAllocator.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        caps[1] = IPublicAllocator.FlowCapsConfig({
            id: RSS1, caps: IPublicAllocator.FlowCaps({maxIn: FLOW, maxOut: FLOW})
        });
        IPublicAllocator(PA).setFlowCaps(YRSS, caps);

        // Open three Ricardian offers (sent)
        bytes32 termsA = keccak256(bytes("OFFER-ANCHORX.md"));
        bytes32 termsC = keccak256(bytes("OFFER-CONFLUX.md"));
        bytes32 termsS = keccak256(bytes("OFFER-SBI.md"));
        ric.openOffer(keccak256("AnchorX"), address(0), ask, termsA);
        ric.openOffer(keccak256("Conflux"), address(0), ask, termsC);
        ric.openOffer(keccak256("SBI"), address(0), ask, termsS);

        vm.stopBroadcast();

        (uint128 parkIn,) = IPublicAllocator(PA).flowCaps(YRSS, PARK);
        (uint128 rssIn,) = IPublicAllocator(PA).flowCaps(YRSS, RSS1);

        console2.log("CrownRicardian", address(ric));
        console2.log("settlement", LANDING);
        console2.log("proseHash");
        console2.logBytes32(proseHash);
        console2.log("karOpenOffer", al.isAllowed(address(ric), SEL_OPEN) ? 1 : 0);
        console2.log("paParkMaxIn", uint256(parkIn));
        console2.log("paRssMaxIn", uint256(rssIn));
        console2.log("offers", ric.offerCount());
        console2.log("incorporated", ric.incorporated() ? 1 : 0);
    }
}
