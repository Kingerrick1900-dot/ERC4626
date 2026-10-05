// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {CrownZkAutoDraw} from "../src/zk/CrownZkAutoDraw.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoGateFire {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IZkGateFire {
    function isProven(address subject) external view returns (bool);
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

interface IZkCreditFire {
    function setOperator(address op, bool allowed) external;
    function king() external view returns (address);
}

interface IERC20G {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice ZK-mandatory fire: deploy CrownGateV2 + CrownZkAutoDraw, adopt Path B RSS, optional shielded borrow.
/// @dev NOTHING FIRES WITHOUT ZK.
///      Required: FIRE_CROWN_GATE_V2=1 · ZK_SHIELD=1 · HOT_KEY
///      Live Base WalletGate must report isProven(HOT)=true (refresh via FireZkAttestRefreshCast / submitProof).
///      Optional: BORROW_USDC · CREDIT_BORROW · LANDING · GATE_ONLY=1 (deploy+wire only; still requires ZK)
contract FireCrownGateV2 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant SOV =
        0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    /// @dev Base ZK Borrow Port WalletGate (see FIRE-ZK-BORROW-PORT.md)
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant ZK_CREDIT = 0x75279D46F0dA7f91D5283687C1D0a6EF86992e09;
    address constant LEGACY_ZK_GATE = 0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579;

    function run() external {
        require(vm.envOr("FIRE_CROWN_GATE_V2", uint256(0)) == 1, "FIRE_CROWN_GATE_V2");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        // Explicit ban on transparent bypass flags
        require(vm.envOr("TRANSPARENT_OK", uint256(0)) == 0, "TRANSPARENT_FORBIDDEN");
        require(vm.envOr("NO_ZK", uint256(0)) == 0, "NO_ZK_FORBIDDEN");

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address zkGate = vm.envOr("ZK_WALLET_GATE", ZK_WALLET_GATE);
        address creditAddr = vm.envOr("ZK_CREDIT", ZK_CREDIT);
        address landing = vm.envOr("LANDING", HOT);

        require(IZkGateFire(zkGate).isProven(HOT), "NOT_PROVEN_PORT");
        // Prefer port gate; legacy may also be proven — log both
        bool legacyProven = IZkGateFire(LEGACY_ZK_GATE).isProven(HOT);
        (uint256 thr, uint256 at, bool valid) = IZkGateFire(zkGate).attestations(HOT);
        console2.log("zkGate", zkGate);
        console2.log("isProven", true);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
        console2.log("legacyProven", legacyProven);

        (address loan, address coll, address orc, address irm_, uint256 lltv_) =
            IMorphoGateFire(MORPHO).idToMarketParams(SOV);
        require(loan == USDC && coll == RSS, "BAD_SOV_TOKENS");
        require(orc == SOV_ORACLE, "BAD_SOV_ORACLE");
        require(irm_ == IRM && lltv_ == LLTV, "BAD_SOV_PARAMS");

        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        require(keccak256(abi.encode(mp)) == SOV, "SOV_ID_MISMATCH");

        vm.startBroadcast(pk);

        CrownGateV2 gate = new CrownGateV2(HOT, zkGate, mp);
        console2.log("CrownGateV2", address(gate));
        console2.logBytes32(gate.MARKET_ID());

        CrownZkAutoDraw autoDraw = new CrownZkAutoDraw(zkGate, address(gate), creditAddr, HOT, landing, HOT);
        console2.log("CrownZkAutoDraw", address(autoDraw));

        gate.setOperator(address(autoDraw), true);
        // Credit operator — only succeeds if HOT still owns Credit (port king=HOT)
        if (IZkCreditFire(creditAddr).king() == HOT) {
            try IZkCreditFire(creditAddr).setOperator(address(autoDraw), true) {
                console2.log("creditOperator", address(autoDraw));
            } catch {
                console2.log("creditOperator_SKIP");
            }
        }

        if (vm.envOr("GATE_ONLY", uint256(0)) == 0) {
            (, uint128 bor, uint128 kingColl) = IMorphoGateFire(MORPHO).position(SOV, HOT);
            console2.log("kingColl", uint256(kingColl));
            console2.log("kingBorShares", uint256(bor));
            require(bor == 0, "KING_HAS_DEBT");

            if (kingColl > 0) {
                IMorphoGateFire.MarketParams memory mpf =
                    IMorphoGateFire.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
                IMorphoGateFire(MORPHO).withdrawCollateral(mpf, uint256(kingColl), HOT, HOT);
                IERC20G(RSS).approve(address(gate), uint256(kingColl));
                gate.supplyCollateral(uint256(kingColl)); // ZK-gated
                console2.log("adoptedRss", uint256(kingColl));
            }

            uint256 borrowAmt = vm.envOr("BORROW_USDC", uint256(0));
            uint256 creditBorrow = vm.envOr("CREDIT_BORROW", uint256(0));
            if (borrowAmt > 0 || creditBorrow > 0) {
                if (borrowAmt > 0) {
                    (uint128 cash,,,,,) = IMorphoGateFire(MORPHO).market(SOV);
                    console2.log("marketCash", uint256(cash));
                    require(borrowAmt <= uint256(cash), "NO_CASH");
                }
                autoDraw.autoDraw(borrowAmt, landing, creditBorrow);
                console2.log("shieldedMorphoBorrow", borrowAmt);
                console2.log("shieldedCreditBorrow", creditBorrow);
            }
        }

        vm.stopBroadcast();

        (, uint128 gBor, uint128 gColl) = IMorphoGateFire(MORPHO).position(SOV, address(gate));
        console2.log("gateColl", uint256(gColl));
        console2.log("gateBorShares", uint256(gBor));
        console2.log("hotUsdc", IERC20G(USDC).balanceOf(HOT));
        console2.log("ZK_SHIELD", uint256(1));
    }
}
