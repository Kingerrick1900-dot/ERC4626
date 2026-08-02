// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Poor-man's seed cannon: one address, one approve, USDC → Landing ops and/or yELE vault.
/// @dev Matcher funds the nation without touching Morpho idle myths.
interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ILoanCompleteS {
    function complete(uint256 amount) external returns (uint256);
    function maxAsk() external view returns (uint256);
    function landing() external view returns (address);
}

interface IVaultS {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function asset() external view returns (address);
}

contract CrownNationSeed {
    address public immutable king;
    ILoanCompleteS public immutable completer;
    IVaultS public immutable vault; // yELE — may be address(0) to disable
    IERC20S public immutable usdc;

    /// @notice BPS of each seed sent to completer (ops → Landing). Rest → yELE vault.
    uint16 public completeBps; // 10000 = 100% to completer
    bool public paused;

    event Seeded(
        address indexed from,
        uint256 total,
        uint256 toCompleter,
        uint256 toVault,
        uint256 landingAfter,
        uint256 vaultShares
    );
    event CompleteBpsSet(uint16 bps);

    error NotKing();
    error Paused();
    error BadBps();
    error Zero();

    modifier onlyKing() {
        if (msg.sender != king) revert NotKing();
        _;
    }

    constructor(address king_, address completer_, address vault_, address usdc_, uint16 completeBps_) {
        require(king_ != address(0) && completer_ != address(0) && usdc_ != address(0), "CFG");
        if (completeBps_ > 10_000) revert BadBps();
        king = king_;
        completer = ILoanCompleteS(completer_);
        vault = IVaultS(vault_);
        usdc = IERC20S(usdc_);
        completeBps = completeBps_;
        if (vault_ != address(0)) {
            require(IVaultS(vault_).asset() == usdc_, "ASSET");
        }
    }

    function maxAsk() external view returns (uint256) {
        return completer.maxAsk();
    }

    function setCompleteBps(uint16 bps) external onlyKing {
        if (bps > 10_000) revert BadBps();
        completeBps = bps;
        emit CompleteBpsSet(bps);
    }

    function setPaused(bool p) external onlyKing {
        paused = p;
    }

    /// @notice Pull USDC from caller → split to ZK completer (Landing) and/or yELE.
    /// @dev Caller approves this contract for `amount` first.
    function seed(uint256 amount) external returns (uint256 landingAfter, uint256 vaultShares) {
        if (paused) revert Paused();
        if (amount == 0) revert Zero();

        require(usdc.transferFrom(msg.sender, address(this), amount), "PULL");

        uint256 toComplete = amount * uint256(completeBps) / 10_000;
        uint256 toVault = amount - toComplete;

        if (toComplete > 0) {
            uint256 maxA = completer.maxAsk();
            require(toComplete <= maxA, "ASK");
            require(usdc.approve(address(completer), toComplete), "APP_C");
            landingAfter = completer.complete(toComplete);
        } else {
            landingAfter = usdc.balanceOf(completer.landing());
        }

        if (toVault > 0) {
            require(address(vault) != address(0), "NO_VAULT");
            require(usdc.approve(address(vault), toVault), "APP_V");
            vaultShares = vault.deposit(toVault, king);
        }

        emit Seeded(msg.sender, amount, toComplete, toVault, landingAfter, vaultShares);
    }

    /// @notice 100% into ZK completer → Landing (ops).
    function seedOps(uint256 amount) external returns (uint256 landingAfter) {
        if (paused) revert Paused();
        if (amount == 0) revert Zero();
        require(amount <= completer.maxAsk(), "ASK");
        require(usdc.transferFrom(msg.sender, address(this), amount), "PULL");
        require(usdc.approve(address(completer), amount), "APP");
        landingAfter = completer.complete(amount);
        emit Seeded(msg.sender, amount, amount, 0, landingAfter, 0);
    }

    /// @notice 100% into yELE under king (curator TVL / fee base).
    function seedVault(uint256 amount) external returns (uint256 shares) {
        if (paused) revert Paused();
        if (amount == 0) revert Zero();
        require(address(vault) != address(0), "NO_VAULT");
        require(usdc.transferFrom(msg.sender, address(this), amount), "PULL");
        require(usdc.approve(address(vault), amount), "APP");
        shares = vault.deposit(amount, king);
        emit Seeded(msg.sender, amount, 0, amount, usdc.balanceOf(completer.landing()), shares);
    }

    function sweep(address token, uint256 amount, address to) external onlyKing {
        require(to != address(0), "TO");
        require(IERC20S(token).transfer(to, amount), "SWEEP");
    }
}
