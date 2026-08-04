// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
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
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrss {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IAero {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(uint256, uint256, Route[] calldata, address, uint256)
        external
        returns (uint256[] memory);
}

contract LowerTo16 {
    IMorpho public immutable morpho;
    IERC20 public immutable usdc;
    IYrss public immutable yrss;
    address public immutable hot;
    bytes32 public immutable mid;
    IMorpho.MarketParams public mp;
    bool private locking;

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address hot_,
        bytes32 mid_,
        IMorpho.MarketParams memory mp_
    ) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrss(yrss_);
        hot = hot_;
        mid = mid_;
        mp = mp_;
    }

    function run(uint256 repayAmt, uint256 keepColl) external {
        require(msg.sender == hot, "HOT");
        locking = true;
        morpho.flashLoan(address(usdc), repayAmt, abi.encode(repayAmt, keepColl));
        locking = false;
        uint256 left = usdc.balanceOf(address(this));
        if (left > 0) usdc.transfer(hot, left);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho) && locking, "FL");
        (uint256 repayAmt, uint256 keepColl) = abi.decode(data, (uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);

        morpho.repay(mp, repayAmt, 0, hot, "");

        (, , uint128 coll) = morpho.position(mid, hot);
        if (uint256(coll) > keepColl) {
            morpho.withdrawCollateral(mp, uint256(coll) - keepColl, hot, hot);
        }

        // Repay freed idle in withdraw-queue #0 — pull hot yRSS straight out
        uint256 pull = yrss.maxWithdraw(hot);
        if (pull > assets) pull = assets;
        if (pull > 0) yrss.withdraw(pull, address(this), hot);

        if (usdc.balanceOf(address(this)) < assets) {
            uint256 need = assets - usdc.balanceOf(address(this));
            uint256 bal = usdc.balanceOf(hot);
            if (bal > 0) usdc.transferFrom(hot, address(this), need <= bal ? need : bal);
        }
        require(usdc.balanceOf(address(this)) >= assets, "SHORT");
        usdc.approve(address(morpho), assets);
    }
}

contract FireLowerTo16 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant TARGET = 16e6;
    uint256 constant KEEP_COLL = 25 ether;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 bor,) = IMorpho(MORPHO).position(MID, HOT);
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(MID);
        uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        require(debt > TARGET, "ALREADY");
        uint256 repayAmt = debt - TARGET;

        vm.startBroadcast(pk);

        IERC20(RSS).approve(AERO, 50_000 ether);
        IAero.Route[] memory routes = new IAero.Route[](1);
        routes[0] = IAero.Route(RSS, USDC, false, FACTORY);
        IAero(AERO).swapExactTokensForTokens(50_000 ether, 1, routes, HOT, block.timestamp + 600);

        LowerTo16 z = new LowerTo16(MORPHO, USDC, YRSS, HOT, MID, mp);
        IMorpho(MORPHO).setAuthorization(address(z), true);
        IYrss(YRSS).approve(address(z), type(uint256).max);
        IERC20(USDC).approve(address(z), type(uint256).max);
        z.run(repayAmt, KEEP_COLL);

        vm.stopBroadcast();

        (, uint128 b2, uint128 c2) = IMorpho(MORPHO).position(MID, HOT);
        (,, uint128 tba2, uint128 tbs2,,) = IMorpho(MORPHO).market(MID);
        uint256 d2 = b2 == 0 ? 0 : (uint256(tba2) * uint256(b2) + uint256(tbs2) - 1) / uint256(tbs2);
        console2.log("debtAfter", d2);
        console2.log("collAfter", uint256(c2));
        console2.log("rss", IERC20(RSS).balanceOf(HOT));
    }
}
