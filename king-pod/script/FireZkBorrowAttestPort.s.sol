// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16WalletVerifier} from "../src/zk/Groth16WalletVerifier.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Port WalletGate + Credit, submit HOT wallet-bind proof, arm operator borrow→HOT.
/// @dev KING_OK=1 FIRE_ZK_BORROW_PORT=1
///      Proof embedded from zk/proofs/wallet_proof_solidity.json (HOT subject, $700k thr).
contract FireZkBorrowAttestPort is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    address constant POLY_DESK = 0x31511861a519D6b814Eb20b4A0bcc391e76177dF;

    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_POLY = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant AXL_USDC_SCROLL = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_BORROW_PORT", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        uint256 cid = block.chainid;
        require(me == _kingFor(cid), "NOT_CHAIN_KING");

        address pay = vm.envOr("PAY_TOKEN", _defaultPay(cid));
        require(pay != address(0) && pay.code.length > 0, "PAY_TOKEN");

        address king = vm.envOr("CREDIT_KING", HOT);
        address landing = vm.envOr("LANDING", HOT);

        uint256[2] memory a = [
            uint256(12048988102465640172905314028101130600086032236188133696583433730868019738912),
            uint256(6751185041101368692428710312564983984087352288654032930812530393409383248403)
        ];
        uint256[2][2] memory b = [
            [
                uint256(20588998507751808304262868037348882626004016767412258921377484409843671560650),
                uint256(19367750127754755791430797682422793813090157854048114200073800385999660382772)
            ],
            [
                uint256(6892002024905766369161919362346794191885443148302211926492300132605641395109),
                uint256(1123033716927665512781742793197927283097159043809652239919800121231037639807)
            ]
        ];
        uint256[2] memory c = [
            uint256(12069287824939949774779383288777182126146008703283159635652833133740688334589),
            uint256(6651397509912333703099354212762786862825013347027709201582429924400063683422)
        ];
        uint256[4] memory pub = [
            uint256(1),
            uint256(7327697485179643413195764390621562824984627928541399694080225469553212177479),
            uint256(700000000000),
            uint256(588224148543878888622858987941633173888015968209)
        ];
        require(address(uint160(pub[3])) == HOT, "PROOF_NOT_HOT");

        vm.startBroadcast(pk);

        Groth16WalletVerifier verifier = new Groth16WalletVerifier();
        CrownZkWalletGate gate = new CrownZkWalletGate(address(verifier), me);
        CrownZkCredit credit = new CrownZkCredit(pay, address(gate), king, landing, me);

        gate.submitProof(a, b, c, pub);
        credit.setOperator(me, true);

        uint256 seedBal = IERC20P(pay).balanceOf(me);
        if (seedBal > 0) {
            IERC20P(pay).approve(address(credit), seedBal);
            credit.supply(seedBal);
        }

        uint256 mb = credit.maxBorrow(king);
        if (mb > 0 && gate.isProven(king)) {
            credit.operatorBorrowTo(landing, mb);
        }

        vm.stopBroadcast();

        console2.log("chainId", cid);
        console2.log("deployer", me);
        console2.log("payToken", pay);
        console2.log("Verifier", address(verifier));
        console2.log("WalletGate", address(gate));
        console2.log("Credit", address(credit));
        console2.log("isProvenHOT", gate.isProven(HOT));
        console2.log("seeded", seedBal);
        console2.log("debtHOT", credit.debtOf(king));
        console2.log("hotPayBal", IERC20P(pay).balanceOf(landing));
        console2.log("BORROW_ATTEST_PORTED", uint256(1));
        require(gate.isProven(HOT), "HOT_NOT_PROVEN");
    }

    function _kingFor(uint256 cid) internal pure returns (address) {
        if (cid == 8453) return HOT;
        if (cid == 137) return POLY_DESK;
        if (cid == 534352) return SCROLL_HOT;
        revert("BAD_CHAIN");
    }

    function _defaultPay(uint256 cid) internal pure returns (address) {
        if (cid == 8453) return USDC_BASE;
        if (cid == 137) return USDC_POLY;
        if (cid == 534352) return AXL_USDC_SCROLL;
        return address(0);
    }
}
