// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";
import {ProofVecGuard} from "../src/zk/ProofVecGuard.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {MockElepan8, MockElepanOracle, MockZkElepanGate} from "./mocks/MockElepanCdp.sol";

/// @dev Verifier double: always accepts (models under-constrained / broken circuit VK).
contract AlwaysAcceptVerifier {
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[4] calldata)
        external
        pure
        returns (bool)
    {
        return true;
    }
}

/// @dev Verifier double: always rejects.
contract AlwaysRejectVerifier {
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[4] calldata)
        external
        pure
        returns (bool)
    {
        return false;
    }
}

contract CrownZkHardeningTest is Test {
    event SilentFailureFlag(address indexed subject, bytes32 indexed code, uint256 commitment, uint256 threshold);

    address internal king = makeAddr("king");
    address internal attacker = makeAddr("attacker");

    AlwaysAcceptVerifier internal acceptV;
    AlwaysRejectVerifier internal rejectV;
    CrownZkWalletGate internal gateAccept;
    CrownZkWalletGate internal gateReject;

    uint256[2] internal a;
    uint256[2][2] internal b;
    uint256[2] internal c;

    function setUp() public {
        acceptV = new AlwaysAcceptVerifier();
        rejectV = new AlwaysRejectVerifier();
        // Cast: gate stores Groth16WalletVerifier immutable but only calls verifyProof.
        gateAccept = new CrownZkWalletGate(address(acceptV), king);
        gateReject = new CrownZkWalletGate(address(rejectV), king);
        a = [uint256(1), 2];
        b[0] = [uint256(1), 2];
        b[1] = [uint256(3), 4];
        c = [uint256(5), 6];
    }

    function _pub(uint256 ok, uint256 commit, uint256 thresh, address subject)
        internal
        pure
        returns (uint256[4] memory p)
    {
        p[0] = ok;
        p[1] = commit;
        p[2] = thresh;
        p[3] = uint256(uint160(subject));
    }

    /// @notice Malicious / under-constrained path: verifier accepts garbage, but ok!=1 must fail.
    function test_rejects_ok_not_one_even_if_verifier_accepts() public {
        uint256[4] memory pub = _pub(0, 123, 700_000e6, attacker);
        vm.expectRevert(CrownZkWalletGate.BadProof.selector);
        gateAccept.submitProof(a, b, c, pub);
        assertFalse(gateAccept.isProven(attacker));
    }

    /// @notice Under-constrained witness class: threshold below min rejected even if verifier broken.
    function test_rejects_under_min_threshold() public {
        uint256[4] memory pub = _pub(1, 123, 1e6, attacker);
        vm.expectRevert(ProofVecGuard.BadThresholdBound.selector);
        gateAccept.submitProof(a, b, c, pub);
    }

    /// @notice High-bit subject smuggling (public input not address-bound) must fail.
    function test_rejects_subject_high_bits() public {
        uint256[4] memory pub = _pub(1, 123, 700_000e6, attacker);
        pub[3] = uint256(uint160(attacker)) | (uint256(1) << 160);
        vm.expectRevert(ProofVecGuard.BadSubjectBits.selector);
        gateAccept.submitProof(a, b, c, pub);
    }

    /// @notice Field element ≥ r rejected (deserialization / field bound).
    function test_rejects_field_overflow() public {
        uint256[4] memory pub = _pub(1, 123, 700_000e6, attacker);
        pub[1] = ProofVecGuard.SNARK_SCALAR_FIELD;
        vm.expectRevert(ProofVecGuard.BadField.selector);
        gateAccept.submitProof(a, b, c, pub);
    }

    /// @notice Dynamic vector: wrong length / oversized length must not allocate or accept.
    function test_rejects_bad_vec_length() public {
        uint256[] memory bad = new uint256[](5);
        bad[0] = 1;
        bad[1] = 1;
        bad[2] = 700_000e6;
        bad[3] = uint256(uint160(attacker));
        bad[4] = 999; // attacker-supplied extra limb
        vm.expectRevert(ProofVecGuard.BadLen.selector);
        gateAccept.submitProofVec(a, b, c, bad);

        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(ProofVecGuard.BadLen.selector);
        gateAccept.submitProofVec(a, b, c, empty);
    }

    /// @notice Honest-shaped signals + broken verifier still rejected by pairing path.
    function test_rejects_when_verifier_returns_false() public {
        uint256[4] memory pub = _pub(1, 123, 700_000e6, attacker);
        vm.expectRevert(CrownZkWalletGate.BadProof.selector);
        gateReject.submitProof(a, b, c, pub);
    }

    /// @notice Accepting verifier with well-formed publics proves subject (models valid proof).
    function test_accepts_well_formed_when_verifier_ok() public {
        uint256[4] memory pub = _pub(1, 0xC0FFEE, 700_000e6, king);
        gateAccept.submitProof(a, b, c, pub);
        assertTrue(gateAccept.isProven(king));
        assertEq(gateAccept.commitmentOf(king), 0xC0FFEE);
    }

    /// @notice Zero commitment accepted by broken verifier → silent-failure flag + monitor view.
    function test_silent_failure_zero_commitment() public {
        uint256[4] memory pub = _pub(1, 0, 700_000e6, king);
        vm.expectEmit(true, true, false, true);
        emit SilentFailureFlag(king, bytes32("ZERO_COMMIT"), 0, 700_000e6);
        gateAccept.submitProof(a, b, c, pub);
        (bool healthy, bytes32 code) = gateAccept.checkSilentFailure(king);
        assertFalse(healthy);
        assertEq(code, bytes32("ZERO_COMMIT"));
    }

    /// @notice Stale attestation flagged by monitor (valid bit still set in storage).
    function test_silent_failure_stale_valid() public {
        uint256[4] memory pub = _pub(1, 99, 700_000e6, king);
        gateAccept.submitProof(a, b, c, pub);
        vm.warp(block.timestamp + 8 days);
        assertFalse(gateAccept.isProven(king));
        (bool healthy, bytes32 code) = gateAccept.checkSilentFailure(king);
        assertFalse(healthy);
        assertEq(code, bytes32("STALE_VALID"));
    }
}

