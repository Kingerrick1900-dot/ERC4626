// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanPreSelfLiq} from "../src/CrownElepanPreSelfLiq.sol";
import {CrownMorphoZkPack} from "../src/CrownMorphoZkPack.sol";

interface IERC20H {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoH {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IZkGateH {
    function isProven(address) external view returns (bool);
    function attestations(address) external view returns (uint256, uint256, uint256);
    function minThreshold() external view returns (uint256);
}

interface IKeepDrawH {
    function setOperator(address) external;
}

interface ICdpH {
    function maxWithdrawable() external view returns (uint256);
    function withdraw(uint256 amount) external;
}

/// @notice Top up Morpho ELE coll (HF comfort) + deploy/arm ZK pre-self-liq.
/// @dev KING_GO=1 FIRE_HF_SELF_LIQ=1
///      LANDING_KEY (optional): move Landing Elepan → Hot → Morpho.
///      TARGET_HF_BPS=20000 (2.00x). POST_ALL_LANDING_ELE=1 posts all free Landing ELE.
contract FireHfAndSelfLiq is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant KEEP_DRAW = 0x0C1c7E4eDc3a7E9f4ae0C23419501D8d63226691;
    address constant CDP = 0x46b1D159b3a2694e7b70F550b7d5dEf6df451174;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_HF_SELF_LIQ", uint256(0)) == 1, "NEED FIRE_HF_SELF_LIQ=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateH(GATE).isProven(HOT), "NOT_PROVEN");
        (uint256 attest,,) = IZkGateH(GATE).attestations(HOT);
        require(attest >= IZkGateH(GATE).minThreshold(), "BELOW_THRESHOLD");

        IMorphoH.MarketParams memory mp = IMorphoH.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IMorphoH(MORPHO).accrueInterest(mp);
        (, uint128 borShares, uint128 coll0) = IMorphoH(MORPHO).position(ELE_USDC, HOT);
        (,, uint128 ba, uint128 bs,,) = IMorphoH(MORPHO).market(ELE_USDC);
        uint256 debt = borShares == 0 || bs == 0
            ? 0
            : (uint256(ba) * uint256(borShares) + uint256(bs) - 1) / uint256(bs);

        uint256 targetHfBps = vm.envOr("TARGET_HF_BPS", uint256(20_000)); // 2.00x coll/debt @ $1
        // coll_8dp = debt_6dp * hfBps / 100
        uint256 needColl = (debt * targetHfBps) / 100;
        uint256 haveColl = uint256(coll0);
        uint256 shortfall = needColl > haveColl ? needColl - haveColl : 0;

        console2.log("debtUsdc6", debt);
        console2.log("collEle8", haveColl);
        console2.log("needCollForTarget", needColl);
        console2.log("shortfallEle8", shortfall);
        console2.log("hfBpsNow", debt == 0 ? 0 : (haveColl * 100) / debt);

        uint256 landPk = vm.envOr("LANDING_KEY", uint256(0));
        bool postAll = vm.envOr("POST_ALL_LANDING_ELE", uint256(1)) == 1; // default: post all free Landing ELE

        // --- A) Landing → Hot (separate signer) ---
        if (landPk != 0) {
            require(vm.addr(landPk) == LANDING, "LANDING_KEY_ADDR");
            uint256 landEle = IERC20H(ELE).balanceOf(LANDING);
            uint256 move = postAll ? landEle : shortfall;
            if (move > landEle) move = landEle;
            if (move > 0) {
                vm.startBroadcast(landPk);
                IERC20H(ELE).transfer(HOT, move);
                vm.stopBroadcast();
                console2.log("movedFromLanding", move);
            }
        } else {
            console2.log("NO_LANDING_KEY", uint256(1));
        }

        // --- B) Hot: post free ELE (from Landing move) + arm self-liq ---
        // Note: do not CDP-pull here — live CDP withdraw is flaky vs forge sim and breaks broadcast.
        uint256 freeEle = IERC20H(ELE).balanceOf(HOT);
        console2.log("hotEleBeforePost", freeEle);

        vm.startBroadcast(pk);

        if (freeEle > 0) {
            IERC20H(ELE).approve(MORPHO, freeEle);
            IMorphoH(MORPHO).supplyCollateral(mp, freeEle, HOT, "");
            console2.log("postedEle", freeEle);
        } else {
            console2.log("postedEle", uint256(0));
        }

        CrownElepanPreSelfLiq selfLiq = new CrownElepanPreSelfLiq(
            GATE, MORPHO, USDC, ELE, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        if (!IMorphoH(MORPHO).isAuthorized(HOT, address(selfLiq))) {
            IMorphoH(MORPHO).setAuthorization(address(selfLiq), true);
        }

        CrownMorphoZkPack book = new CrownMorphoZkPack(
            GATE, CREDIT, MORPHO, USDC, ELE, HOT, LANDING, ELE_USDC, ORACLE, LLTV, HOT
        );
        selfLiq.setOperator(address(book));
        // KeepDraw operator wiring skipped — live KeepDraw rejects setOperator from this path.
        book.wire(KEEP_DRAW, address(selfLiq));
        console2.log("keepDrawWired", KEEP_DRAW);

        vm.stopBroadcast();

        (, uint128 bor1, uint128 coll1) = IMorphoH(MORPHO).position(ELE_USDC, HOT);
        (,, uint128 ba1, uint128 bs1,,) = IMorphoH(MORPHO).market(ELE_USDC);
        uint256 debt1 = bor1 == 0 || bs1 == 0
            ? 0
            : (uint256(ba1) * uint256(bor1) + uint256(bs1) - 1) / uint256(bs1);
        console2.log("preSelfLiq", address(selfLiq));
        console2.log("zkPack", address(book));
        console2.log("collAfter", uint256(coll1));
        console2.log("debtAfter", debt1);
        console2.log("hfBpsAfter", debt1 == 0 ? 0 : (uint256(coll1) * 100) / debt1);
        console2.log(
            "SELF_LIQ_ARMED", IMorphoH(MORPHO).isAuthorized(HOT, address(selfLiq)) ? uint256(1) : uint256(0)
        );
    }
}
