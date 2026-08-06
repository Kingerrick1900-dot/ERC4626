// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice King 6-step: flash USDC → repay debt → withdraw coll → equity → migrate/borrow → repay flashes.
/// Scoreboard: USDC on Landing only.

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IBalancerV2Vault {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external;
}

contract CrownLiFiSixStep {
    IMorphoL public immutable morpho;
    IBalancerV2Vault public immutable balancer;
    IERC20L public immutable usdc;
    IERC20L public immutable weth;
    IERC20L public immutable rss;
    address public immutable king;
    address public immutable landing;
    bytes32 public immutable rssMarketId;

    IMorphoL.MarketParams public rssUsdc;
    IMorphoL.MarketParams public wethUsdc;

    uint256 public lastLandingCredit;
    string public lastMode;

    uint256 private _usdcFlash;
    uint256 private _wethFlash;
    uint256 private _landingTarget;

    constructor(
        address morpho_,
        address balancer_,
        address usdc_,
        address weth_,
        address rss_,
        address king_,
        address landing_,
        bytes32 rssMarketId_,
        address rssOracle,
        address wethOracle,
        address irm
    ) {
        morpho = IMorphoL(morpho_);
        balancer = IBalancerV2Vault(balancer_);
        usdc = IERC20L(usdc_);
        weth = IERC20L(weth_);
        rss = IERC20L(rss_);
        king = king_;
        landing = landing_;
        rssMarketId = rssMarketId_;
        rssUsdc = IMorphoL.MarketParams(usdc_, rss_, rssOracle, irm, 0.77e18);
        wethUsdc = IMorphoL.MarketParams(usdc_, weth_, wethOracle, irm, 0.86e18);
    }

    /// @notice Full 6-step with Balancer WETH flash (King vault addr).
    function runSixStepBalancer(uint256 usdcFlashAmt, uint256 wethFlashAmt, uint256 landingUsdc) external {
        require(msg.sender == king, "KING");
        _usdcFlash = usdcFlashAmt;
        _wethFlash = wethFlashAmt;
        _landingTarget = landingUsdc;
        morpho.flashLoan(address(usdc), usdcFlashAmt, abi.encode(uint8(1)));
    }

    /// @notice Full 6-step with Morpho WETH flash (deeper WETH on Base).
    function runSixStepMorpho(uint256 usdcFlashAmt, uint256 wethFlashAmt, uint256 landingUsdc) external {
        require(msg.sender == king, "KING");
        _usdcFlash = usdcFlashAmt;
        _wethFlash = wethFlashAmt;
        _landingTarget = landingUsdc;
        morpho.flashLoan(address(usdc), usdcFlashAmt, abi.encode(uint8(10)));
    }

    /// @notice Flash USDC → repay → withdraw supply → credit any residual to Landing.
    function runSupplyExtract(uint256 usdcFlashAmt) external {
        require(msg.sender == king, "KING");
        _usdcFlash = usdcFlashAmt;
        morpho.flashLoan(address(usdc), usdcFlashAmt, abi.encode(uint8(20)));
    }

    /// @notice Flash USDC → repay → withdraw RSS → add free RSS → resupply → borrow flash+Landing.
    function runRssReborrow(uint256 usdcFlashAmt, uint256 extraRssFromHot, uint256 landingUsdc) external {
        require(msg.sender == king, "KING");
        _usdcFlash = usdcFlashAmt;
        _landingTarget = landingUsdc;
        if (extraRssFromHot > 0) {
            require(rss.transferFrom(king, address(this), extraRssFromHot), "RSS");
        }
        morpho.flashLoan(address(usdc), usdcFlashAmt, abi.encode(uint8(30)));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        uint8 mode = abi.decode(data, (uint8));

        if (mode == 1) {
            _repayWithdrawRss(assets);
            address[] memory tokens = new address[](1);
            tokens[0] = address(weth);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = _wethFlash;
            balancer.flashLoan(address(this), tokens, amounts, abi.encode(uint8(2)));
            usdc.approve(address(morpho), assets);
            lastMode = "SIX_BALANCER";
        } else if (mode == 10) {
            _repayWithdrawRss(assets);
            morpho.flashLoan(address(weth), _wethFlash, abi.encode(uint8(11)));
            usdc.approve(address(morpho), assets);
            lastMode = "SIX_MORPHO";
        } else if (mode == 11) {
            _wethSupplyBorrow(assets);
            weth.approve(address(morpho), assets);
        } else if (mode == 20) {
            usdc.approve(address(morpho), assets);
            morpho.repay(rssUsdc, assets, 0, king, "");
            morpho.withdraw(rssUsdc, assets, 0, king, address(this));
            uint256 bal = usdc.balanceOf(address(this));
            uint256 credit = bal > assets ? bal - assets : 0;
            if (credit > 0) require(usdc.transfer(landing, credit), "PUSH");
            lastLandingCredit = credit;
            usdc.approve(address(morpho), assets);
            lastMode = "SUPPLY_EXTRACT";
        } else if (mode == 30) {
            usdc.approve(address(morpho), assets);
            morpho.repay(rssUsdc, assets, 0, king, "");
            (, , uint128 coll) = morpho.position(rssMarketId, king);
            if (coll > 0) morpho.withdrawCollateral(rssUsdc, uint256(coll), king, address(this));
            uint256 rssBal = rss.balanceOf(address(this));
            rss.approve(address(morpho), rssBal);
            morpho.supplyCollateral(rssUsdc, rssBal, address(this), "");
            uint256 borrowAmt = assets + _landingTarget;
            morpho.borrow(rssUsdc, borrowAmt, 0, address(this), address(this));
            if (_landingTarget > 0) {
                require(usdc.transfer(landing, _landingTarget), "PUSH");
                lastLandingCredit = _landingTarget;
            }
            usdc.approve(address(morpho), assets);
            lastMode = "RSS_REBORROW";
        } else {
            revert("MODE");
        }
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(msg.sender == address(balancer), "BAL");
        require(abi.decode(userData, (uint8)) == 2, "M");
        _wethSupplyBorrow(amounts[0]);
        require(weth.transfer(address(balancer), amounts[0] + feeAmounts[0]), "REPAY_WETH");
    }

    function _repayWithdrawRss(uint256 usdcAmt) internal {
        usdc.approve(address(morpho), usdcAmt);
        morpho.repay(rssUsdc, usdcAmt, 0, king, "");
        (, , uint128 coll) = morpho.position(rssMarketId, king);
        if (coll > 0) morpho.withdrawCollateral(rssUsdc, uint256(coll), king, address(this));
    }

    function _wethSupplyBorrow(uint256 wethAmt) internal {
        weth.approve(address(morpho), wethAmt);
        morpho.supplyCollateral(wethUsdc, wethAmt, address(this), "");
        uint256 borrowAmt = _usdcFlash + _landingTarget;
        morpho.borrow(wethUsdc, borrowAmt, 0, address(this), address(this));
        if (_landingTarget > 0) {
            require(usdc.transfer(landing, _landingTarget), "PUSH");
            lastLandingCredit = _landingTarget;
        }
        // WETH must still be returned to flash source — without equity this reverts upstream.
    }
}
