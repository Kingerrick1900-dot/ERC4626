// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanPsm} from "../src/CrownElepanPsm.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoPsm {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function accrueInterest(MarketParams memory) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Deploy / seed Kingdom PSM. KING_GO=1 FIRE_PSM=1
/// @dev Seed ONLY explicit amounts. Optional IDLE_TO_PSM_USDC borrows that size from Morpho → hot → PSM.
contract FireElepanPsm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant LIVE_PSM = 0x9199E5099C2C46A688F982E377a146Ab6db8060b;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;
    /// @dev Keep ETH on hot for later fires.
    uint256 constant DEFAULT_MIN_ETH = 3e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_PSM", uint256(0)) == 1, "NEED FIRE_PSM=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(0)));
        uint256 seedEusdAmt = vm.envOr("SEED_EUSD_AMT", uint256(0));
        uint256 seedUsdcAmt = vm.envOr("SEED_USDC_AMT", uint256(0));
        uint256 idleToPsm = vm.envOr("IDLE_TO_PSM_USDC", uint256(0));
        uint256 buyUsdcAmt = vm.envOr("BUY_USDC", uint256(0));
        uint256 minEth = vm.envOr("MIN_ETH_WEI", DEFAULT_MIN_ETH);

        require(vm.envOr("SEED_EUSD", uint256(0)) == 0, "USE SEED_EUSD_AMT");
        require(vm.envOr("SEED_USDC", uint256(0)) == 0, "USE SEED_USDC_AMT");

        uint256 ethBal = HOT.balance;
        console2.log("hotEth", ethBal);
        console2.log("minEth", minEth);
        require(ethBal >= minEth, "GAS_FLOOR");

        vm.startBroadcast(pk);
        address existing = vm.envOr("PSM", LIVE_PSM);
        CrownElepanPsm psm = existing.code.length == 0
            ? new CrownElepanPsm(HOT, LAND, EUSD, USDC, feeBps)
            : CrownElepanPsm(existing);
        console2.log("psm", address(psm));

        if (idleToPsm > 0) {
            IMorphoPsm.MarketParams memory mp =
                IMorphoPsm.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
            IMorphoPsm(MORPHO).accrueInterest(mp);
            (uint128 sa,, uint128 ba,,,) = IMorphoPsm(MORPHO).market(ELE_USDC);
            uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
            // Leave 1 wei idle on market; never take more than asked.
            require(idle > 1, "NO_IDLE");
            uint256 take = idleToPsm;
            if (take > idle - 1) take = idle - 1;
            require(take > 0, "IDLE0");
            console2.log("idleBorrow", take);
            IMorphoPsm(MORPHO).borrow(mp, take, 0, HOT, HOT);
            seedUsdcAmt += take; // sized seed of what we just drew
        }

        if (seedEusdAmt > 0) {
            uint256 bal = IERC20F(EUSD).balanceOf(HOT);
            require(bal >= seedEusdAmt, "EUSD_BAL");
            require(seedEusdAmt < bal, "KEEP_EUSD_FLOAT");
            console2.log("seedEusdAmt", seedEusdAmt);
            IERC20F(EUSD).approve(address(psm), seedEusdAmt);
            psm.seedEusd(seedEusdAmt);
        }
        if (seedUsdcAmt > 0) {
            uint256 bal = IERC20F(USDC).balanceOf(HOT);
            require(bal >= seedUsdcAmt, "USDC_BAL");
            // If USDC came only from idle borrow, seeding it all into PSM is intentional sized go-live.
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
        console2.log("hotUsdcAfter", IERC20F(USDC).balanceOf(HOT));
        console2.log("landUsdc", IERC20F(USDC).balanceOf(LAND));
        console2.log("PSM_OK", uint256(1));
    }
}
