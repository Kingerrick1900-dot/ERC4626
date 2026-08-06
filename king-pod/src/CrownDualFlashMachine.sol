// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Dual-flash machine (LI.FI-style). Both flashes from Morpho (Balancer V2 vault absent on Base).

interface IERC20D {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IWETHD {
    function deposit() external payable;
    function approve(address, uint256) external returns (bool);
}

interface IMorphoD {
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
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
}

contract CrownDualFlashMachine {
    IMorphoD public immutable morpho;
    IERC20D public immutable usdc;
    IERC20D public immutable weth;
    IERC20D public immutable rss;
    address public immutable king;
    address public immutable landing;

    IMorphoD.MarketParams public rssUsdc;
    IMorphoD.MarketParams public wethUsdc;

    uint256 public lastLandingCredit;
    string public lastMode;

    uint8 public constant MODE_CREATE_IDLE_REPAY = 1;
    uint8 public constant MODE_UNWIND = 2;
    uint8 public constant MODE_WETH_FLASH_LANDING = 3;

    constructor(
        address morpho_,
        address usdc_,
        address weth_,
        address rss_,
        address king_,
        address landing_,
        address rssOracle,
        address wethOracle,
        address irm
    ) {
        morpho = IMorphoD(morpho_);
        usdc = IERC20D(usdc_);
        weth = IERC20D(weth_);
        rss = IERC20D(rss_);
        king = king_;
        landing = landing_;
        rssUsdc = IMorphoD.MarketParams(usdc_, rss_, rssOracle, irm, 0.77e18);
        wethUsdc = IMorphoD.MarketParams(usdc_, weth_, wethOracle, irm, 0.86e18);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint8 mode, uint256 aux) = abi.decode(data, (uint8, uint256));

        if (mode == MODE_CREATE_IDLE_REPAY) {
            usdc.approve(address(morpho), assets);
            morpho.supply(rssUsdc, assets, 0, address(this), "");
            morpho.borrow(rssUsdc, assets, 0, address(this), address(this));
            usdc.approve(address(morpho), assets);
            lastLandingCredit = 0;
            lastMode = "CREATE_IDLE_REPAY";
        } else if (mode == MODE_UNWIND) {
            usdc.approve(address(morpho), assets);
            morpho.repay(rssUsdc, assets, 0, king, "");
            morpho.withdraw(rssUsdc, assets, 0, king, address(this));
            uint256 bal = usdc.balanceOf(address(this));
            usdc.approve(address(morpho), assets);
            if (bal > assets) {
                uint256 credit = bal - assets;
                require(usdc.transfer(landing, credit), "PUSH");
                lastLandingCredit = credit;
            } else {
                lastLandingCredit = 0;
            }
            lastMode = "UNWIND";
        } else if (mode == MODE_WETH_FLASH_LANDING) {
            weth.approve(address(morpho), assets);
            morpho.supplyCollateral(wethUsdc, assets, address(this), "");
            morpho.borrow(wethUsdc, aux, 0, address(this), landing);
            lastLandingCredit = aux;
            lastMode = "WETH_FLASH_LANDING";
            weth.approve(address(morpho), assets);
        } else {
            revert("MODE");
        }
    }

    function runUsdcFlash(uint8 mode, uint256 amount) external {
        require(msg.sender == king, "KING");
        morpho.flashLoan(address(usdc), amount, abi.encode(mode, uint256(0)));
    }

    function runWethFlash(uint8 mode, uint256 wethAmount, uint256 usdcOut) external {
        require(msg.sender == king, "KING");
        morpho.flashLoan(address(weth), wethAmount, abi.encode(mode, usdcOut));
    }

    function equityWethBorrow(uint256 wethIn, uint256 usdcOut) external {
        require(msg.sender == king, "KING");
        require(weth.transferFrom(msg.sender, address(this), wethIn), "PULL");
        weth.approve(address(morpho), wethIn);
        morpho.supplyCollateral(wethUsdc, wethIn, address(this), "");
        morpho.borrow(wethUsdc, usdcOut, 0, address(this), landing);
        lastLandingCredit = usdcOut;
        lastMode = "EQUITY_WETH";
    }

    /// @notice Base MorphoWethLoanProtectionPolicy shape: wrap native ETH → WETH → Morpho coll → USDC to Landing.
    /// @dev LI.FI equity path C. Caller sends ETH as msg.value (no WETH balance required upfront).
    function equityEthBorrow(uint256 usdcOut) external payable {
        require(msg.sender == king, "KING");
        uint256 ethIn = msg.value;
        require(ethIn > 0, "NO_ETH");
        IWETHD(address(weth)).deposit{value: ethIn}();
        weth.approve(address(morpho), ethIn);
        morpho.supplyCollateral(wethUsdc, ethIn, address(this), "");
        morpho.borrow(wethUsdc, usdcOut, 0, address(this), landing);
        lastLandingCredit = usdcOut;
        lastMode = "EQUITY_ETH_WRAP";
    }

    receive() external payable {}
}
