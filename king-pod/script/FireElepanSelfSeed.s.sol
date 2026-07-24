// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanSelfSeed} from "../src/CrownElepanSelfSeed.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20S {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IMetaMorphoS {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function supplyQueue(uint256) external view returns (bytes32);
}

/// @notice Bootstrap yELEPAN-USDC with Morpho flash USDC (protocol inventory ~$200M).
/// @dev KING_GO=1 FIRE_ELEPAN_SEED=1 to fire. Prep-only: omit FIRE_ELEPAN_SEED.
///      REPAY_SOURCE=Morpho.borrow(ELE_USDC onBehalf hot) after yELEPAN.deposit.
contract FireElepanSelfSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        bool doFire = vm.envOr("FIRE_ELEPAN_SEED", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", uint256(9_000_000e6));
        if (borrowUsdc < 1_000_000e6) borrowUsdc = 9_000_000e6;
        uint256 elepanColl = vm.envOr("ELEPAN_COLL", uint256(0)); // 0 = full hot free
        address existing = vm.envOr("SEEDER", address(0));

        uint256 eleBal = IERC20S(ELEPAN).balanceOf(HOT);
        if (elepanColl == 0) elepanColl = eleBal;
        require(elepanColl <= eleBal, "ELEPAN_BAL");
        // 70% LTV soft $1, Elepan 8dp
        require(borrowUsdc * 1e8 <= (elepanColl * 7000 * 1e6) / 10_000, "LTV");

        uint256 morphoUsdc = IERC20S(USDC).balanceOf(MORPHO);
        require(morphoUsdc >= borrowUsdc, "MORPHO_FLASH_LIQ");

        console2.log("REPAY_SOURCE", "Morpho.borrow(ELE_USDC)");
        console2.log("elepanColl", elepanColl);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("morphoUsdcInventory", morphoUsdc);
        console2.log("yeleAssetsBefore", IMetaMorphoS(YELE).totalAssets());
        console2.log("queue0");
        console2.logBytes32(IMetaMorphoS(YELE).supplyQueue(0));
        require(IMetaMorphoS(YELE).supplyQueue(0) == ELE_USDC, "QUEUE");

        vm.startBroadcast(pk);

        CrownElepanSelfSeed seeder;
        if (existing == address(0)) {
            seeder = new CrownElepanSelfSeed(
                MORPHO, USDC, ELEPAN, YELE, HOT, ELE_USDC, ORACLE, IRM, LLTV, HOT
            );
            console2.log("seeder", address(seeder));
        } else {
            seeder = CrownElepanSelfSeed(existing);
            console2.log("seederExisting", existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoAuth(MORPHO).setAuthorization(address(seeder), true);
        }
        if (IERC20S(ELEPAN).allowance(HOT, address(seeder)) < elepanColl) {
            IERC20S(ELEPAN).approve(address(seeder), type(uint256).max);
        }

        if (doFire) {
            seeder.selfSeed(elepanColl, borrowUsdc);
        }

        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(ELE_USDC, HOT);
        (uint128 sup,, uint128 mBor,,,) = IMorphoAuth(MORPHO).market(ELE_USDC);
        uint256 shares = IMetaMorphoS(YELE).balanceOf(HOT);
        console2.log("posColl", uint256(coll));
        console2.log("posBorrowShares", uint256(bor));
        console2.log("marketSupply", uint256(sup));
        console2.log("marketBorrow", uint256(mBor));
        console2.log("yeleShares", shares);
        console2.log("yeleAssetsAfter", IMetaMorphoS(YELE).totalAssets());
        console2.log("hotUsdc", IERC20S(USDC).balanceOf(HOT));
        if (doFire) {
            require(uint256(coll) >= elepanColl, "COLL_MISS");
            require(IMetaMorphoS(YELE).totalAssets() >= borrowUsdc, "VAULT_MISS");
            console2.log("ELEPAN_SELF_SEED_OK", uint256(1));
        } else {
            console2.log("ELEPAN_SELF_SEED_PREP_OK", uint256(1));
        }
    }
}
