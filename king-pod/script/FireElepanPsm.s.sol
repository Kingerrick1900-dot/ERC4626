// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanPsm} from "../src/CrownElepanPsm.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Deploy / seed Kingdom PSM. KING_GO=1 FIRE_PSM=1
/// @dev Go-live = deploy only. Seed ONLY explicit amounts (never full balance).
///      PSM=0x… · SEED_EUSD_AMT · SEED_USDC_AMT · FEE_BPS · BUY_USDC · MIN_ETH_WEI
contract FireElepanPsm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    /// @dev Keep ~0.0003 ETH on hot for later fires (Base is cheap; do not drain).
    uint256 constant DEFAULT_MIN_ETH = 3e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_PSM", uint256(0)) == 1, "NEED FIRE_PSM=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(0)));
        uint256 seedEusdAmt = vm.envOr("SEED_EUSD_AMT", uint256(0));
        uint256 seedUsdcAmt = vm.envOr("SEED_USDC_AMT", uint256(0));
        uint256 buyUsdcAmt = vm.envOr("BUY_USDC", uint256(0));
        uint256 minEth = vm.envOr("MIN_ETH_WEI", DEFAULT_MIN_ETH);

        // Reject legacy full-drain flags.
        require(vm.envOr("SEED_EUSD", uint256(0)) == 0, "USE SEED_EUSD_AMT");
        require(vm.envOr("SEED_USDC", uint256(0)) == 0, "USE SEED_USDC_AMT");

        uint256 ethBal = HOT.balance;
        console2.log("hotEth", ethBal);
        console2.log("minEth", minEth);
        require(ethBal >= minEth, "GAS_FLOOR");

        vm.startBroadcast(pk);
        address existing = vm.envOr("PSM", address(0));
        CrownElepanPsm psm = existing == address(0)
            ? new CrownElepanPsm(HOT, LAND, EUSD, USDC, feeBps)
            : CrownElepanPsm(existing);
        console2.log("psm", address(psm));

        if (seedEusdAmt > 0) {
            uint256 bal = IERC20F(EUSD).balanceOf(HOT);
            require(bal >= seedEusdAmt, "EUSD_BAL");
            // Never dump the entire eUSD bag in one seed.
            require(seedEusdAmt < bal, "KEEP_EUSD_FLOAT");
            console2.log("seedEusdAmt", seedEusdAmt);
            IERC20F(EUSD).approve(address(psm), seedEusdAmt);
            psm.seedEusd(seedEusdAmt);
        }
        if (seedUsdcAmt > 0) {
            uint256 bal = IERC20F(USDC).balanceOf(HOT);
            require(bal >= seedUsdcAmt, "USDC_BAL");
            console2.log("seedUsdcAmt", seedUsdcAmt);
            IERC20F(USDC).approve(address(psm), seedUsdcAmt);
            psm.seedUsdc(seedUsdcAmt);
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
        console2.log("hotEthAfter", HOT.balance);
        console2.log("landUsdc", IERC20F(USDC).balanceOf(LAND));
        console2.log("PSM_OK", uint256(1));
    }
}
