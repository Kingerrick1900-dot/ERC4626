// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    function supply(MarketParams calldata, uint256, uint256, address, bytes calldata) external returns (uint256, uint256);
    function withdraw(MarketParams calldata, uint256, uint256, address, address) external returns (uint256, uint256);
    function supplyCollateral(MarketParams calldata, uint256, address, bytes calldata) external;
    function borrow(MarketParams calldata, uint256, uint256, address, address) external returns (uint256, uint256);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IVaultV2 {
    function deposit(uint256, address) external returns (uint256);
    function redeem(uint256, address, address) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract CrownIdleLand {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IVaultV2 public immutable vault;
    address public immutable landing;
    address public immutable king;
    address public immutable loanToken;
    address public immutable collToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;
    bytes32 public immutable marketId;

    uint256 public lastAsk;
    uint256 public lastLandingCredit;
    uint256 public lastRssColl;
    bool public lastClosed;

    error NotKing();
    error NotMorpho();
    error LandingMiss(uint256, uint256);
    error RepayShort(uint256, uint256);
    error SharesMiss();
    error Stage(uint8);

    event IdleLand(uint256 ask, uint256 rssColl, uint256 landingCredit, bool closed);

    constructor(
        address morpho_, address usdc_, address rss_, address vault_, address landing_, address king_,
        address loanToken_, address collToken_, address oracle_, address irm_, uint256 lltv_, bytes32 marketId_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        vault = IVaultV2(vault_);
        landing = landing_;
        king = king_;
        loanToken = loanToken_;
        collToken = collToken_;
        oracle = oracle_;
        irm = irm_;
        lltv = lltv_;
        marketId = marketId_;
    }

    function fire(uint256 ask, uint256 rssColl) external {
        if (msg.sender != king) revert NotKing();
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

        IMorpho.MarketParams memory p =
            IMorpho.MarketParams(loanToken, collToken, oracle, irm, lltv);

        // S1 seed
        usdc.approve(address(morpho), ask);
        morpho.supply(p, ask, 0, address(this), "");
        // S2 coll
        rss.approve(address(morpho), lastRssColl);
        morpho.supplyCollateral(p, lastRssColl, address(this), "");
        // S3 borrow
        morpho.borrow(p, ask, 0, address(this), address(this));
        // S4 deposit idle
        usdc.approve(address(vault), ask);
        vault.deposit(ask, address(this));
        uint256 vShares = vault.balanceOf(address(this));
        if (vShares == 0) revert SharesMiss();
        // S5 redeem — assets may be 1 wei under ask from rounding; accept convertToAssets
        uint256 out = vault.redeem(vShares, landing, address(this));
        uint256 landAfter = usdc.balanceOf(landing);
        uint256 credited;
        unchecked {
            credited = landAfter - landBefore;
        }
        // accept 1-unit rounding shortfall on credited vs ask
        if (credited + 1 < ask && out + 1 < ask) revert LandingMiss(ask, credited);
        lastLandingCredit = credited;

        // S6 repay via supply shares
        (uint256 supplyShares,,) = morpho.position(marketId, address(this));
        morpho.withdraw(p, 0, supplyShares, address(this), address(this));
        uint256 have = usdc.balanceOf(address(this));
        // Morpho share round-down can leave 1 wei short — top not possible; require have >= ask-1 then pull remainder fails flash
        // So withdraw assets=ask with shares=0 if have enough shares; else shares path and require have >= ask
        if (have < ask) {
            // try assets withdraw for exact ask (mulDivUp shares)
            morpho.withdraw(p, ask - have, 0, address(this), address(this));
            have = usdc.balanceOf(address(this));
        }
        if (have < ask) revert RepayShort(ask, have);
        usdc.approve(address(morpho), ask);

        lastAsk = ask;
        lastClosed = true;
        emit IdleLand(ask, lastRssColl, credited, true);
    }
}
