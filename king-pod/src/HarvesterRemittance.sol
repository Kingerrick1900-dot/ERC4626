// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateHR {
    function isProven(address subject) external view returns (bool);
}

interface IBordersHR {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 6a — Nigeria remittance fee harvester. One line. Zero competition.
/// @dev 2% fees from CrownNigeriaDesk route to HOT. No liquidation. No MEV.
contract HarvesterRemittance is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint8 public constant LINE_NIGERIA = 1;
    uint256 public constant FEE_BPS = 200;

    IERC20 public immutable usdc;
    IZkGateHR public immutable zkGate;
    IBordersHR public immutable attest;
    address public immutable king;
    address public immutable hot; // fee recipient
    address public immutable krt; // Build 3
    address public immutable nigeriaDesk; // Build 5
    address public immutable sovereignRail; // Build 1

    uint256 public totalHarvestedUsdc;
    uint256 public harvestCount;

    event RemittanceHarvested(address indexed from, uint256 usdcFee, bytes32 ref, uint256 total);

    error Auth();
    error Zero();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address usdc_,
        address zkGate_,
        address attest_,
        address king_,
        address hot_,
        address krt_,
        address nigeriaDesk_,
        address sovereignRail_,
        address owner_
    ) Ownable(owner_) {
        require(
            usdc_ != address(0) && zkGate_ != address(0) && attest_ != address(0) && king_ != address(0)
                && hot_ != address(0) && krt_ != address(0) && nigeriaDesk_ != address(0)
                && sovereignRail_ != address(0),
            "ZERO"
        );
        usdc = IERC20(usdc_);
        zkGate = IZkGateHR(zkGate_);
        attest = IBordersHR(attest_);
        king = king_;
        hot = hot_;
        krt = krt_;
        nigeriaDesk = nigeriaDesk_;
        sovereignRail = sovereignRail_;
    }

    /// @notice Pull USDC remittance fee → HOT. Books Nigeria line only.
    function harvest(uint256 usdcFee, bytes32 ref) external nonReentrant whenZk {
        if (usdcFee == 0) revert Zero();
        if (msg.sender != owner && msg.sender != king && msg.sender != nigeriaDesk) revert Auth();

        usdc.safeTransferFrom(msg.sender, hot, usdcFee);
        totalHarvestedUsdc += usdcFee;
        unchecked {
            ++harvestCount;
        }
        emit RemittanceHarvested(msg.sender, usdcFee, ref, totalHarvestedUsdc);
    }

    /// @notice Sweep any USDC stuck on this contract → HOT.
    function sweep() external onlyOwner nonReentrant whenZk {
        uint256 bal = usdc.balanceOf(address(this));
        if (bal == 0) revert Zero();
        usdc.safeTransfer(hot, bal);
        totalHarvestedUsdc += bal;
        unchecked {
            ++harvestCount;
        }
        emit RemittanceHarvested(address(this), bal, bytes32("SWEEP"), totalHarvestedUsdc);
    }
}
