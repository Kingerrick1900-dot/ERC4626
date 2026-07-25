// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Permissionless millions rail: filler pays USDC ask → TEN debt cleared →
///         king Morpho supply spoil withdrawn to king → listed ELE to filler.
/// @dev Bypasses "USDC already on hot". One atomic fill unlocks the TEN ~$700k spoil.
interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoF {
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
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

contract CrownSpoilsFill {
    address public immutable king;
    address public immutable oracle;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_915 = 915000000000000000;

    uint256 public eleListed;
    uint256 public usdcAsk;
    bool public pullTenColl;

    error NotKing();
    error Empty();
    error Busy();
    error NotAuth();
    error AskShort();
    error NoDebt();

    event Listed(uint256 eleAmount, uint256 usdcAsk_, bool pullTenColl_);
    event Cancelled(uint256 eleReturned);
    event Filled(address indexed filler, uint256 usdcPaid, uint256 spoilToKing, uint256 eleToFiller);

    constructor(address king_, address oracle_) {
        king = king_;
        oracle = oracle_;
    }

    function _mp() internal view returns (IMorphoF.MarketParams memory) {
        return IMorphoF.MarketParams(USDC, ELE, oracle, IRM, LLTV_915);
    }

    function marketId() public view returns (bytes32) {
        return keccak256(abi.encode(_mp()));
    }

    function debt() public view returns (uint256) {
        (, uint128 borShares,) = IMorphoF(MORPHO).position(marketId(), king);
        if (borShares == 0) return 0;
        (,, uint128 ba, uint128 bs,,) = IMorphoF(MORPHO).market(marketId());
        if (bs == 0) return 0;
        return (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
    }

    /// @notice King arms the rail. Escrows ELE. `usdcAsk_` must be ≥ TEN debt at fill time.
    function list(uint256 eleAmount, uint256 usdcAsk_, bool pullTenColl_) external {
        if (msg.sender != king) revert NotKing();
        if (eleAmount == 0 || usdcAsk_ == 0) revert Empty();
        if (eleListed != 0) revert Busy();
        require(IERC20F(ELE).transferFrom(king, address(this), eleAmount), "ELE");
        eleListed = eleAmount;
        usdcAsk = usdcAsk_;
        pullTenColl = pullTenColl_;
        emit Listed(eleAmount, usdcAsk_, pullTenColl_);
    }

    function cancel() external {
        if (msg.sender != king) revert NotKing();
        uint256 ele = eleListed;
        eleListed = 0;
        usdcAsk = 0;
        pullTenColl = false;
        if (ele > 0) require(IERC20F(ELE).transfer(king, ele), "RET");
        emit Cancelled(ele);
    }

    /// @notice Anyone pays exact `usdcAsk`: unlocks king TEN spoil to king, takes escrowed ELE.
    function fill() external {
        uint256 listed = eleListed;
        uint256 ask = usdcAsk;
        bool pullColl = pullTenColl;
        if (listed == 0 || ask == 0) revert Empty();
        if (!IMorphoF(MORPHO).isAuthorized(king, address(this))) revert NotAuth();

        IMorphoF.MarketParams memory mp = _mp();
        IMorphoF(MORPHO).accrueInterest(mp);
        bytes32 id = marketId();

        (, uint128 borShares,) = IMorphoF(MORPHO).position(id, king);
        if (borShares == 0) revert NoDebt();
        (,, uint128 ba, uint128 bs,,) = IMorphoF(MORPHO).market(id);
        uint256 d = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        if (ask < d) revert AskShort();

        eleListed = 0;
        usdcAsk = 0;
        pullTenColl = false;

        require(IERC20F(USDC).transferFrom(msg.sender, address(this), ask), "USDC");
        IERC20F(USDC).approve(MORPHO, d);
        IMorphoF(MORPHO).repay(mp, 0, borShares, king, "");

        (uint256 supShares,, uint128 coll) = IMorphoF(MORPHO).position(id, king);
        uint256 spoil;
        if (supShares > 0) {
            (spoil,) = IMorphoF(MORPHO).withdraw(mp, 0, supShares, king, king);
        }

        uint256 left = IERC20F(USDC).balanceOf(address(this));
        if (left > 0) require(IERC20F(USDC).transfer(king, left), "DUST");

        uint256 eleOut = listed;
        if (pullColl && coll > 0) {
            IMorphoF(MORPHO).withdrawCollateral(mp, uint256(coll), king, msg.sender);
            eleOut += uint256(coll);
        }

        require(IERC20F(ELE).transfer(msg.sender, listed), "ELE_OUT");
        emit Filled(msg.sender, ask, spoil + left, eleOut);
    }
}
