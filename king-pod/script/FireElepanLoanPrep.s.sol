// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanKeepDraw} from "../src/CrownElepanKeepDraw.sol";
import {CrownElepanPreSelfLiq} from "../src/CrownElepanPreSelfLiq.sol";
import {CrownMorphoZkPack} from "../src/CrownMorphoZkPack.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoP {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IVaultFee {
    function feeRecipient() external view returns (address);
    function fee() external view returns (uint96);
}

interface IVaultFeeMut {
    function setFeeRecipient(address) external;
    function setFee(uint256) external;
}

interface IZkGateP {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

interface IZkCreditP {
    function maxBorrow(address) external view returns (uint256);
}

/// @notice PREP ONLY — ZK-gated Morpho loan + self-liq + diverse passive.
/// @dev Broadcast only if LIVE_ARMED=1 KING_GO=1 FIRE_LOAN_PREP=1.
contract FireElepanLoanPrep is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        bool liveArmed = vm.envOr("LIVE_ARMED", uint256(0)) == 1;
        bool kingGo = vm.envOr("KING_GO", uint256(0)) == 1;
        bool fire = vm.envOr("FIRE_LOAN_PREP", uint256(0)) == 1;
        bool doBroadcast = liveArmed && kingGo && fire;

        (uint128 s,, uint128 b,,,) = IMorphoP(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(s) - uint256(b);
        (uint256 sup, uint128 bor, uint128 coll) = IMorphoP(MORPHO).position(ELE_USDC, HOT);
        (uint256 attest,,) = IZkGateP(GATE).attestations(HOT);

        console2.log("=== MORPHO LOAN + ZK PACK PREP (NO IMPLIED GO) ===");
        console2.log("liveArmed", liveArmed ? uint256(1) : uint256(0));
        console2.log("willBroadcast", doBroadcast ? uint256(1) : uint256(0));
        console2.log("zkPackProven", IZkGateP(GATE).isProven(HOT) ? uint256(1) : uint256(0));
        console2.log("zkPackAttestUsdc6", attest);
        console2.log("zkPackMinThreshold", IZkGateP(GATE).minThreshold());
        console2.log("zkCreditMaxBorrow", IZkCreditP(CREDIT).maxBorrow(HOT));
        console2.log("marketIdle", idle);
        console2.log("hotSupplyShares", sup);
        console2.log("hotBorrowShares", uint256(bor));
        console2.log("hotCollEle", uint256(coll));
        console2.log("landingUsdc", IERC20P(USDC).balanceOf(LANDING));
        console2.log("yELE feeRecipient", IVaultFee(YELE).feeRecipient());
        console2.log("yRSS feeRecipient", IVaultFee(YRSS).feeRecipient());
        console2.log("--- LOAN (MORPHO) ---");
        console2.log("borrowPortion = Morpho borrow(assets,0,hot,Landing)");
        console2.log("preSelfLiq = Morpho flash self-liq");
        console2.log("--- PACK (ZK) ---");
        console2.log("gate.requireProven on Morpho actions; not a ZK loan");
        console2.log("--- PASSIVE DIVERSE ---");
        console2.log("P1 yRSS | P2 yELE@GO | P3 Blue APY | P4 skim | P5 zk credit rail | P6 Uni");

        if (!doBroadcast) {
            console2.log("PREP_ONLY_OK", uint256(1));
            console2.log("NO_BROADCAST", uint256(1));
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateP(GATE).isProven(HOT), "NOT_PROVEN");

        bool armPassive = vm.envOr("ARM_PASSIVE_FEES", uint256(1)) == 1;
        uint256 yeleFee = vm.envOr("YELE_FEE_WAD", uint256(0.1e18));

        vm.startBroadcast(pk);
        CrownMorphoZkPack book = new CrownMorphoZkPack(
            GATE, CREDIT, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, LLTV, HOT
        );
        CrownElepanKeepDraw keep = new CrownElepanKeepDraw(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        CrownElepanPreSelfLiq selfLiq = new CrownElepanPreSelfLiq(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        keep.setOperator(address(book));
        selfLiq.setOperator(address(book));
        book.wire(address(keep), address(selfLiq));

        if (armPassive) {
            IVaultFeeMut(YELE).setFeeRecipient(LANDING);
            if (IVaultFee(YELE).fee() != uint96(yeleFee)) {
                IVaultFeeMut(YELE).setFee(yeleFee);
            }
        }
        vm.stopBroadcast();

        console2.log("zkPack", address(book));
        console2.log("keepDraw", address(keep));
        console2.log("preSelfLiq", address(selfLiq));
        console2.log("MORPHO_LOAN_ZK_PACK_PREP_DEPLOYED", uint256(1));
    }
}
