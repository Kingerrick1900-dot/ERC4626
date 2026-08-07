// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Chunked self-del. flash chunk → repay → withdraw supply → free RSS. Then FREEZE.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
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
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

contract CrownSelfDelChunk {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    address public immutable king;
    bytes32 public immutable marketId;
    address public immutable loanToken;
    address public immutable collToken;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltv;

    uint256 public totalRepaid;
    uint256 public totalRssFreed;
    bool private _lock;

    error NotKing();
    error NotMorpho();
    error Short();

    event Chunk(uint256 repaid, uint256 pulled);
    event Freed(uint256 rssFreed, uint256 debtLeft, uint256 collLeft);

    constructor(
        address morpho_,
        address usdc_,
        address king_,
        bytes32 marketId_,
        address loanToken_,
        address collToken_,
        address oracle_,
        address irm_,
        uint256 lltv_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        king = king_;
        marketId = marketId_;
        loanToken = loanToken_;
        collToken = collToken_;
        oracle = oracle_;
        irm = irm_;
        lltv = lltv_;
    }

    function _mp() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams(loanToken, collToken, oracle, irm, lltv);
    }

    /// @dev One chunk: flash `amt` USDC, repay, pull supply to cover flash.
    function chunk(uint256 amt) external {
        if (msg.sender != king) revert NotKing();
        require(amt > 0, "0");
        uint256 cash = usdc.balanceOf(address(morpho));
        require(amt + 1_000e6 <= cash, "CASH");
        _lock = true;
        morpho.flashLoan(address(usdc), amt, abi.encode(amt));
        _lock = false;
    }

    /// @dev After debt dusted: withdraw excess RSS to king.
    function freeCollateral() external {
        if (msg.sender != king) revert NotKing();
        IMorpho.MarketParams memory p = _mp();
        morpho.accrueInterest(p);
        (, uint128 bor, uint128 coll) = morpho.position(marketId, king);
        uint256 keep;
        uint256 debtLeft;
        if (bor > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            debtLeft = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
            keep = (debtLeft * 1e18) / lltv;
            keep = keep + keep / 10 + 400 ether;
        }
        uint256 freed;
        if (coll > keep) {
            freed = uint256(coll) - keep;
            morpho.withdrawCollateral(p, freed, king, king);
        }
        totalRssFreed += freed;
        emit Freed(freed, debtLeft, keep > coll ? coll : keep);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert NotMorpho();
        if (!_lock) revert NotMorpho();
        uint256 amt = abi.decode(data, (uint256));
        require(assets == amt, "FLASH");

        IMorpho.MarketParams memory p = _mp();
        usdc.approve(address(morpho), type(uint256).max);

        morpho.accrueInterest(p);
        (, uint128 bor,) = morpho.position(marketId, king);
        uint256 repaid;
        if (bor > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
            uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
            repaid = amt < debt ? amt : debt;
            if (repaid > 0) morpho.repay(p, repaid, 0, king, "");
            totalRepaid += repaid;
        }

        // Pull enough supply to repay flash (assets mode)
        uint256 need = assets;
        uint256 have = usdc.balanceOf(address(this));
        if (have < need) {
            uint256 pull = need - have;
            (uint256 pulled,) = morpho.withdraw(p, pull, 0, king, address(this));
            pulled;
        }
        have = usdc.balanceOf(address(this));
        if (have < assets) revert Short();
        usdc.approve(address(morpho), assets);
        emit Chunk(repaid, have);
    }
}
