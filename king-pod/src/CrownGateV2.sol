// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, ReentrancyGuard} from "./lib/Core.sol";
import {IMorphoMarket} from "./interfaces/IMorphoMarket.sol";

interface IMorphoGate is IMorphoMarket {
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
}

interface IZkGateV2 {
    function isProven(address subject) external view returns (bool);
    function attestations(address subject) external view returns (uint256 threshold, uint256 provenAt, bool valid);
}

/// @notice King-controlled Morpho Blue gate for the sovereign RSS/USDC market.
/// @dev Position onBehalf = this. Supply/borrow require live ZK wallet-bind on `zkGate`.
///      Doctrine: nothing fires without ZK. Repay/withdraw stay King-only (exit if TTL expires).
contract CrownGateV2 is ReentrancyGuard {
    using SafeTransfer for IERC20;

    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address public immutable loanToken;
    address public immutable collateralToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;
    bytes32 public immutable MARKET_ID;
    IZkGateV2 public immutable zkGate;

    IERC20 public immutable LOAN_TOKEN;
    IERC20 public immutable COLLATERAL_TOKEN;

    address public king;
    address public pendingKing;
    bool public paused;
    mapping(address => bool) public operator;

    event Supplied(uint256 amount);
    event Borrowed(uint256 assets, uint256 shares, address indexed to);
    event Repaid(uint256 assets, uint256 shares);
    event Withdrawn(uint256 amount, address indexed to);
    event KingTransferInitiated(address indexed newKing);
    event KingTransferCompleted(address indexed newKing);
    event Paused(bool isPaused);
    event Rescued(address indexed token, uint256 amount, address indexed to);
    event ApprovalsReset();
    event OperatorSet(address indexed op, bool allowed);

    error NotKing();
    error NotProven();
    error ZeroAmount();
    error ZeroAddress();
    error IsPaused();
    error RescueBlocked();

    modifier onlyKing() {
        if (msg.sender != king) revert NotKing();
        _;
    }

    modifier onlyKingOrOperator() {
        if (msg.sender != king && !operator[msg.sender]) revert NotKing();
        _;
    }

    /// @dev Fire path: valid ZK attestation on King required.
    modifier whenZkFire() {
        if (!zkGate.isProven(king)) revert NotProven();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert IsPaused();
        _;
    }

    /// @param _operator Optional initial operator (pass address(0) for none).
    constructor(
        address _king,
        address _zkGate,
        IMorphoMarket.MarketParams memory _params,
        address _operator
    ) {
        if (_king == address(0) || _zkGate == address(0)) revert ZeroAddress();
        if (_params.loanToken == address(0) || _params.collateralToken == address(0)) revert ZeroAddress();
        if (_params.oracle == address(0) || _params.irm == address(0)) revert ZeroAddress();

        king = _king;
        zkGate = IZkGateV2(_zkGate);
        loanToken = _params.loanToken;
        collateralToken = _params.collateralToken;
        oracle = _params.oracle;
        irm = _params.irm;
        lltv = _params.lltv;
        MARKET_ID = keccak256(abi.encode(_params));

        LOAN_TOKEN = IERC20(_params.loanToken);
        COLLATERAL_TOKEN = IERC20(_params.collateralToken);

        COLLATERAL_TOKEN.safeApprove(MORPHO, type(uint256).max);
        LOAN_TOKEN.safeApprove(MORPHO, type(uint256).max);

        if (_operator != address(0)) {
            operator[_operator] = true;
            emit OperatorSet(_operator, true);
        }
    }

    function marketParams() public view returns (IMorphoMarket.MarketParams memory) {
        return IMorphoMarket.MarketParams(loanToken, collateralToken, oracle, irm, lltv);
    }

    /// @notice King posts RSS. Requires `zkGate.isProven(king)`.
    function supplyCollateral(uint256 amount) external onlyKing whenNotPaused whenZkFire nonReentrant {
        if (amount == 0) revert ZeroAmount();
        COLLATERAL_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        IMorphoGate(MORPHO).supplyCollateral(marketParams(), amount, address(this), "");
        emit Supplied(amount);
    }

    /// @notice King or AutoDraw operator borrows USDC. Requires ZK attestation.
    function borrowUSDC(uint256 assets, address to) external onlyKingOrOperator whenNotPaused whenZkFire nonReentrant {
        if (assets == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        (uint256 a, uint256 s) = IMorphoGate(MORPHO).borrow(marketParams(), assets, 0, address(this), to);
        emit Borrowed(a, s, to);
    }

    /// @notice Exit path — King-only, no ZK (TTL expiry must not trap position).
    function repayUSDC(uint256 assets) external onlyKing nonReentrant {
        if (assets == 0) revert ZeroAmount();
        LOAN_TOKEN.safeTransferFrom(msg.sender, address(this), assets);
        (uint256 a, uint256 s) = IMorphoGate(MORPHO).repay(marketParams(), assets, 0, address(this), "");
        emit Repaid(a, s);
    }

    /// @notice Exit path — King-only, no ZK.
    function withdrawCollateral(uint256 amount, address to) external onlyKing nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        IMorphoGate(MORPHO).withdrawCollateral(marketParams(), amount, address(this), to);
        emit Withdrawn(amount, to);
    }

    function setOperator(address op, bool allowed) external onlyKing {
        if (op == address(0)) revert ZeroAddress();
        operator[op] = allowed;
        emit OperatorSet(op, allowed);
    }

    function setPaused(bool _paused) external onlyKing {
        paused = _paused;
        emit Paused(_paused);
    }

    function initiateKingTransfer(address newKing) external onlyKing {
        if (newKing == address(0)) revert ZeroAddress();
        pendingKing = newKing;
        emit KingTransferInitiated(newKing);
    }

    function acceptKingship() external {
        if (msg.sender != pendingKing) revert NotKing();
        king = pendingKing;
        pendingKing = address(0);
        emit KingTransferCompleted(king);
    }

    function resetApprovals() external onlyKing {
        COLLATERAL_TOKEN.safeApprove(MORPHO, 0);
        LOAN_TOKEN.safeApprove(MORPHO, 0);
        COLLATERAL_TOKEN.safeApprove(MORPHO, type(uint256).max);
        LOAN_TOKEN.safeApprove(MORPHO, type(uint256).max);
        emit ApprovalsReset();
    }

    function rescueToken(address token, uint256 amount, address to) external onlyKing nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (token == address(COLLATERAL_TOKEN)) revert RescueBlocked();
        IERC20(token).safeTransfer(to, amount);
        emit Rescued(token, amount, to);
    }
}
