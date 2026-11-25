// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IBordersX {
    function bordersSecure() external view returns (bool);
}

interface IPqX {
    function activeDilithium() external view returns (bytes32);
}

/// @title CrownExitNative
/// @notice Final boss solver — eUSD → cbBTC / WETH / USDC from Kingdom hunt inventory.
/// @dev No external pool required. Hunt bots fundInventory; King exits quantum-gated.
contract CrownExitNative is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public immutable hot;
    address public attest;
    address public pq;
    address public usdc;
    address public cbbtc;
    address public weth;

    bool public requireBorders = true;
    bool public requirePq = true;

    // eUSD (18dp) per 1 unit of out token (out token native decimals), owner-set from hunt oracle
    mapping(address => uint256) public eusdPerOut; // scaled 1e18: eUSD wei for 1 full out token
    mapping(bytes32 => bool) public nfcUsed;

    uint256 public totalExitedEusd;
    mapping(address => uint256) public totalOut;

    event InventoryFunded(address indexed token, uint256 amt, address from);
    event RateSet(address indexed token, uint256 eusdPerOut);
    event Exited(address indexed to, address indexed tokenOut, uint256 eusdIn, uint256 outAmt, bytes32 nfc);

    error Auth();
    error Borders();
    error Pq();
    error Bad();
    error Nfc();
    error Inventory();
    error Rate();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address eusd_,
        address hot_,
        address usdc_,
        address cbbtc_,
        address weth_,
        address owner_
    ) Ownable(owner_) {
        eusd = IERC20(eusd_);
        hot = hot_;
        usdc = usdc_;
        cbbtc = cbbtc_;
        weth = weth_;
        // Default: $1 eUSD ↔ $1 USDC (1e18 eUSD per 1e6 USDC → 1e12)
        eusdPerOut[usdc_] = 1e12;
    }

    function setArmor(address attest_, address pq_) external onlyOwner {
        attest = attest_;
        pq = pq_;
    }

    function setRate(address token, uint256 rate) external onlyOwner {
        if (token == address(0) || rate == 0) revert Bad();
        eusdPerOut[token] = rate;
        emit RateSet(token, rate);
    }

    /// @notice Hunt bots / King seed hard-asset inventory.
    function fundInventory(address token, uint256 amt) external nonReentrant {
        if (token != usdc && token != cbbtc && token != weth) revert Bad();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        emit InventoryFunded(token, amt, msg.sender);
    }

    /// @notice Exit eUSD into hard asset. Quantum + NFC gated.
    function exit(uint256 eusdAmt, address tokenOut, uint256 minOut, bytes32 nfcReceipt)
        external
        onlyHot
        nonReentrant
        returns (uint256 outAmt)
    {
        if (eusdAmt == 0 || nfcReceipt == bytes32(0)) revert Bad();
        if (tokenOut != usdc && tokenOut != cbbtc && tokenOut != weth) revert Bad();
        if (nfcUsed[nfcReceipt]) revert Nfc();
        _gate();
        uint256 rate = eusdPerOut[tokenOut];
        if (rate == 0) revert Rate();

        // outAmt = eusdAmt / rate  (both sides wei)
        outAmt = eusdAmt / rate;
        if (outAmt < minOut) revert Bad();
        if (IERC20(tokenOut).balanceOf(address(this)) < outAmt) revert Inventory();

        nfcUsed[nfcReceipt] = true;
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        IERC20(tokenOut).safeTransfer(hot, outAmt);

        totalExitedEusd += eusdAmt;
        totalOut[tokenOut] += outAmt;
        emit Exited(hot, tokenOut, eusdAmt, outAmt, nfcReceipt);
    }

    function inventory(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _gate() internal view {
        if (requireBorders && attest != address(0) && !IBordersX(attest).bordersSecure()) revert Borders();
        if (requirePq && pq != address(0) && IPqX(pq).activeDilithium() == bytes32(0)) revert Pq();
    }
}