/// @notice CDP direct-collateral fallback when ZK attestation fails.
contract CrownZkFallbackCdpTest is Test {
    address internal king = makeAddr("king");
    MockElepan8 internal elepan;
    MockElepanOracle internal oracle;
    MockZkElepanGate internal zkGate;
    CrownElepanUsd internal eusd;
    CrownElepanCdpVault internal vault;

    uint256 constant LR = 1.5e18;
    uint256 constant FLOOR = 1.55e18;
    uint256 constant FEE_BPS = 500;

    function setUp() public {
        elepan = new MockElepan8();
        oracle = new MockElepanOracle();
        zkGate = new MockZkElepanGate();
        zkGate.setProofTtl(0);
        zkGate.setProven(king, true);
        eusd = new CrownElepanUsd(king);
        vault = new CrownElepanCdpVault(
            address(elepan),
            address(eusd),
            address(oracle),
            address(zkGate),
            king,
            king,
            king,
            LR,
            FLOOR,
            FEE_BPS
        );
        vm.prank(king);
        eusd.setMinter(address(vault), true);
        elepan.mint(king, 100_000_000e8);
        vm.prank(king);
        elepan.approve(address(vault), type(uint256).max);
    }

    function test_fallback_disabled_blocks_when_zk_fails() public {
        zkGate.setProven(king, false);
        vm.prank(king);
        vm.expectRevert(MockZkElepanGate.Expired.selector);
        vault.deposit(1e8);
    }

    function test_fallback_enables_direct_collateral_lock_and_mint() public {
        zkGate.setProven(king, false);
        vm.prank(king);
        vault.setZkFallback(true);
        assertTrue(vault.mutationAllowed(king));
        assertFalse(vault.zkMintAllowed(king));

        vm.startPrank(king);
        vault.deposit(30_000_000e8);
        vault.mint(10_000_000e18);
        vm.stopPrank();

        assertEq(vault.coll(), 30_000_000e8);
        assertEq(eusd.balanceOf(king), 10_000_000e18);
        assertEq(elepan.balanceOf(address(vault)), 30_000_000e8);
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_fallback_still_enforces_hf_and_real_collateral() public {
        zkGate.setProven(king, false);
        vm.startPrank(king);
        vault.setZkFallback(true);
        vault.deposit(20_000_000e8);
        vm.expectRevert(CrownElepanCdpVault.UnsafeHf.selector);
        vault.mint(14_000_000e18); // would be HF < floor at soft $1
        vm.stopPrank();
    }

    function test_fallback_does_not_open_rando() public {
        zkGate.setProven(king, false);
        vm.prank(king);
        vault.setZkFallback(true);
        address rando = makeAddr("rando");
        zkGate.setProven(rando, false);
        vm.prank(rando);
        vm.expectRevert();
        vault.deposit(1e8);
    }
}
