// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoK {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;

    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IOracleK {
    function price() external view returns (uint256);
}

/// @notice Morpho-native KEEP: USDC blue-supply + ELE coll post → borrow → Landing.
/// @dev No yELE. No recycle. King authorizes this contract on Morpho once.
contract CrownElepanKeepDraw is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoK public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable elepan;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoK.MarketParams public marketParams;
    uint256 public immutable lltv;

    event KeepDrawn(uint256 suppliedUsdc, uint256 postedEle, uint256 borrowedUsdc, uint256 landingBal);

    constructor(
        address morpho_,
        address usdc_,
        address elepan_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoK(morpho_);
        usdc = IERC20(usdc_);
        elepan = IERC20(elepan_);
        king = king_;
        landing = landing_;
        marketId = marketId_;
        lltv = lltv_;
        marketParams = IMorphoK.MarketParams({
            loanToken: usdc_,
            collateralToken: elepan_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /// @notice Pull USDC/ELE from King, open idle, borrow max room to Landing KEEP.
    function drawKeep(uint256 supplyUsdc, uint256 postEle, uint256 borrowUsdc) external onlyOwner nonReentrant {
        require(morpho.isAuthorized(king, address(this)), "AUTH");

        if (supplyUsdc > 0) {
            usdc.safeTransferFrom(king, address(this), supplyUsdc);
            usdc.safeApprove(address(morpho), 0);
            usdc.safeApprove(address(morpho), supplyUsdc);
            morpho.supply(marketParams, supplyUsdc, 0, king, "");
        }

        if (postEle > 0) {
            elepan.safeTransferFrom(king, address(this), postEle);
            elepan.safeApprove(address(morpho), 0);
            elepan.safeApprove(address(morpho), postEle);
            morpho.supplyCollateral(marketParams, postEle, king, "");
        }

        (uint128 supplyAssets,, uint128 borrowAssets,,,) = morpho.market(marketId);
        uint256 idle = uint256(supplyAssets) - uint256(borrowAssets);
        require(idle > 0, "NO_IDLE");

        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        uint256 price = IOracleK(marketParams.oracle).price();
        uint256 collValue = (uint256(coll) * price) / 1e36;
        uint256 maxByLltv = (collValue * lltv) / 1e18;
        uint256 debt;
        if (borShares > 0 && borrowAssets > 0) {
            (,, uint128 ba, uint128 bs,,) = morpho.market(marketId);
            debt = (uint256(ba) * uint256(borShares) + uint256(bs) - 1) / uint256(bs);
        }
        uint256 room = maxByLltv > debt ? maxByLltv - debt : 0;
        require(room > 0, "NO_ROOM");

        uint256 amt = borrowUsdc == 0 ? type(uint256).max : borrowUsdc;
        if (amt > idle) amt = idle;
        if (amt > room) amt = room;
        require(amt > 0, "ZERO");

        uint256 before = usdc.balanceOf(landing);
        morpho.borrow(marketParams, amt, 0, king, landing);
        uint256 afterBal = usdc.balanceOf(landing);
        require(afterBal >= before + amt, "LANDING_MISS");
        emit KeepDrawn(supplyUsdc, postEle, amt, afterBal);
    }
}
