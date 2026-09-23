// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnlatchIdle} from "../src/CrownUnlatchIdle.sol";

interface IMorphoU {
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20U {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IPsmSweep {
    function sweep(address token, address to, uint256 amt) external;
    function usdcReserve() external view returns (uint256);
}

/// @notice Deploy CrownUnlatchIdle + optional PSM USDC sweep into engineerIdle.
/// @dev KING_GO=1 forge script script/FireUnlatchIdle.s.sol:FireUnlatchDeploy --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireUnlatchDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    bytes32 constant MARKET_YRSS_PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoU(MORPHO).idToMarketParams(MARKET_YRSS_PARK);
        require(loan == USDC && coll == RSS, "MARKET");

        bool doSweep = vm.envOr("SWEEP_PSM", uint256(1)) == 1;
        bool doEngineer = vm.envOr("ENGINEER", uint256(1)) == 1;

        vm.startBroadcast(pk);

        if (doSweep) {
            uint256 res = IPsmSweep(PSM).usdcReserve();
            if (res > 0) {
                IPsmSweep(PSM).sweep(USDC, HOT, res);
                console2.log("swept_psm_usdc", res);
            }
        }

        CrownUnlatchIdle eng = new CrownUnlatchIdle(MORPHO, USDC, YRSS, HOT, LANDING, HOT);
        eng.setMarketRss(RSS, oracle, irm, lltv, MARKET_YRSS_PARK);
        eng.setArmed(true);

        uint256 bal = IERC20U(USDC).balanceOf(HOT);
        console2.log("hot_usdc_before_engineer", bal);

        if (doEngineer && bal > 0) {
            IERC20U(USDC).approve(address(eng), bal);
            uint256 supplied = eng.engineerIdle(bal);
            console2.log("engineered", supplied);
        }

        vm.stopBroadcast();

        console2.log("CrownUnlatchIdle", address(eng));
        console2.log("idle", eng.idle());
        console2.log("utilBps", eng.utilBps());
        console2.log("minIdleBuffer", eng.minIdleBuffer());
        console2.log("surplusIdle", eng.surplusIdle());
        console2.log("maxPeel", eng.maxPeel());
        console2.log("kingDebt", eng.kingBorrowAssets());
    }
}

/// @notice Fund + engineerIdle larger size once USDC is on HOT.
/// @dev KING_GO=1 FIRE=1 UNLATCH=0x… AMT=… forge script …:FireUnlatchEngineer --broadcast --slow
contract FireUnlatchEngineer is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE", uint256(0)) == 1, "NO_FIRE");
        address engAddr = vm.envAddress("UNLATCH");
        uint256 amt = vm.envOr("AMT", uint256(0));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownUnlatchIdle eng = CrownUnlatchIdle(engAddr);
        if (amt == 0) amt = IERC20U(USDC).balanceOf(HOT);

        vm.startBroadcast(pk);
        IERC20U(USDC).approve(engAddr, amt);
        uint256 supplied = eng.engineerIdle(amt);
        vm.stopBroadcast();

        console2.log("supplied", supplied);
        console2.log("idle", eng.idle());
        console2.log("minIdleBuffer", eng.minIdleBuffer());
    }
}
