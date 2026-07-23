// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOldCdp {
    function close() external;
    function accrue() external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
}

interface IZkGateM {
    function isProven(address) external view returns (bool);
}

/// @notice Deploy Access-Clause Elepan CDP with selfLiquidate; migrate healthy $13M position from OLD_CDP.
/// @dev KING_GO=1 FIRE_SELF_LIQ_MIGRATE=1 OLD_CDP=0xcdA6…
///      Flow: close old (burn eUSD from Landing) → deposit full coll on new → mintTo(Landing, 13M).
contract FireElepanSelfLiqMigrate is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;

    uint256 constant LR = 1.5e18;
    uint256 constant FLOOR = 1.55e18;
    uint256 constant FEE_BPS = 500;
    uint256 constant MINT = 13_000_000 ether;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SELF_LIQ_MIGRATE", uint256(0)) == 1, "NEED FIRE_SELF_LIQ_MIGRATE=1");
        address oldCdp = vm.envAddress("OLD_CDP");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkGateM(ZK_GATE).isProven(HOT), "HOT_NOT_ZK_PROVEN");

        CrownElepanUsd eusd = CrownElepanUsd(EUSD);
        uint256 collAmt = IOldCdp(oldCdp).coll();
        require(collAmt > 0, "OLD_EMPTY");
        require(IOldCdp(oldCdp).healthFactor() >= FLOOR, "OLD_UNSAFE");

        uint256 landingBeforeClose = eusd.balanceOf(LANDING);
        require(landingBeforeClose > 0, "NO_COLD_EUSD");

        vm.startBroadcast(pk);

        // 1) Deploy self-liq Access-Clause vault (cold = Landing)
        CrownElepanCdpVault vault = new CrownElepanCdpVault(
            ELEPAN, EUSD, ORACLE, ZK_GATE, HOT, LANDING, LANDING, LR, FLOOR, FEE_BPS
        );
        require(vault.treasury() == LANDING, "TREASURY");
        eusd.setMinter(address(vault), true);

        // 2) Close old: accrue fee to Landing, burn full debt from Landing, return coll to hot
        IOldCdp(oldCdp).accrue();
        IOldCdp(oldCdp).close();
        require(IOldCdp(oldCdp).coll() == 0 && IOldCdp(oldCdp).accruedDebt() == 0, "OLD_NOT_CLOSED");

        // 3) Re-open on self-liq vault — same coll, $13M to cold
        uint256 eleBal = IERC20M(ELEPAN).balanceOf(HOT);
        require(eleBal >= collAmt, "ELE_AFTER_CLOSE");
        IERC20M(ELEPAN).approve(address(vault), collAmt);
        vault.deposit(collAmt);
        vault.mintTo(LANDING, MINT);

        vm.stopBroadcast();

        require(eusd.balanceOf(LANDING) >= MINT, "COLD_MISS");
        require(eusd.balanceOf(HOT) == 0, "HOT_EUSD");
        require(eusd.balanceOf(address(vault)) == 0, "VAULT_HOLD");
        require(vault.healthFactor() >= FLOOR, "HF");
        require(vault.liquidatable() == false, "SHOULD_BE_HEALTHY");

        console2.log("NEW_CDP", address(vault));
        console2.log("OLD_CDP", oldCdp);
        console2.log("coll", vault.coll());
        console2.log("debt", vault.accruedDebt());
        console2.log("hf", vault.healthFactor());
        console2.log("landingEusd", eusd.balanceOf(LANDING));
        console2.log("SELF_LIQ_MIGRATE_OK", uint256(1));
    }
}
