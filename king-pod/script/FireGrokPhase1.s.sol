// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanGrokPhase1} from "../src/CrownElepanGrokPhase1.sol";

interface IMorphoP1 {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20P1 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IMetaP1 {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function submitFee(uint256 newFee) external;
    function setFeeRecipient(address) external;
    function owner() external view returns (address);
}

/// @notice Grok Phase 1 fire. KING_GO=1 FIRE_GROK_P1=1 to broadcast loan.
contract FireGrokPhase1 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant ASK = 13_000_000e6;
    uint256 constant MAX_LTV_BPS = 6450;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        bool doFire = vm.envOr("FIRE_GROK_P1", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", ASK);
        address spend = vm.envOr("SPEND_TO", KING_VAULT);
        address earnTo = vm.envOr("EARN_SHARES_TO", LANDING);

        uint256 eleFree = IERC20P1(ELEPAN).balanceOf(HOT);
        (, , uint128 coll) = IMorphoP1(MORPHO).position(ELE_USDC, HOT);
        uint256 totalColl = uint256(coll) + eleFree;
        uint256 maxBorrow = (totalColl * MAX_LTV_BPS * 1e6) / (10_000 * 1e8);
        uint256 morphoInv = IERC20P1(USDC).balanceOf(MORPHO);
        uint256 yeleAssets = IMetaP1(YELE).totalAssets();

        // HF vs LLTV 77%: collValue/debt ; soft $1
        uint256 hfWad = borrowUsdc == 0 ? type(uint256).max : (totalColl * 1e18 * 1e6) / (borrowUsdc * 1e8);

        console2.log("=== GROK PHASE 1 PREFLIGHT ===");
        console2.log("eleFreeHot", eleFree);
        console2.log("eleCollHot", uint256(coll));
        console2.log("totalColl", totalColl);
        console2.log("maxBorrow6450", maxBorrow);
        console2.log("borrowAsk", borrowUsdc);
        console2.log("hfRawWad_ifAsk", hfWad);
        console2.log("morphoUsdcInv", morphoInv);
        console2.log("yeleAssets", yeleAssets);
        console2.log("queue0");
        console2.logBytes32(IMetaP1(YELE).supplyQueue(0));

        bool goReady = eleFree > 0 && maxBorrow >= borrowUsdc && morphoInv >= borrowUsdc
            && IMetaP1(YELE).supplyQueue(0) == ELE_USDC && hfWad >= 1.55e18;

        console2.log("GO_READY", goReady ? uint256(1) : uint256(0));
        if (!goReady) {
            console2.log("GO_BLOCK", maxBorrow < borrowUsdc ? "COLL_LTV" : "OTHER");
            console2.log("NEED_ELE_MIN", (borrowUsdc * 1e8 * 10_000) / (MAX_LTV_BPS * 1e6));
        }

        if (!doFire) {
            console2.log("PREFLIGHT_ONLY set FIRE_GROK_P1=1 to fire");
            return;
        }
        require(goReady, "GO_NOT_READY");

        vm.startBroadcast(pk);

        // Activate fees: recipient KingVault; submit 10% (timelock accept later)
        if (IMetaP1(YELE).owner() == HOT) {
            if (IMetaP1(YELE).feeRecipient() != spend) {
                IMetaP1(YELE).setFeeRecipient(spend);
            }
            if (IMetaP1(YELE).fee() == 0) {
                IMetaP1(YELE).submitFee(0.1e18);
            }
        }

        CrownElepanGrokPhase1 seeder = new CrownElepanGrokPhase1(
            MORPHO, USDC, ELEPAN, YELE, HOT, spend, earnTo, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        console2.log("seeder", address(seeder));

        if (!IMorphoP1(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoP1(MORPHO).setAuthorization(address(seeder), true);
        }
        if (IERC20P1(ELEPAN).allowance(HOT, address(seeder)) < eleFree) {
            IERC20P1(ELEPAN).approve(address(seeder), type(uint256).max);
        }

        seeder.phase1(eleFree, borrowUsdc);

        vm.stopBroadcast();

        (, uint128 bor, uint128 collAfter) = IMorphoP1(MORPHO).position(ELE_USDC, HOT);
        (uint128 sup,, uint128 mBor,,,) = IMorphoP1(MORPHO).market(ELE_USDC);
        console2.log("posColl", uint256(collAfter));
        console2.log("posBorrowShares", uint256(bor));
        console2.log("marketSupply", uint256(sup));
        console2.log("marketBorrow", uint256(mBor));
        console2.log("yeleAssetsAfter", IMetaP1(YELE).totalAssets());
        console2.log("earnShares", IMetaP1(YELE).balanceOf(earnTo));
        console2.log("kingVaultUsdc", IERC20P1(USDC).balanceOf(spend));
        console2.log("GROK_P1_OK", uint256(1));
    }
}
