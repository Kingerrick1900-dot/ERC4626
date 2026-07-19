// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";

interface IMorpho {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}
interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address,uint256) external returns (bool); }
interface IYrss { function maxWithdraw(address) external view returns (uint256); function withdraw(uint256,address,address) external returns (uint256); function approve(address,uint256) external returns (bool); }

contract Chunker is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    bool locking;
    uint256 flashAmt;
    uint256 repayAssets;

    function test_chunk_loop_zero_prefund() public {
        vm.startPrank(HOT);
        IMorpho(MORPHO).setAuthorization(address(this), true);
        IYrss(YRSS).approve(address(this), type(uint256).max);
        vm.stopPrank();

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        // chunk until dust
        for (uint256 i; i < 20; i++) {
            IMorpho(MORPHO).accrueInterest(mp);
            (, uint128 borShares,) = IMorpho(MORPHO).position(MID, HOT);
            if (borShares == 0) break;
            (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(MID);
            uint256 debt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            // leave last ~$300 debt to avoid rounding Short on final full close
            uint256 chunk = debt > 300e6 ? (debt > 1_000_000e6 ? 1_000_000e6 : debt - 300e6) : 0;
            if (chunk == 0) break;
            flashAmt = chunk;
            repayAssets = chunk;
            locking = true;
            IMorpho(MORPHO).flashLoan(USDC, chunk, "");
            locking = false;
            console2.log("chunk", i, chunk);
        }

        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 bor2, uint128 coll2) = IMorpho(MORPHO).position(MID, HOT);
        console2.log("bor left", uint256(bor2));
        console2.log("coll", uint256(coll2));
        // withdraw excess collateral vs dust debt
        // max borrow at 77% lltv with price $1 (oracle scale 1e36): maxBorrow = coll * price / 1e36 * lltv
        // Keep coll for dust: debt/lltv with buffer
        (,, uint128 tba2, uint128 tbs2,,) = IMorpho(MORPHO).market(MID);
        uint256 debtLeft = bor2 == 0 ? 0 : (uint256(tba2) * uint256(bor2) + uint256(tbs2) - 1) / uint256(tbs2);
        console2.log("debtLeft$", debtLeft / 1e6);
        // Keep $400 of coll value buffer at $1/RSS => 400 RSS + debt/0.77
        uint256 keep = debtLeft == 0 ? 0 : (debtLeft * 1e18 / 77e16) + 400 ether; // rough
        if (keep < coll2) {
            vm.prank(HOT);
            // need auth - this contract is authorized
            IMorpho(MORPHO).withdrawCollateral(mp, uint256(coll2) - keep, HOT, HOT);
        }
        (, uint128 bor3, uint128 coll3) = IMorpho(MORPHO).position(MID, HOT);
        console2.log("final bor", uint256(bor3));
        console2.log("final coll", uint256(coll3));
        console2.log("hot RSS", IERC20(RSS).balanceOf(HOT) / 1e18);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO && locking);
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IMorpho(MORPHO).repay(mp, repayAssets, 0, HOT, "");
        uint256 need = assets - IERC20(USDC).balanceOf(address(this));
        uint256 maxW = IYrss(YRSS).maxWithdraw(HOT);
        uint256 pull = maxW < need ? maxW : need;
        if (pull > 0) IYrss(YRSS).withdraw(pull, address(this), HOT);
        require(IERC20(USDC).balanceOf(address(this)) >= assets, "SHORT");
        IERC20(USDC).approve(MORPHO, assets);
    }
}
