// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateHF {
    function isProven(address subject) external view returns (bool);
}

interface IBordersHF {
    function bordersSecure() external view returns (bool);
}

/// @notice Build 6b — AMO fee harvester. Ocean / ySYNTH / Curator / HuntRouter / ZK tips → HOT.
/// @dev No liquidation. No MEV. One collector, five fee sources.
contract HarvesterFees is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint8 public constant SRC_OCEAN = 1;
    uint8 public constant SRC_YSYNTH = 2;
    uint8 public constant SRC_CURATOR = 3;
    uint8 public constant SRC_HUNT = 4;
    uint8 public constant SRC_ZK_TIP = 5;

    IERC20 public immutable usdc;
    IZkGateHF public immutable zkGate;
    IBordersHF public immutable attest;
    address public immutable king;
    address public immutable hot;

    mapping(uint8 => uint256) public feesBySource;
    uint256 public totalHarvestedUsdc;
    mapping(address => bool) public bot;

    event FeeHarvested(uint8 indexed source, address indexed from, uint256 usdcFee, bytes32 ref);
    event BotSet(address indexed bot, bool ok);

    error Auth();
    error Zero();
    error BadSource();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner && msg.sender != king) revert Auth();
        _;
    }

    constructor(address usdc_, address zkGate_, address attest_, address king_, address hot_, address owner_)
        Ownable(owner_)
    {
        require(
            usdc_ != address(0) && zkGate_ != address(0) && attest_ != address(0) && king_ != address(0)
                && hot_ != address(0),
            "ZERO"
        );
        usdc = IERC20(usdc_);
        zkGate = IZkGateHF(zkGate_);
        attest = IBordersHF(attest_);
        king = king_;
        hot = hot_;
        bot[owner_] = true;
        bot[king_] = true;
    }

    function setBot(address b, bool ok) external onlyOwner {
        bot[b] = ok;
        emit BotSet(b, ok);
    }

    function harvestOcean(uint256 usdcFee, bytes32 ref) external onlyBot nonReentrant whenZk {
        _pull(SRC_OCEAN, usdcFee, ref);
    }

    function harvestYsynth(uint256 usdcFee, bytes32 ref) external onlyBot nonReentrant whenZk {
        _pull(SRC_YSYNTH, usdcFee, ref);
    }

    function harvestCurator(uint256 usdcFee, bytes32 ref) external onlyBot nonReentrant whenZk {
        _pull(SRC_CURATOR, usdcFee, ref);
    }

    function harvestHunt(uint256 usdcFee, bytes32 ref) external onlyBot nonReentrant whenZk {
        _pull(SRC_HUNT, usdcFee, ref);
    }

    function harvestZkTip(uint256 usdcFee, bytes32 ref) external onlyBot nonReentrant whenZk {
        _pull(SRC_ZK_TIP, usdcFee, ref);
    }

    function _pull(uint8 source, uint256 usdcFee, bytes32 ref) internal {
        if (source == 0 || source > 5) revert BadSource();
        if (usdcFee == 0) revert Zero();
        usdc.safeTransferFrom(msg.sender, hot, usdcFee);
        feesBySource[source] += usdcFee;
        totalHarvestedUsdc += usdcFee;
        emit FeeHarvested(source, msg.sender, usdcFee, ref);
    }
}
