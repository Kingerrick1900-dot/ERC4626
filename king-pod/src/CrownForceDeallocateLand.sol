// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownForceDeallocateLand
/// @notice Closes with flash = 1× ASK (no double-supply shortfall):
///   seed Morpho ASK → RSS-borrow ASK → vault deposit (adapter supplies Morpho)
///   → forceDeallocate → withdraw Landing → withdraw Morpho seed → repay flash.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams calldata, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdraw(
        MarketParams calldata,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
    function supplyCollateral(MarketParams calldata, uint256 assets, address onBehalf, bytes calldata data)
        external;
    function borrow(
        MarketParams calldata,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IVaultV2 {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function forceDeallocate(address adapter, bytes calldata data, uint256 assets, address onBehalf)
        external
        returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function forceDeallocatePenalty(address) external view returns (uint256);
}

contract CrownForceDeallocateLand {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IVaultV2 public immutable vault;
    address public immutable adapter;
    address public immutable landing;
    address public immutable king;

    address public immutable loanToken;
    address public immutable collToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;

    uint256 public lastAsk;
    uint256 public lastLandingCredit;
    uint256 public lastRssColl;
    bool public lastClosed;

    error NotKing();
    error NotMorpho();
    error PenaltyNotZero();
    error LandingMiss(uint256 want, uint256 got);
    error RepayShort(uint256 need, uint256 have);
    error SharesMiss();

    event ForceDeallocLand(uint256 ask, uint256 rssColl, uint256 landingCredit, bool closed);

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address vault_,
        address adapter_,
        address landing_,
        address king_,
        address loanToken_,
        address collToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        vault = IVaultV2(vault_);
        adapter = adapter_;
        landing = landing_;
        king = king_;
        loanToken = loanToken_;
        collToken = collToken_;
        oracle = oracle_;
        irm = irm_;
        lltv = lltv_;
    }

    function _params() internal view returns (IMorpho.MarketParams memory p) {
        p.loanToken = loanToken;
        p.collateralToken = collToken;
        p.oracle = oracle;
        p.irm = irm;
        p.lltv = lltv;
    }

    /// @dev Flash size = ASK (one ask). No second raw Morpho supply.
    function fire(uint256 ask, uint256 rssColl) external {
        if (msg.sender != king) revert NotKing();
        if (vault.forceDeallocatePenalty(adapter) != 0) revert PenaltyNotZero();
        require(ask > 0 && rssColl > 0, "ZERO");
        require(rss.transferFrom(king, address(this), rssColl), "RSS");
        lastAsk = ask;
        lastRssColl = rssColl;
        morpho.flashLoan(address(usdc), ask, abi.encode(ask, usdc.balanceOf(landing)));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert NotMorpho();
        (uint256 ask, uint256 landBefore) = abi.decode(data, (uint256, uint256));
        require(assets == ask, "FLASH");

        IMorpho.MarketParams memory p = _params();

        // 1) Seed Morpho with one ASK
        usdc.approve(address(morpho), ask);
        morpho.supply(p, ask, 0, address(this), "");

        // 2) Borrow ASK against free RSS, deposit → vault (adapter supplies Morpho)
        rss.approve(address(morpho), lastRssColl);
        morpho.supplyCollateral(p, lastRssColl, address(this), "");
        morpho.borrow(p, ask, 0, address(this), address(this));
        usdc.approve(address(vault), ask);
        vault.deposit(ask, address(this));
        if (vault.balanceOf(address(this)) == 0) revert SharesMiss();

        // 3) Classic: forceDeallocate → withdraw Landing (no second raw supply)
        vault.forceDeallocate(adapter, abi.encode(p), ask, address(this));
        vault.withdraw(ask, landing, address(this));

        uint256 credited = usdc.balanceOf(landing) - landBefore;
        lastLandingCredit = credited;
        if (credited < ask) revert LandingMiss(ask, credited);

        // 4) Repay flash from Morpho seed
        morpho.withdraw(p, ask, 0, address(this), address(this));
        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) revert RepayShort(assets, have);
        usdc.approve(address(morpho), assets);

        lastClosed = true;
        emit ForceDeallocLand(ask, lastRssColl, credited, true);
    }
}
