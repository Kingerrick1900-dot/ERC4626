// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMorphoDepth {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IOracleDepth {
    function price() external view returns (uint256);
}

/// @notice On-chain depth scribe: RSS/eUSD AMO + legacy RSS/USDC book snapshot.
contract CrownDepthAttest {
    uint256 internal constant ORACLE_SCALE = 1e36;

    IMorphoDepth public immutable morpho;
    bytes32 public immutable eusdMarketId;
    bytes32 public immutable usdcMarketId;
    address public immutable king;

    struct Snapshot {
        uint256 eusdIdle;
        uint256 eusdSupply;
        uint256 eusdBorrow;
        uint256 usdcSupply;
        uint256 usdcBorrow;
        uint256 usdcIdle;
        uint256 kingUsdcDebt;
        uint256 kingRssCollUsdc;
        uint256 kingEusdDebt;
        uint256 kingRssCollEusd;
        uint256 blockNumber;
    }

    Snapshot public latest;

    event Snap(uint256 blockNumber, uint256 eusdIdle, uint256 usdcIdle);

    constructor(address morpho_, bytes32 eusdMarketId_, bytes32 usdcMarketId_, address king_) {
        morpho = IMorphoDepth(morpho_);
        eusdMarketId = eusdMarketId_;
        usdcMarketId = usdcMarketId_;
        king = king_;
    }

    function snap() external returns (Snapshot memory s) {
        (uint128 es,, uint128 eb,,,) = morpho.market(eusdMarketId);
        (uint128 us,, uint128 ub,,,) = morpho.market(usdcMarketId);
        s.eusdSupply = es;
        s.eusdBorrow = eb;
        s.eusdIdle = es > eb ? es - eb : 0;
        s.usdcSupply = us;
        s.usdcBorrow = ub;
        s.usdcIdle = us > ub ? us - ub : 0;
        (, uint128 uBor, uint128 uColl) = morpho.position(usdcMarketId, king);
        (, uint128 eBor, uint128 eColl) = morpho.position(eusdMarketId, king);
        s.kingUsdcDebt = uBor;
        s.kingRssCollUsdc = uColl;
        s.kingEusdDebt = eBor;
        s.kingRssCollEusd = eColl;
        s.blockNumber = block.number;
        latest = s;
        emit Snap(s.blockNumber, s.eusdIdle, s.usdcIdle);
    }
}
