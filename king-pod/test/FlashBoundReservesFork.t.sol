// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownBoundReservesGate} from "../src/zk/CrownBoundReservesGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownFlashBoundAttest} from "../src/CrownFlashBoundAttest.sol";
import {CrownBoundLandingCompleter} from "../src/CrownBoundLandingCompleter.sol";
import {IERC20} from "../src/lib/Core.sol";

/// @notice Base fork: Morpho flash → bound attest → repay. Opt-in via BASE_RPC_URL.
contract FlashBoundReservesForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant LIVE_VERIFIER = 0xCC1223C0fCA9efe6c4ea4b35A8b9F08b3f8aF681;

    uint256 constant AMT = 700_000e6;

    function test_fork_flash_bound_attest_net_zero() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("ETH_RPC_URL", string(""));
        }
        if (bytes(rpc).length == 0) {
            rpc = "https://mainnet.base.org";
        }

        vm.createSelectFork(rpc);

        CrownBoundReservesGate gate = new CrownBoundReservesGate(LIVE_VERIFIER, USDC, HOT);
        CrownZkCredit credit = new CrownZkCredit(USDC, address(gate), HOT, LANDING, HOT);
        CrownFlashBoundAttest flash = new CrownFlashBoundAttest(MORPHO, USDC, address(gate), HOT, HOT);
        CrownBoundLandingCompleter completer = new CrownBoundLandingCompleter(address(credit), USDC);

        vm.startPrank(HOT);
        gate.setAttestor(address(flash), true);
        credit.setOperator(address(flash), true);
        credit.setOperator(address(completer), true);
        flash.setCredit(address(credit));
        vm.stopPrank();

        uint256 morphoUsdc = IERC20(USDC).balanceOf(MORPHO);
        console2.log("morphoUsdc", morphoUsdc);
        vm.skip(morphoUsdc < AMT);

        uint256 hotBefore = IERC20(USDC).balanceOf(HOT);
        uint256 landingBefore = IERC20(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        IERC20(USDC).approve(address(flash), AMT);
        (bool proven, uint256 landingDelta) = flash.fireLive(AMT);
        vm.stopPrank();

        assertTrue(proven);
        assertTrue(gate.isProven(HOT));
        (uint256 thr,, bool valid) = gate.attestations(HOT);
        assertEq(thr, AMT);
        assertTrue(valid);
        assertEq(IERC20(USDC).balanceOf(HOT), hotBefore);
        assertEq(landingDelta, 0);
        assertEq(IERC20(USDC).balanceOf(LANDING), landingBefore);
        console2.log("FORK PASS: flash bound attest; net-zero hot; Landing unchanged without credit fill");
    }
}
