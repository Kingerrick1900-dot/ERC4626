// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
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

interface IERC20G {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownGateV2 on sovereign RSS/USDC market and adopt King's Morpho collateral onto the gate.
/// Gate: FIRE_CROWN_GATE_V2=1 · HOT_KEY → 0x6708…a7d1
/// Optional: BORROW_USDC=<assets> · GATE_ONLY=1 (deploy only, skip adopt)
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

    function run() external {
        require(vm.envOr("FIRE_CROWN_GATE_V2", uint256(0)) == 1, "FIRE_CROWN_GATE_V2");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address orc, address irm_, uint256 lltv_) =
            IMorphoGateFire(MORPHO).idToMarketParams(SOV);
        require(loan == USDC && coll == RSS, "BAD_SOV_TOKENS");
        require(orc == SOV_ORACLE, "BAD_SOV_ORACLE");
        require(irm_ == IRM && lltv_ == LLTV, "BAD_SOV_PARAMS");

        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        require(keccak256(abi.encode(mp)) == SOV, "SOV_ID_MISMATCH");

        vm.startBroadcast(pk);

        CrownGateV2 gate = new CrownGateV2(HOT, mp);
        console2.log("CrownGateV2", address(gate));
        console2.logBytes32(gate.MARKET_ID());

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
                gate.supplyCollateral(uint256(kingColl));
                console2.log("adoptedRss", uint256(kingColl));
            }

            uint256 borrowAmt = vm.envOr("BORROW_USDC", uint256(0));
            if (borrowAmt > 0) {
                (uint128 cash,,,,,) = IMorphoGateFire(MORPHO).market(SOV);
                console2.log("marketCash", uint256(cash));
                require(borrowAmt <= uint256(cash), "NO_CASH");
                gate.borrowUSDC(borrowAmt, HOT);
                console2.log("borrowedUsdc", borrowAmt);
            }
        }

        vm.stopBroadcast();

        (, uint128 gBor, uint128 gColl) = IMorphoGateFire(MORPHO).position(SOV, address(gate));
        console2.log("gateColl", uint256(gColl));
        console2.log("gateBorShares", uint256(gBor));
        console2.log("hotUsdc", IERC20G(USDC).balanceOf(HOT));
    }
}
