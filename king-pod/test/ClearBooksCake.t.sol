// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
interface IMorpho {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory marketParams) external;
    function setAuthorization(address, bool) external;
}
interface IYrss {
    function maxWithdraw(address) external view returns (uint256);
    function withdraw(uint256, address, address) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function redeem(uint256, address, address) external returns (uint256);
    function maxRedeem(address) external view returns (uint256);
}

contract ClearBooksCakeTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CAKE = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    bool locking;

    function test_clear_with_cake() public {
        vm.startPrank(HOT);
        IMorpho(MORPHO).setAuthorization(address(this), true);
        IYrss(YRSS).approve(address(this), type(uint256).max);
        IERC20(USDC).approve(address(this), type(uint256).max);
        vm.stopPrank();
        vm.prank(CAKE);
        IYrss(YRSS).approve(address(this), type(uint256).max);

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(MID, HOT);
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(MID);
        uint256 flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs) + 2e6;
        locking = true;
        IMorpho(MORPHO).flashLoan(USDC, flashAmt, abi.encode(uint256(bor), uint256(coll)));
        locking = false;

        // redeem any leftover shares to hot
        vm.startPrank(HOT);
        uint256 mr = IYrss(YRSS).maxRedeem(HOT);
        if (mr > 0) IYrss(YRSS).redeem(mr, HOT, HOT);
        vm.stopPrank();
        vm.startPrank(CAKE);
        mr = IYrss(YRSS).maxRedeem(CAKE);
        if (mr > 0) IYrss(YRSS).redeem(mr, CAKE, CAKE);
        vm.stopPrank();

        (, uint128 b2, uint128 c2) = IMorpho(MORPHO).position(MID, HOT);
        console2.log("bor", uint256(b2));
        console2.log("coll", uint256(c2));
        console2.log("rss", IERC20(RSS).balanceOf(HOT) / 1e18);
        console2.log("hotUsdc", IERC20(USDC).balanceOf(HOT));
        console2.log("cakeUsdc", IERC20(USDC).balanceOf(CAKE));
        console2.log("yrssHot", IYrss(YRSS).balanceOf(HOT));
        console2.log("yrssCake", IYrss(YRSS).balanceOf(CAKE));
        assertEq(uint256(b2), 0);
        assertEq(uint256(c2), 0);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO && locking);
        (uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256));
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IMorpho(MORPHO).repay(mp, 0, borShares, HOT, "");
        if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, coll, HOT, HOT);

        _pull(HOT, assets);
        if (IERC20(USDC).balanceOf(address(this)) < assets) _pull(CAKE, assets);
        if (IERC20(USDC).balanceOf(address(this)) < assets) {
            uint256 need = assets - IERC20(USDC).balanceOf(address(this));
            uint256 bal = IERC20(USDC).balanceOf(HOT);
            uint256 take = bal < need ? bal : need;
            if (take > 0) IERC20(USDC).transferFrom(HOT, address(this), take);
        }
        require(IERC20(USDC).balanceOf(address(this)) >= assets, "SHORT");
        IERC20(USDC).approve(MORPHO, assets);
    }

    function _pull(address owner, uint256 assets) internal {
        uint256 have = IERC20(USDC).balanceOf(address(this));
        if (have >= assets) return;
        uint256 need = assets - have;
        uint256 maxW = IYrss(YRSS).maxWithdraw(owner);
        uint256 pull = maxW < need ? maxW : need;
        if (pull > 0) IYrss(YRSS).withdraw(pull, address(this), owner);
    }
}
