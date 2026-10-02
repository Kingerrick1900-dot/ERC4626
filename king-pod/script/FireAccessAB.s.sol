// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownMeasuredAccess} from "../src/CrownMeasuredAccess.sol";

interface IMorphoA {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20a {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IVaultA {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @notice FIRE A+B: eUSD→borrow synth idle to HOT; USDC→ySYNTH.deposit. C = measured-access spec.
contract FireAccessAB is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YSYNTH = 0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000;
    bytes32 constant SYNTH = 0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd;
    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        (uint128 synS,, uint128 synB,,,) = IMorphoA(MORPHO).market(SYNTH);
        uint256 idleA = uint256(synS) > uint256(synB) ? uint256(synS) - uint256(synB) : 0;
        (uint128 cbS,, uint128 cbB,,,) = IMorphoA(MORPHO).market(CBBTC_ID);
        uint256 idleB = uint256(cbS) > uint256(cbB) ? uint256(cbS) - uint256(cbB) : 0;

        uint256 hotUsdcBefore = IERC20a(USDC).balanceOf(HOT);
        uint256 vaultBefore = IVaultA(YSYNTH).totalAssets();
        uint256 cbBal = IERC20a(CBBTC).balanceOf(HOT);

        console2.log("FIRE", "access-AB");
        console2.log("idleA_synth", idleA);
        console2.log("idleB_cbBtc", idleB);
        console2.log("cbBtcBal", cbBal);
        console2.log("hotUsdcBefore", hotUsdcBefore);
        console2.log("vaultBefore", vaultBefore);

        vm.startBroadcast(pk);

        CrownMeasuredAccess accessC =
            new CrownMeasuredAccess(MORPHO, YSYNTH, USDC, EUSD, HOT, ORACLE, IRM, LLTV, HOT);

        if (!IMorphoA(MORPHO).isAuthorized(HOT, address(accessC))) {
            IMorphoA(MORPHO).setAuthorization(address(accessC), true);
        }

        uint256 dep = hotUsdcBefore > 10_000 ? hotUsdcBefore - 10_000 : 0;
        if (dep > 0) IERC20a(USDC).approve(address(accessC), dep);

        uint256 borrowAmt = idleA;
        uint256 eusdColl;
        if (borrowAmt > 0) {
            eusdColl = (borrowAmt * 1e12 * 1e18) / LLTV + 1e18;
            if (eusdColl < 1e18) eusdColl = 1e18;
            IERC20a(EUSD).approve(address(accessC), eusdColl);
        }

        // B deposit + A borrow in one access(); minRetain = borrowed amount
        accessC.access(dep, eusdColl, borrowAmt, borrowAmt);

        vm.stopBroadcast();

        console2.log("CrownMeasuredAccess", address(accessC));
        console2.log("hotUsdcAfter", IERC20a(USDC).balanceOf(HOT));
        console2.log("vaultAfter", IVaultA(YSYNTH).totalAssets());
        console2.log("ySynthBal", IVaultA(YSYNTH).balanceOf(HOT));
        console2.log("cbBtcBorrow", cbBal > 0 && idleB > 0 ? "SKIP_DUST_COLL_257wei" : "SKIP");
    }
}
