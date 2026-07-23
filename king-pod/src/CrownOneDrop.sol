// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, ReentrancyGuard} from "./lib/Core.sol";

interface ICrownCdp {
    function deposit(uint256 collAmt) external;
    function mint(uint256 mintAmt) external;
    function open(uint256 collAmt, uint256 mintAmt) external;
    function collOf(address) external view returns (uint256);
    function debtOf(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
}

interface IAeroRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
}

interface IMorphoOD {
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
}

/// @notice One-drop: RSS -> CDP mint kUSD -> Aero swap USDC -> Landing + proof event.
/// @dev Morpho-integrated optional post for book presence. Primary mint is Crown CDP (live).
contract CrownOneDrop is ReentrancyGuard {
    using SafeTransfer for IERC20;

    address public immutable morpho;
    address public immutable aeroRouter;
    address public immutable aeroFactory;
    address public immutable kusd;
    address public immutable usdc;
    address public immutable rss;
    address public immutable cdp;
    address public immutable landing;
    address public immutable oracle;
    address public immutable irm;
    uint256 public immutable lltvRss;

    address public owner;

    event ProofEmitted(
        address indexed borrower,
        uint256 collateralPosted,
        uint256 kusdMinted,
        uint256 usdcReceived,
        uint256 timestamp
    );

    error NotOwner();
    error BadAmt();
    error SwapFail();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address morpho_,
        address aeroRouter_,
        address aeroFactory_,
        address kusd_,
        address usdc_,
        address rss_,
        address cdp_,
        address landing_,
        address oracle_,
        address irm_,
        uint256 lltvRss_
    ) {
        morpho = morpho_;
        aeroRouter = aeroRouter_;
        aeroFactory = aeroFactory_;
        kusd = kusd_;
        usdc = usdc_;
        rss = rss_;
        cdp = cdp_;
        landing = landing_;
        oracle = oracle_;
        irm = irm_;
        lltvRss = lltvRss_;
        owner = msg.sender;
    }

    /// @notice One tx: pull RSS, mint kUSD on CDP, swap to USDC on Aero, send Landing, emit proof.
    /// @param rssAmount RSS wei to lock in CDP
    /// @param kusdAmount kUSD raw (6dp) to mint
    /// @param usdcOutMin min USDC out (slippage)
    /// @param morphoPost if >0, also post that RSS amount to Morpho RSS77 as presence (from msg.sender extra)
    function execute(uint256 rssAmount, uint256 kusdAmount, uint256 usdcOutMin, uint256 morphoPost)
        external
        nonReentrant
    {
        if (rssAmount == 0 || kusdAmount == 0) revert BadAmt();

        // Pull RSS for CDP
        IERC20(rss).safeTransferFrom(msg.sender, address(this), rssAmount);
        IERC20(rss).safeApprove(cdp, rssAmount);

        // CDP: deposit + mint (position is on this contract)
        ICrownCdp(cdp).deposit(rssAmount);
        ICrownCdp(cdp).mint(kusdAmount);

        // Optional Morpho book presence (extra RSS from caller)
        if (morphoPost > 0) {
            IERC20(rss).safeTransferFrom(msg.sender, address(this), morphoPost);
            IERC20(rss).safeApprove(morpho, morphoPost);
            IMorphoOD.MarketParams memory mp = IMorphoOD.MarketParams({
                loanToken: usdc,
                collateralToken: rss,
                oracle: oracle,
                irm: irm,
                lltv: lltvRss
            });
            IMorphoOD(morpho).supplyCollateral(mp, morphoPost, address(this), "");
        }

        // Swap kUSD -> USDC via Aero stable route, recipient = Landing
        uint256 kBal = IERC20(kusd).balanceOf(address(this));
        if (kBal < kusdAmount) kusdAmount = kBal;
        IERC20(kusd).safeApprove(aeroRouter, kusdAmount);

        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: kusd, to: usdc, stable: true, factory: aeroFactory});

        uint256 usdcBefore = IERC20(usdc).balanceOf(landing);
        IAeroRouter(aeroRouter).swapExactTokensForTokens(
            kusdAmount, usdcOutMin, routes, landing, block.timestamp + 20 minutes
        );
        uint256 usdcReceived = IERC20(usdc).balanceOf(landing) - usdcBefore;
        if (usdcOutMin > 0 && usdcReceived < usdcOutMin) revert SwapFail();

        emit ProofEmitted(msg.sender, rssAmount, kusdAmount, usdcReceived, block.timestamp);
    }

    function transferOwnership(address n) external onlyOwner {
        require(n != address(0), "ZERO");
        owner = n;
    }

    /// @notice Rescue tokens stuck on this contract to Landing.
    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(landing, amt);
    }
}
