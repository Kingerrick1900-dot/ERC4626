// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16WalletVerifier} from "../src/zk/Groth16WalletVerifier.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

/// @notice Port WalletGate + Credit (borrow attest) to current chain (Scroll / Polygon / Base).
/// @dev KING_OK=1 FIRE_ZK_BORROW_PORT=1
///      PAY_TOKEN optional override (default: Base USDC / Polygon native USDC).
///      Subject + owner = Broadcaster. Does NOT submitProof or seed pool.
contract FireZkBorrowAttestPort is Script {
    address constant HOT_BASE = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant POLY_DESK = 0x31511861a519D6b814Eb20b4A0bcc391e76177dF;

    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_POLY = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_BORROW_PORT", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        uint256 cid = block.chainid;

        address expected = _kingFor(cid);
        require(me == expected, "NOT_CHAIN_KING");

        address pay = vm.envOr("PAY_TOKEN", _defaultPay(cid));
        require(pay != address(0), "NEED_PAY_TOKEN");
        require(pay.code.length > 0, "PAY_TOKEN_NO_CODE");

        address landing = vm.envOr("LANDING", me);

        vm.startBroadcast(pk);

        Groth16WalletVerifier verifier = new Groth16WalletVerifier();
        CrownZkWalletGate gate = new CrownZkWalletGate(address(verifier), me);
        CrownZkCredit credit = new CrownZkCredit(pay, address(gate), me, landing, me);

        vm.stopBroadcast();

        console2.log("chainId", cid);
        console2.log("king", me);
        console2.log("payToken", pay);
        console2.log("Verifier", address(verifier));
        console2.log("WalletGate", address(gate));
        console2.log("Credit", address(credit));
        console2.log("minThreshold", gate.minThreshold());
        console2.log("isProven", gate.isProven(me));
        console2.log("maxBorrow", credit.maxBorrow(me));
        console2.log("BORROW_ATTEST_PORTED", uint256(1));
    }

    function _kingFor(uint256 cid) internal pure returns (address) {
        if (cid == 8453) return HOT_BASE;
        if (cid == 137) return POLY_DESK;
        if (cid == 534352) return SCROLL_HOT;
        revert("BAD_CHAIN");
    }

    function _defaultPay(uint256 cid) internal pure returns (address) {
        if (cid == 8453) return USDC_BASE;
        if (cid == 137) return USDC_POLY;
        // Scroll: no canonical Circle USDC at probe — require PAY_TOKEN env.
        return address(0);
    }
}
