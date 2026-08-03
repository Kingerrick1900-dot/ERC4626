// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssOpsSeed} from "../src/CrownRssOpsSeed.sol";

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
    function maxWithdraw(address) external view returns (uint256);
    function setSupplyQueue(bytes32[] calldata ids) external;
    function supplyQueue(uint256) external view returns (bytes32);
}

/// @notice Desk-free RSS ops seed ($600k–$700k) into yRSS war chest.
/// @dev Requires KING_OVERRIDE_NO_RECYCLE=1 (King mission override of NO-RECYCLE freeze).
///      FIRE=1 to execute opsSeed. Default = deploy + auth + approve only.
///      End state: yRSS assets ≈ ask (reinvest). Liquid USDC ≈ 0. Elepan untouched.
contract FireRssOpsSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    bytes32 constant CBBTC_M = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_M = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant BRETT_M = 0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16;

    function run() external {
        require(vm.envOr("KING_OVERRIDE_NO_RECYCLE", uint256(0)) == 1, "NEED_KING_OVERRIDE_NO_RECYCLE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", uint256(700_000e6));
        require(borrowUsdc >= 600_000e6 && borrowUsdc <= 700_000e6, "ASK_BAND");
        address existing = vm.envOr("SEEDER", address(0));

        uint256 rssBal = IERC20S(RSS).balanceOf(HOT);
        uint256 eleBal = IERC20S(ELEPAN).balanceOf(HOT);
        console2.log("=== RSS OPS SEED ===");
        console2.log("rssBal", rssBal);
        console2.log("elepan (untouched)", eleBal);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("landingUsdc", IERC20S(USDC).balanceOf(LANDING));
        console2.log("yRSS_TVL_before", IMetaMorphoS(YRSS).totalAssets());
        console2.log("yRSS_maxWithdraw", IMetaMorphoS(YRSS).maxWithdraw(HOT));
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        // Soft LTV preview @70%
        uint256 maxBorrow = (rssBal * 70) / 100 / 1e12;
        console2.log("maxBorrow70", maxBorrow);
        require(maxBorrow >= borrowUsdc, "RSS_LTV_SHORT");

        vm.startBroadcast(pk);

        bytes32[] memory q = new bytes32[](4);
        q[0] = RSS_M;
        q[1] = CBBTC_M;
        q[2] = WETH_M;
        q[3] = BRETT_M;
        if (IMetaMorphoS(YRSS).supplyQueue(0) != RSS_M) {
            IMetaMorphoS(YRSS).setSupplyQueue(q);
        }

        CrownRssOpsSeed seeder;
        if (existing == address(0)) {
            seeder = new CrownRssOpsSeed(MORPHO, USDC, RSS, YRSS, HOT, RSS_M, ORACLE, IRM, LLTV, HOT);
            console2.log("seeder", address(seeder));
        } else {
            seeder = CrownRssOpsSeed(existing);
            console2.log("seederExisting", existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(seeder))) {
            IMorphoAuth(MORPHO).setAuthorization(address(seeder), true);
        }
        if (IERC20S(RSS).allowance(HOT, address(seeder)) < rssBal) {
            IERC20S(RSS).approve(address(seeder), type(uint256).max);
        }

        if (doFire) {
            seeder.opsSeed(rssBal, borrowUsdc);
        }

        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(RSS_M, HOT);
        (uint128 sup,, uint128 mBor,,,) = IMorphoAuth(MORPHO).market(RSS_M);
        uint256 sh = IMetaMorphoS(YRSS).balanceOf(HOT);
        console2.log("collRss", uint256(coll));
        console2.log("debtShares", uint256(bor));
        console2.log("marketSupply", uint256(sup));
        console2.log("marketBorrow", uint256(mBor));
        console2.log("yRSS_TVL", IMetaMorphoS(YRSS).totalAssets());
        console2.log("hotYrssAssets", IMetaMorphoS(YRSS).convertToAssets(sh));
        console2.log("hotUsdc", IERC20S(USDC).balanceOf(HOT));
        console2.log("landingUsdc", IERC20S(USDC).balanceOf(LANDING));
        console2.log("elepanAfter", IERC20S(ELEPAN).balanceOf(HOT));
        console2.log("NOTE liquid USDC stays ~0; seed form = yRSS war chest");
    }
}
