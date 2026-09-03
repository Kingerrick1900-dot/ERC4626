// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";

interface IMorphoIdle {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

/// @title CrownPrimeIdleTap
/// @notice Borrows live Morpho USDC idle against eUSD (or other coll) and supplies CrownPrimeCredit.
/// @dev Does NOT flash. Only pulls unmatched USDC already sitting in a Morpho book.
contract CrownPrimeIdleTap is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoIdle public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    CrownPrimeCredit public immutable credit;
    address public immutable king;

    IMorphoIdle.MarketParams public eusdMp;
    bytes32 public eusdMarketId;

    event MarketSet(bytes32 indexed id, address oracle, uint256 lltv);
    event CollPosted(uint256 eusdAmt);
    event Tapped(bytes32 indexed marketId, uint256 usdcAmt, uint256 creditIdle);

    error KingOnly();
    error BadAmt();
    error NoIdle();

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address credit_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoIdle(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        credit = CrownPrimeCredit(credit_);
        king = king_;
        usdc.safeApprove(credit_, type(uint256).max);
        eusd.safeApprove(morpho_, type(uint256).max);
    }

    function setEusdMarket(address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        eusdMp = IMorphoIdle.MarketParams({
            loanToken: address(usdc),
            collateralToken: address(eusd),
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        eusdMarketId = id;
        emit MarketSet(id, oracle, lltv);
    }

    function idleOf(bytes32 id) public view returns (uint256) {
        (uint128 supply,, uint128 borrow,,,) = morpho.market(id);
        return uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
    }

    /// @notice King posts eUSD as Morpho coll so later taps can borrow USDC.
    function postEusd(uint256 amt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (amt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        morpho.supplyCollateral(eusdMp, amt, king, "");
        emit CollPosted(amt);
    }

    /// @notice Pull unmatched USDC from the eUSD/USDC book into credit. Stays there (no flash repay).
    function tapEusd(uint256 amt) external nonReentrant returns (uint256) {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        return _tap(eusdMp, eusdMarketId, amt);
    }

    /// @notice Pull unmatched USDC from any Morpho USDC book king is authorized to borrow on.
    function tapMarket(IMorphoIdle.MarketParams calldata mp, bytes32 id, uint256 amt)
        external
        nonReentrant
        returns (uint256)
    {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        require(mp.loanToken == address(usdc), "LOAN");
        return _tap(mp, id, amt);
    }

    function _tap(IMorphoIdle.MarketParams memory mp, bytes32 id, uint256 amt) internal returns (uint256 pulled) {
        uint256 idle = idleOf(id);
        if (idle == 0) revert NoIdle();
        pulled = amt == 0 || amt > idle ? idle : amt;
        morpho.borrow(mp, pulled, 0, king, address(this));
        credit.supply(pulled);
        emit Tapped(id, pulled, credit.freeUsdc());
    }
}
