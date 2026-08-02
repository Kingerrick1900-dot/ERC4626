// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBaseUsdcPsm} from "../src/CrownBaseUsdcPsm.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IEusdOwner {
    function owner() external view returns (address);
    function setMinter(address m, bool allowed) external;
    function isMinter(address) external view returns (bool);
}

/// @notice Deploy / wire / seed Base Maker PSM. KING_GO=1 FIRE_BASE_USDC_PSM=1
/// @dev Deploy + setMinter by default. Seed ONLY SEED_USDC_AMT (explicit).
///      PSM=0x… skips deploy. SET_MINTER=0 skips minter wire. MIN_ETH_WEI gas floor.
contract FireBaseUsdcPsm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant DEFAULT_MIN_ETH = 3e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_BASE_USDC_PSM", uint256(0)) == 1, "NEED FIRE_BASE_USDC_PSM=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(0)));
        uint256 seedUsdcAmt = vm.envOr("SEED_USDC_AMT", uint256(0));
        uint256 minEth = vm.envOr("MIN_ETH_WEI", DEFAULT_MIN_ETH);
        bool doMinter = vm.envOr("SET_MINTER", uint256(1)) == 1;

        require(vm.envOr("SEED_USDC", uint256(0)) == 0, "USE SEED_USDC_AMT");

        uint256 ethBal = HOT.balance;
        console2.log("hotEth", ethBal);
        console2.log("minEth", minEth);
        require(ethBal >= minEth, "GAS_FLOOR");

        require(IEusdOwner(EUSD).owner() == HOT, "EUSD_OWNER");

        vm.startBroadcast(pk);
        address existing = vm.envOr("PSM", address(0));
        CrownBaseUsdcPsm psm = existing == address(0)
            ? new CrownBaseUsdcPsm(HOT, LAND, EUSD, USDC, feeBps)
            : CrownBaseUsdcPsm(existing);
        console2.log("psm", address(psm));

        if (doMinter && !IEusdOwner(EUSD).isMinter(address(psm))) {
            IEusdOwner(EUSD).setMinter(address(psm), true);
            console2.log("setMinter", uint256(1));
        }
        console2.log("isMinter", IEusdOwner(EUSD).isMinter(address(psm)) ? uint256(1) : uint256(0));

        if (seedUsdcAmt > 0) {
            uint256 bal = IERC20F(USDC).balanceOf(HOT);
            require(bal >= seedUsdcAmt, "USDC_BAL");
            console2.log("seedUsdcAmt", seedUsdcAmt);
            IERC20F(USDC).approve(address(psm), seedUsdcAmt);
            psm.seedUsdc(seedUsdcAmt);
        }
        vm.stopBroadcast();

        console2.log("reserveUsdc", psm.usdcReserve());
        console2.log("feeBps", uint256(psm.feeBps()));
        console2.log("paused", psm.paused() ? uint256(1) : uint256(0));
        console2.log("hotUsdc", IERC20F(USDC).balanceOf(HOT));
        console2.log("hotEthAfter", HOT.balance);
        console2.log("BASE_USDC_PSM_OK", uint256(1));
    }
}
