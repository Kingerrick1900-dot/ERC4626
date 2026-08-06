// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Peapods-style atomic self-lend seed on Morpho (King order: engineer the numbers).
/// Flash USDC → supply → borrow same amount against existing RSS coll → repay flash.
/// Result: matched book grows, 100% util preserved, no external supplier.
/// Mirror: Peapods LVF / Venus enterSingleAssetLeverage ( Morpho edition ).

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoP {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

contract CrownPeapodsMorphoSeed {
    IMorphoP public immutable morpho;
    IERC20P public immutable usdc;
    address public immutable king;
    bytes32 public immutable marketId;
    IMorphoP.MarketParams public mp;

    uint256 public lastSeed;
    uint256 public lastSupply;
    uint256 public lastBorrow;

    constructor(address morpho_, address usdc_, address king_, bytes32 marketId_) {
        morpho = IMorphoP(morpho_);
        usdc = IERC20P(usdc_);
        king = king_;
        marketId = marketId_;
        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoP(morpho_).idToMarketParams(marketId_);
        mp = IMorphoP.MarketParams(loan, coll, oracle, irm, lltv);
    }

    /// @notice Engineer +`assets` matched USDC on the RSS/$1200 book (Peapods self-lend).
    function seed(uint256 assets) external {
        require(msg.sender == king, "KING");
        require(assets > 0, "AMT");
        morpho.flashLoan(address(usdc), assets, abi.encode(assets));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(morpho), "MORPHO");
        usdc.approve(address(morpho), assets);
        // Supply flashed USDC into market on behalf of king (seed liquidity)
        morpho.supply(mp, assets, 0, king, "");
        // Borrow same USDC against king's existing RSS coll → repay flash (100% util seed)
        morpho.borrow(mp, assets, 0, king, address(this));
        lastSeed = assets;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        lastSupply = s;
        lastBorrow = b;
        usdc.approve(address(morpho), assets);
    }
}
