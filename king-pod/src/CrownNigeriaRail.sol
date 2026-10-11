// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateNR {
    function isProven(address subject) external view returns (bool);
}

interface IBordersNR {
    function bordersSecure() external view returns (bool);
}

interface INigeriaDeskNR {
    function FEE_BPS() external view returns (uint256);
    function feeSink() external view returns (address);
    function totalFeesUsdc() external view returns (uint256);
    function settleCount() external view returns (uint256);
}

interface IHarvesterRemitNR {
    function totalHarvestedUsdc() external view returns (uint256);
}

/// @notice Nigeria remittance rail — opens the live corridor (desk + remittance harvester + registry).
/// @dev Doctrine: Nigeria first. KYC off-chain. 2% USDC → HOT. Not gated on China.
contract CrownNigeriaRail is Ownable {
    IZkGateNR public immutable zkGate;
    IBordersNR public immutable attest;
    address public immutable king;
    address public immutable hot;

    address public immutable desk;
    address public immutable harvesterRemittance;
    address public immutable krt;
    address public immutable oracle;
    address public immutable sovereignRail;
    address public immutable killMetric;
    bytes32 public immutable marketId;

    bool public open;
    uint256 public openedAt;

    event RailOpened(address indexed opener, uint256 timestamp);

    error Auth();
    error AlreadyOpen();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address zkGate_,
        address attest_,
        address king_,
        address hot_,
        address desk_,
        address harvesterRemittance_,
        address krt_,
        address oracle_,
        address sovereignRail_,
        address killMetric_,
        bytes32 marketId_,
        address owner_
    ) Ownable(owner_) {
        require(
            zkGate_ != address(0) && attest_ != address(0) && king_ != address(0) && hot_ != address(0)
                && desk_ != address(0) && harvesterRemittance_ != address(0) && krt_ != address(0)
                && oracle_ != address(0) && sovereignRail_ != address(0) && killMetric_ != address(0),
            "ZERO"
        );
        zkGate = IZkGateNR(zkGate_);
        attest = IBordersNR(attest_);
        king = king_;
        hot = hot_;
        desk = desk_;
        harvesterRemittance = harvesterRemittance_;
        krt = krt_;
        oracle = oracle_;
        sovereignRail = sovereignRail_;
        killMetric = killMetric_;
        marketId = marketId_;
    }

    /// @notice One fire — declare Nigeria remittance rail OPEN.
    function fireOpen() external whenZk {
        if (msg.sender != owner && msg.sender != king && msg.sender != hot) revert Auth();
        if (open) revert AlreadyOpen();
        open = true;
        openedAt = block.timestamp;
        emit RailOpened(msg.sender, block.timestamp);
    }

    /// @notice Public corridor status — settle on desk: settleRemittance(agent, usdcAmount).
    function status()
        external
        view
        returns (
            bool isOpen,
            uint256 opened,
            uint256 feeBps,
            address feeTo,
            uint256 deskFees,
            uint256 deskSettles,
            uint256 harvested
        )
    {
        isOpen = open;
        opened = openedAt;
        feeBps = INigeriaDeskNR(desk).FEE_BPS();
        feeTo = INigeriaDeskNR(desk).feeSink();
        deskFees = INigeriaDeskNR(desk).totalFeesUsdc();
        deskSettles = INigeriaDeskNR(desk).settleCount();
        harvested = IHarvesterRemitNR(harvesterRemittance).totalHarvestedUsdc();
    }
}
