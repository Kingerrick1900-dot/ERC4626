// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanPsm} from "../src/CrownElepanPsm.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Deploy / seed Kingdom PSM. KING_GO=1 FIRE_PSM=1
/// @dev Optional: PSM=0x existing · SEED_EUSD=1 · SEED_USDC=1 · FEE_BPS=0 · BUY_USDC=<usdc6 out via eUSD>
contract FireElepanPsm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_PSM", uint256(0)) == 1, "NEED FIRE_PSM=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(0)));
        bool seedEusd = vm.envOr("SEED_EUSD", uint256(0)) == 1;
        bool seedUsdc = vm.envOr("SEED_USDC", uint256(0)) == 1;
        uint256 buyUsdcAmt = vm.envOr("BUY_USDC", uint256(0));

        vm.startBroadcast(pk);
        address existing = vm.envOr("PSM", address(0));
        CrownElepanPsm psm = existing == address(0)
            ? new CrownElepanPsm(HOT, LAND, EUSD, USDC, feeBps)
            : CrownElepanPsm(existing);
        console2.log("psm", address(psm));

        if (seedEusd) {
            uint256 bal = IERC20F(EUSD).balanceOf(HOT);
            console2.log("seedEusd", bal);
            if (bal > 0) {
                IERC20F(EUSD).approve(address(psm), bal);
                psm.seedEusd(bal);
            }
        }
        if (seedUsdc) {
            uint256 bal = IERC20F(USDC).balanceOf(HOT);
            console2.log("seedUsdc", bal);
            if (bal > 0) {
                IERC20F(USDC).approve(address(psm), bal);
                psm.seedUsdc(bal);
            }
        }

        if (buyUsdcAmt > 0) {
            uint256 eusdIn = buyUsdcAmt * 1e12;
            require(IERC20F(EUSD).balanceOf(HOT) >= eusdIn, "EUSD");
            (uint256 usdcBal,) = psm.reserves();
            require(usdcBal >= buyUsdcAmt, "NO_USDC_RESERVE");
            IERC20F(EUSD).approve(address(psm), eusdIn);
            uint256 out = psm.buyUsdc(eusdIn, LAND);
            console2.log("boughtUsdc", out);
        }
        vm.stopBroadcast();

        (uint256 u, uint256 e) = psm.reserves();
        console2.log("reserveUsdc", u);
        console2.log("reserveEusd", e);
        console2.log("landUsdc", IERC20F(USDC).balanceOf(LAND));
        console2.log("PSM_OK", uint256(1));
    }
}
