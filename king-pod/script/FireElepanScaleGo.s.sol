// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanSelfSeedV2} from "../src/CrownElepanSelfSeedV2.sol";

interface IMorphoG {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function supplyCollateral(MarketParams calldata, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams calldata, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20G {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IMetaG {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function submitCap(bytes32 id, uint256 newSupplyCap) external;
    function acceptCap(bytes32 id) external;
    function timelock() external view returns (uint256);
}

/// @notice GO pack: move war-chest shares → Landing, top coll, fill vault cap via flash, borrow idle → Landing.
/// @dev KING_GO=1 FIRE_SCALE=1
contract FireElepanScaleGo is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
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
        require(vm.envOr("FIRE_SCALE", uint256(0)) == 1, "NEED FIRE_SCALE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        // Fill remaining ~$5M room under $14M cap (leave $2 dust buffer)
        uint256 fillUsdc = vm.envOr("FILL_USDC", uint256(4_999_000e6));
        uint256 extraColl = vm.envOr("EXTRA_COLL", uint256(20_000_000e8));
        // coll for fill at 70% LTV
        uint256 seedColl = vm.envOr("SEED_COLL", uint256(0));
        if (seedColl == 0) {
            // borrow/0.7 in Elepan 8dp: fillUsdc/1e6 / 0.7 * 1e8 = fillUsdc * 1e8 / (0.7*1e6)
            seedColl = (fillUsdc * 1e8 * 10_000) / (7000 * 1e6) + 1e8; // +1 Elepan dust
        }

        IMorphoG.MarketParams memory mp = IMorphoG.MarketParams({
            loanToken: USDC,
            collateralToken: ELEPAN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        uint256 landUsdcBefore = IERC20G(USDC).balanceOf(LANDING);
        uint256 sharesHot = IMetaG(YELE).balanceOf(HOT);

        console2.log("REPAY_SOURCE", "Morpho.borrow(ELE_USDC)");
        console2.log("fillUsdc", fillUsdc);
        console2.log("seedColl", seedColl);
        console2.log("extraColl", extraColl);
        console2.log("sharesHot", sharesHot);

        vm.startBroadcast(pk);

        // 1) War chest → Landing (cold)
        if (sharesHot > 0) {
            require(IMetaG(YELE).transfer(LANDING, sharesHot), "SHARE_XFER");
        }

        // 2) Extra Morpho coll headroom
        uint256 eleBal = IERC20G(ELEPAN).balanceOf(HOT);
        require(eleBal >= seedColl + extraColl, "ELEPAN");
        IERC20G(ELEPAN).approve(MORPHO, extraColl);
        IMorphoG(MORPHO).supplyCollateral(mp, extraColl, HOT, "");

        // 3) Flash-fill remaining vault cap; shares → Landing
        CrownElepanSelfSeedV2 seeder = new CrownElepanSelfSeedV2(
            MORPHO, USDC, ELEPAN, YELE, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        if (!IMorphoG(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoG(MORPHO).setAuthorization(address(seeder), true);
        }
        IERC20G(ELEPAN).approve(address(seeder), seedColl);
        seeder.selfSeed(seedColl, fillUsdc);

        // 4) Borrow all market idle → Landing (pipe; may be dust if still matched)
        (uint128 supply,, uint128 borrow,,,) = IMorphoG(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        if (idle > 0) {
            IMorphoG(MORPHO).borrow(mp, idle, 0, HOT, LANDING);
        }

        vm.stopBroadcast();

        console2.log("seederV2", address(seeder));
        console2.log("yeleAssets", IMetaG(YELE).totalAssets());
        console2.log("sharesLanding", IMetaG(YELE).balanceOf(LANDING));
        console2.log("sharesHotAfter", IMetaG(YELE).balanceOf(HOT));
        console2.log("idleLeft", idle);
        console2.log("landingUsdcBefore", landUsdcBefore);
        console2.log("landingUsdcAfter", IERC20G(USDC).balanceOf(LANDING));
        (, uint128 bor, uint128 coll) = IMorphoG(MORPHO).position(ELE_USDC, HOT);
        console2.log("posColl", uint256(coll));
        console2.log("posBorrowShares", uint256(bor));
        console2.log("SCALE_GO_OK", uint256(1));
    }
}
