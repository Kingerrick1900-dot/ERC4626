// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateH {
    function isProven(address subject) external view returns (bool);
}

interface IBordersH {
    function bordersSecure() external view returns (bool);
}

interface IMorphoH {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
}

/// @notice Harvester — seed Morpho only under WalletGate + borders.
contract CrownHarvesterZk is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoH public immutable morpho;
    IZkGateH public immutable zkGate;
    IBordersH public immutable attest;

    address public railToken;
    address public beneficiary;
    IMorphoH.MarketParams public rail;
    uint256 public totalSeeded;
    mapping(address => bool) public bot;

    event BotSet(address indexed bot, bool ok);
    event RailSet(address token);
    event Seeded(address indexed token, uint256 amount, address indexed onBehalf);
    event Swept(address indexed token, uint256 amount);

    error Auth();
    error Zero();
    error NotProven();
    error Borders();

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner) revert Auth();
        _;
    }

    modifier whenZk() {
        if (!zkGate.isProven(msg.sender) && msg.sender != owner) {
            // owner (Safe) still must be proven as king custody
            if (!zkGate.isProven(owner)) revert NotProven();
        } else if (!zkGate.isProven(msg.sender)) {
            revert NotProven();
        }
        if (!zkGate.isProven(owner)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(address morpho_, address zkGate_, address attest_, address owner_, address beneficiary_)
        Ownable(owner_)
    {
        require(morpho_ != address(0) && zkGate_ != address(0) && attest_ != address(0), "ZERO");
        morpho = IMorphoH(morpho_);
        zkGate = IZkGateH(zkGate_);
        attest = IBordersH(attest_);
        beneficiary = beneficiary_;
        bot[owner_] = true;
    }

    function setBot(address b, bool ok) external onlyOwner {
        bot[b] = ok;
        emit BotSet(b, ok);
    }

    function setBeneficiary(address b) external onlyOwner {
        if (b == address(0)) revert Zero();
        beneficiary = b;
    }

    function setRailParams(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    ) external onlyOwner {
        rail = IMorphoH.MarketParams(loanToken, collateralToken, oracle, irm, lltv);
        railToken = loanToken;
        emit RailSet(loanToken);
    }

    function seedRail(uint256 amount) external onlyBot nonReentrant whenZk {
        if (amount == 0 || railToken == address(0)) revert Zero();
        IERC20 t = IERC20(railToken);
        t.safeTransferFrom(msg.sender, address(this), amount);
        t.safeApprove(address(morpho), amount);
        morpho.supply(rail, amount, 0, beneficiary, "");
        totalSeeded += amount;
        emit Seeded(railToken, amount, beneficiary);
    }

    function seedBalance() external onlyOwner nonReentrant whenZk {
        if (railToken == address(0)) revert Zero();
        uint256 bal = IERC20(railToken).balanceOf(address(this));
        if (bal == 0) revert Zero();
        IERC20(railToken).safeApprove(address(morpho), bal);
        morpho.supply(rail, bal, 0, beneficiary, "");
        totalSeeded += bal;
        emit Seeded(railToken, bal, beneficiary);
    }

    function sweep(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) revert Zero();
        IERC20(token).safeTransfer(owner, bal);
        emit Swept(token, bal);
    }
}
