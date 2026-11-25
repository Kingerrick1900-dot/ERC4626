// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCuratorTranche} from "../src/CrownCuratorTranche.sol";
import {CrownPendleSleeve} from "../src/CrownPendleSleeve.sol";

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IAllowlist {
    function setAllowed(address target, bytes4 selector, bool ok) external;
    function owner() external view returns (address);
}

/// @notice Deploy 200M-capped curator tranche + Pendle sleeve. Deposits only if real USDC present.
/// @dev Idle eUSD on Landing is NOT the deposit asset. Process: fill→USDC→deploy; LLC after payroll.
contract FireCuratorTranche is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ALLOWLIST = 0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 ask = vm.envOr("TRANCHE_USDC", uint256(0)); // 0 = deploy chassis only
        require(ask <= 200_000_000e6, "GT_CAP");

        uint256 usdcHot = IERC20b(USDC).balanceOf(HOT);
        uint256 usdcLanding = IERC20b(USDC).balanceOf(LANDING);
        uint256 eusdLanding = IERC20b(EUSD).balanceOf(LANDING);
        console2.log("usdcHot", usdcHot);
        console2.log("usdcLanding", usdcLanding);
        console2.log("eusdLanding", eusdLanding);
        console2.log("ask", ask);

        // Harvest sink: Landing (Base ops) — Scroll harvest path documented; bridge is separate fire.
        address sink = vm.envOr("HARVEST_SINK", LANDING);

        vm.startBroadcast(pk);

        CrownCuratorTranche tranche = new CrownCuratorTranche(USDC, HOT, sink, HOT);
        CrownPendleSleeve sleeve = new CrownPendleSleeve(USDC, address(tranche), HOT);
        tranche.setCurators(GAUNTLET, STEAK, address(sleeve));
        tranche.setWeights(4500, 4500, 1000);
        tranche.setAttest(ATTEST);
        tranche.setRequireBorders(true);
        tranche.setArmed(true);

        // KAR: allow deploy + harvest selectors
        if (IAllowlist(ALLOWLIST).owner() == HOT) {
            IAllowlist(ALLOWLIST).setAllowed(address(tranche), CrownCuratorTranche.deploy.selector, true);
            IAllowlist(ALLOWLIST).setAllowed(address(tranche), CrownCuratorTranche.harvestGauntlet.selector, true);
            IAllowlist(ALLOWLIST).setAllowed(address(tranche), CrownCuratorTranche.harvestSteak.selector, true);
            IAllowlist(ALLOWLIST).setAllowed(address(tranche), CrownCuratorTranche.sweepUsdc.selector, true);
        }

        if (ask > 0) {
            require(usdcHot >= ask, "NO_USDC"); // will not pull eUSD; will not touch gold
            IERC20b(USDC).approve(address(tranche), ask);
            tranche.deploy(ask);
        }

        vm.stopBroadcast();

        console2.log("CrownCuratorTranche", address(tranche));
        console2.log("CrownPendleSleeve", address(sleeve));
        console2.log("totalDeployed", tranche.totalDeployed());
        console2.log("remainingCap", tranche.remainingCap());
        console2.log("deployedValue", tranche.deployedValue());
        console2.log("scrollHotNote", SCROLL_HOT);
        console2.log("coldEusdUnchanged", eusdLanding);
    }
}
