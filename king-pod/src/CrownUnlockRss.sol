// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoX {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
}

/// @notice One-tx unlock: repay dust + free all RSS coll back to king.
contract CrownUnlockRss {
    address public immutable king;
    IMorphoX public immutable morpho;
    address public immutable usdc;
    address public immutable rss;
    bytes32 public immutable mid77;
    bytes32 public immutable mid91;

    constructor(address morpho_, address usdc_, address rss_, address king_, bytes32 m77, bytes32 m91) {
        morpho = IMorphoX(morpho_);
        usdc = usdc_;
        rss = rss_;
        king = king_;
        mid77 = m77;
        mid91 = m91;
    }

    function unlock() external {
        require(msg.sender == king, "KING");
        _one(mid77);
        _one(mid91);
        uint256 dust = IERC20X(usdc).balanceOf(address(this));
        if (dust > 0) IERC20X(usdc).transfer(king, dust);
        uint256 r = IERC20X(rss).balanceOf(address(this));
        if (r > 0) IERC20X(rss).transfer(king, r);
    }

    function _one(bytes32 mid) internal {
        IMorphoX.MarketParams memory mp = morpho.idToMarketParams(mid);
        morpho.accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = morpho.position(mid, king);
        if (borShares > 0) {
            (,, uint128 bA, uint128 bS,,) = morpho.market(mid);
            uint256 debt = (uint256(borShares) * uint256(bA) + uint256(bS) - 1) / uint256(bS) + 10;
            require(IERC20X(usdc).transferFrom(king, address(this), debt), "USDC");
            IERC20X(usdc).approve(address(morpho), debt);
            morpho.repay(mp, 0, uint256(borShares), king, "");
        }
        (, , uint128 collLeft) = morpho.position(mid, king);
        if (collLeft > 0) {
            morpho.withdrawCollateral(mp, uint256(collLeft), king, king);
        }
    }
}
