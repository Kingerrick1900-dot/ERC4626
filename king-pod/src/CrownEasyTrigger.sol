// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IAllowlistET {
    function check(address target, bytes4 selector) external view;
    function isAllowed(address target, bytes4 selector) external view returns (bool);
}

interface IBordersET {
    function bordersSecure() external view returns (bool);
}

interface ICapacityET {
    function canMint(uint256 amount) external view returns (bool);
}

interface ITrancheET {
    function deploy(uint256 usdcAmt) external returns (uint256);
    function remainingCap() external view returns (uint256);
}

/// @title CrownEasyTrigger
/// @notice "Security in the armor, not the gate" — one-tap King paths through KAR + borders + NFC flag.
/// @dev Does not weaken checks; collapses ceremony into a single authorized call.
contract CrownEasyTrigger is Ownable, ReentrancyGuard {
    IAllowlistET public allowlist;
    IBordersET public attest;
    ICapacityET public capacity;
    ITrancheET public tranche;
    address public hot;

    mapping(bytes32 => bool) public nfcReceipts; // spent NFC cosign receipts
    bool public nfcRequired = true;

    event Wired(address allowlist, address attest, address capacity, address tranche);
    event NfcRequired(bool on);
    event EasyDeploy(uint256 amt, bytes32 nfcReceipt);
    event EasyCapacityCheck(uint256 amt, bool ok);

    error Auth();
    error Borders();
    error Nfc();
    error Armor();
    error Bad();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(address hot_, address owner_) Ownable(owner_) {
        hot = hot_;
    }

    function wire(address allowlist_, address attest_, address capacity_, address tranche_) external onlyOwner {
        allowlist = IAllowlistET(allowlist_);
        attest = IBordersET(attest_);
        capacity = ICapacityET(capacity_);
        tranche = ITrancheET(tranche_);
        emit Wired(allowlist_, attest_, capacity_, tranche_);
    }

    function setNfcRequired(bool on) external onlyOwner {
        nfcRequired = on;
        emit NfcRequired(on);
    }

    /// @notice Register NFC cosign receipt (from air-gap card) before easy path.
    function submitNfcReceipt(bytes32 receipt) external onlyHot {
        if (receipt == bytes32(0)) revert Bad();
        nfcReceipts[receipt] = true;
    }

    function _armor(address target, bytes4 selector, bytes32 nfcReceipt) internal {
        if (address(attest) != address(0) && !attest.bordersSecure()) revert Borders();
        if (address(allowlist) != address(0)) {
            allowlist.check(target, selector);
        }
        if (nfcRequired) {
            if (!nfcReceipts[nfcReceipt]) revert Nfc();
            nfcReceipts[nfcReceipt] = false; // one-shot
        }
    }

    /// @notice One-shot: armor check + curator deploy (USDC must already be approved to tranche).
    function easyDeploy(uint256 usdcAmt, bytes32 nfcReceipt) external onlyHot nonReentrant returns (uint256) {
        if (usdcAmt == 0 || address(tranche) == address(0)) revert Bad();
        _armor(address(tranche), ITrancheET.deploy.selector, nfcReceipt);
        if (tranche.remainingCap() < usdcAmt) revert Armor();
        uint256 d = tranche.deploy(usdcAmt);
        emit EasyDeploy(usdcAmt, nfcReceipt);
        return d;
    }

    /// @notice Policy peek for 100T path — does not mint.
    function easyCanMint(uint256 amt) external view returns (bool) {
        if (address(capacity) == address(0)) return false;
        if (address(attest) != address(0) && !attest.bordersSecure()) return false;
        return capacity.canMint(amt);
    }
}
