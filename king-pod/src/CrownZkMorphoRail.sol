// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IZkGateR {
    function isProven(address subject) external view returns (bool);
}

interface IBordersR {
    function bordersSecure() external view returns (bool);
}

interface IMorphoR {
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

    function withdraw(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @title CrownZkMorphoRail — Morpho supply/withdraw only when WalletGate+borders hold.
/// @dev Quantum law on-chain. Unshielded Morpho direct supply is not Kingdom fire.
contract CrownZkMorphoRail is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoR public immutable morpho;
    IZkGateR public immutable zkGate;
    IBordersR public immutable attest;
    address public immutable king; // Safe — default onBehalf

    IMorphoR.MarketParams public rail;
    bytes32 public railId;
    address public railToken;

    uint256 public totalSupplied;
    uint256 public totalWithdrawn;

    event RailSet(bytes32 id, address loan);
    event ZkSupplied(address indexed from, address indexed onBehalf, uint256 assets, uint256 shares);
    event ZkWithdrawn(address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares);

    error NotProven();
    error Borders();
    error Zero();
    error BadRail();

    modifier whenZk() {
        if (!zkGate.isProven(msg.sender)) revert NotProven();
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(address morpho_, address zkGate_, address attest_, address king_, address owner_) Ownable(owner_) {
        require(
            morpho_ != address(0) && zkGate_ != address(0) && attest_ != address(0) && king_ != address(0), "ZERO"
        );
        morpho = IMorphoR(morpho_);
        zkGate = IZkGateR(zkGate_);
        attest = IBordersR(attest_);
        king = king_;
    }

    function setRail(IMorphoR.MarketParams calldata m) external onlyOwner {
        _setRail(m);
    }

    function setRailParams(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    ) external onlyOwner {
        _setRail(IMorphoR.MarketParams(loanToken, collateralToken, oracle, irm, lltv));
    }

    function _setRail(IMorphoR.MarketParams memory m) internal {
        if (m.loanToken == address(0)) revert Zero();
        rail = m;
        railToken = m.loanToken;
        railId = keccak256(abi.encode(m));
        emit RailSet(railId, m.loanToken);
    }

    /// @notice Pull `assets` from msg.sender and supply to Morpho under ZK law.
    /// @dev onBehalf=0 → king (Safe). Caller must be WalletGate-proven.
    function zkSupply(uint256 assets, address onBehalf) external nonReentrant whenZk returns (uint256, uint256) {
        if (assets == 0 || railToken == address(0)) revert Zero();
        if (onBehalf == address(0)) onBehalf = king;
        if (!zkGate.isProven(onBehalf) && onBehalf != king) revert NotProven();

        IERC20 t = IERC20(railToken);
        t.safeTransferFrom(msg.sender, address(this), assets);
        t.safeApprove(address(morpho), assets);
        (uint256 a, uint256 s) = morpho.supply(rail, assets, 0, onBehalf, "");
        totalSupplied += a;
        emit ZkSupplied(msg.sender, onBehalf, a, s);
        return (a, s);
    }

    /// @notice Withdraw Morpho supply shares/assets for msg.sender under ZK law.
    function zkWithdraw(uint256 assets, uint256 shares, address receiver)
        external
        nonReentrant
        whenZk
        returns (uint256, uint256)
    {
        if (railToken == address(0)) revert Zero();
        if (assets == 0 && shares == 0) revert Zero();
        if (receiver == address(0)) receiver = msg.sender;
        (uint256 a, uint256 s) = morpho.withdraw(rail, assets, shares, msg.sender, receiver);
        totalWithdrawn += a;
        emit ZkWithdrawn(msg.sender, receiver, a, s);
        return (a, s);
    }

    /// @notice Owner rescue stray ERC20.
    function sweep(address token, address to) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) revert Zero();
        IERC20(token).safeTransfer(to, bal);
    }
}
