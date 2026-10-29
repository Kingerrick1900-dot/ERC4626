// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IERC20P {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IEusdP {
    function mint(address to, uint256 amt) external;
    function approve(address, uint256) external returns (bool);
    function isMinter(address) external view returns (bool);
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
    function supply(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory m, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function isAuthorized(address user, address operator) external view returns (bool);
}

interface IMetaMorphoP {
    function totalAssets() external view returns (uint256);
}

/// @notice Path B forge: flash USDC → supply onBehalf yRSS → mint eUSD coll → borrow → repay.
/// @dev HOT must setMinter(this) and Morpho.setAuthorization(this, true) before forge.
contract CrownPathBYrssIdle is Ownable {
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    bytes32 public constant EUSD_MKT = 0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366;

    address public immutable hot;
    uint256 public totalForged;
    uint256 public lastYrssAssets;

    event Forged(uint256 ask, uint256 yrssAssetsAfter, uint256 yrssSupplyShares);

    error NotMorpho();
    error NotMinter();
    error NotAuth();
    error Zero();

    constructor(address hot_) Ownable(hot_) {
        hot = hot_;
    }

    function forge(uint256 ask) external onlyOwner {
        if (ask == 0) revert Zero();
        if (!IEusdP(EUSD).isMinter(address(this))) revert NotMinter();
        if (!IMorphoP(MORPHO).isAuthorized(hot, address(this))) revert NotAuth();
        IMorphoP(MORPHO).flashLoan(USDC, ask, hex"");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != MORPHO) revert NotMorpho();

        (address loan, address coll, address oracle, address irm, uint256 lltv) =
            IMorphoP(MORPHO).idToMarketParams(EUSD_MKT);
        IMorphoP.MarketParams memory mp =
            IMorphoP.MarketParams({loanToken: loan, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv});

        // Park flash USDC as yRSS inventory
        IERC20P(USDC).approve(MORPHO, assets);
        IMorphoP(MORPHO).supply(mp, assets, 0, YRSS, "");

        // Mint eUSD collateral to this contract (2x USDC notional in 18dp)
        uint256 collAmt = assets * 2e12;
        IEusdP(EUSD).mint(address(this), collAmt);
        IEusdP(EUSD).approve(MORPHO, collAmt);
        IMorphoP(MORPHO).supplyCollateral(mp, collAmt, hot, "");
        IMorphoP(MORPHO).borrow(mp, assets, 0, hot, address(this));

        IERC20P(USDC).approve(MORPHO, assets);

        (uint256 shares,,) = IMorphoP(MORPHO).position(EUSD_MKT, YRSS);
        lastYrssAssets = IMetaMorphoP(YRSS).totalAssets();
        totalForged += assets;
        emit Forged(assets, lastYrssAssets, shares);
    }
}
