// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoHarvest {
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

    function createMarket(MarketParams memory marketParams) external;
}

/// @notice Inbound engine: sweep spoils / fees → Morpho idle on a named rail.
/// @dev Arb/liq bots call `seedRail` with profits. Owner can push Kingdom eUSD/USDC spoils.
contract CrownHarvester is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoHarvest public immutable morpho;
    address public railToken; // USDC or eUSD
    address public beneficiary; // Morpho onBehalf (Killer / vault / HOT)

    IMorphoHarvest.MarketParams public rail;

    uint256 public totalSeeded;
    mapping(address => bool) public bot;

    event BotSet(address indexed bot, bool ok);
    event RailSet(address token, bytes32 hint);
    event Seeded(address indexed token, uint256 amount, address indexed onBehalf);
    event Swept(address indexed token, uint256 amount);

    error Auth();
    error Zero();

    modifier onlyBot() {
        if (!bot[msg.sender] && msg.sender != owner) revert Auth();
        _;
    }

    constructor(address morpho_, address owner_, address beneficiary_) Ownable(owner_) {
        morpho = IMorphoHarvest(morpho_);
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

    function setRail(IMorphoHarvest.MarketParams calldata m) external onlyOwner {
        _setRail(m);
    }

    function setRailParams(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    ) external onlyOwner {
        _setRail(IMorphoHarvest.MarketParams(loanToken, collateralToken, oracle, irm, lltv));
    }

    function _setRail(IMorphoHarvest.MarketParams memory m) internal {
        rail = m;
        railToken = m.loanToken;
        emit RailSet(m.loanToken, bytes32(0));
    }

    /// @notice Push token into Morpho rail as supply (real idle).
    function seedRail(uint256 amount) external onlyBot nonReentrant {
        if (amount == 0 || railToken == address(0)) revert Zero();
        IERC20 t = IERC20(railToken);
        t.safeTransferFrom(msg.sender, address(this), amount);
        t.safeApprove(address(morpho), amount);
        morpho.supply(rail, amount, 0, beneficiary, "");
        totalSeeded += amount;
        emit Seeded(railToken, amount, beneficiary);
    }

    /// @notice Owner spoil push: harvest tokens already on this contract into the rail.
    function seedBalance() external onlyOwner nonReentrant {
        if (railToken == address(0)) revert Zero();
        uint256 bal = IERC20(railToken).balanceOf(address(this));
        if (bal == 0) revert Zero();
        IERC20(railToken).safeApprove(address(morpho), bal);
        morpho.supply(rail, bal, 0, beneficiary, "");
        totalSeeded += bal;
        emit Seeded(railToken, bal, beneficiary);
    }

    /// @notice Sweep stray ERC20 to HOT.
    function sweep(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) revert Zero();
        IERC20(token).safeTransfer(owner, bal);
        emit Swept(token, bal);
    }

    receive() external payable {}
}
