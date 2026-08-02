// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transfer(address,uint256) external returns (bool);
}
interface IMorpho {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256, uint256, address, bytes memory) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256, address, address) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function setAuthorization(address, bool) external;
}
interface IYele {
    function balanceOf(address) external view returns (uint256);
    function transfer(address,uint256) external returns (bool);
    function approve(address,uint256) external returns (bool);
    function maxWithdraw(address) external view returns (uint256);
    function maxRedeem(address) external view returns (uint256);
    function withdraw(uint256,address,address) external returns (uint256);
    function redeem(uint256,address,address) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract EleUnwindDebug is Test {
    address HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address LAND=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address ELE=0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address YELE=0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address ORACLE=0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address IRM=0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 MID=0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bool locking;

    function setUp() public { vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org"))); }

    function test_debug() public {
        uint256 sh=IYele(YELE).balanceOf(LAND);
        vm.prank(LAND); IYele(YELE).transfer(HOT, sh);
        // also any fee shares on landing minted later — transfer again at end of setup
        vm.startPrank(HOT);
        IMorpho(MORPHO).setAuthorization(address(this), true);
        IYele(YELE).approve(address(this), type(uint256).max);
        vm.stopPrank();
        deal(USDC, address(this), 100e6, true);

        IMorpho.MarketParams memory mp=IMorpho.MarketParams(USDC,ELE,ORACLE,IRM,770000000000000000);
        IMorpho(MORPHO).accrueInterest(mp);
        (,uint128 bor,uint128 coll)=IMorpho(MORPHO).position(MID,HOT);
        (,,uint128 tba,uint128 tbs,,)=IMorpho(MORPHO).market(MID);
        uint256 flashNeed=(uint256(tba)*uint256(bor)+uint256(tbs)-1)/uint256(tbs)+5e6;
        locking=true;
        IMorpho(MORPHO).flashLoan(USDC, flashNeed, abi.encode(uint256(bor), uint256(coll)));
        locking=false;
        (,uint128 b2,uint128 c2)=IMorpho(MORPHO).position(MID,HOT);
        console2.log("debt", uint256(b2));
        console2.log("coll", uint256(c2));
        console2.log("ele", IERC20(ELE).balanceOf(HOT));
        console2.log("OK", uint256(1));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender==MORPHO && locking);
        (uint256 borShares, uint256 coll)=abi.decode(data,(uint256,uint256));
        IMorpho.MarketParams memory mp=IMorpho.MarketParams(USDC,ELE,ORACLE,IRM,770000000000000000);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IMorpho(MORPHO).repay(mp, 0, borShares, HOT, "");
        if (coll>0) IMorpho(MORPHO).withdrawCollateral(mp, coll, HOT, HOT);

        // pull any new fee shares on landing
        uint256 landSh=IYele(YELE).balanceOf(LAND);
        if (landSh>0) { vm.prank(LAND); IYele(YELE).transfer(HOT, landSh); }

        uint256 maxR=IYele(YELE).maxRedeem(HOT);
        console2.log("maxRedeem", maxR);
        if (maxR>0) {
            uint256 assetsOut=IYele(YELE).redeem(maxR, address(this), HOT);
            console2.log("redeemedAssets", assetsOut);
        }
        console2.log("shares left", IYele(YELE).balanceOf(HOT));
        console2.log("have", IERC20(USDC).balanceOf(address(this)));
        console2.log("need", assets);
        uint256 have=IERC20(USDC).balanceOf(address(this));
        if (have < assets) {
            // size was too fat — shouldn't happen with $100 buffer
            console2.log("short", assets - have);
        }
        require(have >= assets, "SHORT");
        IERC20(USDC).approve(MORPHO, assets);
    }
}
