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
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function accrueInterest(MarketParams memory marketParams) external;
}
interface IYrss {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

contract Finish16 {
    IMorpho immutable morpho; IERC20 immutable usdc; IYrss immutable yrss;
    address immutable hot; address immutable landing; bytes32 immutable mid;
    IMorpho.MarketParams mp; bool locking;
    constructor(address m,address u,address y,address h,address land,bytes32 id,IMorpho.MarketParams memory mp_) {
        morpho=IMorpho(m); usdc=IERC20(u); yrss=IYrss(y); hot=h; landing=land; mid=id; mp=mp_;
    }
    function run() external {
        require(msg.sender==hot,"HOT");
        morpho.accrueInterest(mp);
        (,uint128 bor,uint128 coll)=morpho.position(mid,hot);
        require(bor>0,"NO_DEBT");
        (,,uint128 tba,uint128 tbs,,)=morpho.market(mid);
        uint256 flashAmt=(uint256(tba)*uint256(bor)+uint256(tbs)-1)/uint256(tbs)+1e5; // tiny buffer
        locking=true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(bor), uint256(coll)));
        locking=false;
        // refund any leftover USDC to landing first (source of gap), then hot
        uint256 left=usdc.balanceOf(address(this));
        if(left>0){ usdc.transfer(landing, left); }
    }
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender==address(morpho)&&locking,"FL");
        (uint256 borShares,)=abi.decode(data,(uint256,uint256));
        usdc.approve(address(morpho), type(uint256).max);
        morpho.repay(mp, 0, borShares, hot, "");
        (,,uint128 coll)=morpho.position(mid,hot);
        if(coll>0) morpho.withdrawCollateral(mp, coll, hot, hot);

        // pull landing yRSS now that repay freed liquidity
        uint256 w=yrss.maxWithdraw(landing);
        if(w>0) yrss.withdraw(w, address(this), landing);
        w=yrss.maxWithdraw(hot);
        if(w>0) yrss.withdraw(w, address(this), hot);

        if(usdc.balanceOf(address(this))<assets){
            uint256 need=assets-usdc.balanceOf(address(this));
            uint256 lb=usdc.balanceOf(landing);
            uint256 take=need<=lb?need:lb;
            if(take>0) usdc.transferFrom(landing, address(this), take);
        }
        if(usdc.balanceOf(address(this))<assets){
            uint256 need=assets-usdc.balanceOf(address(this));
            uint256 hb=usdc.balanceOf(hot);
            uint256 take=need<=hb?need:hb;
            if(take>0) usdc.transferFrom(hot, address(this), take);
        }
        require(usdc.balanceOf(address(this))>=assets,"SHORT");
        usdc.approve(address(morpho), assets);
    }
}

contract FireFinish16 is Script {
    address constant HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE=0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM=0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV=770000000000000000;
    bytes32 constant MID=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 hotPk=vm.envUint("PRIVATE_KEY");
        uint256 landPk=vm.envUint("LANDING_KEY");
        require(vm.addr(hotPk)==HOT,"HOT");
        require(vm.addr(landPk)==LANDING,"LANDING");
        IMorpho.MarketParams memory mp=IMorpho.MarketParams(USDC,RSS,ORACLE,IRM,LLTV);

        vm.startBroadcast(hotPk);
        Finish16 z=new Finish16(MORPHO,USDC,YRSS,HOT,LANDING,MID,mp);
        IMorpho(MORPHO).setAuthorization(address(z), true);
        IYrss(YRSS).approve(address(z), type(uint256).max);
        IERC20(USDC).approve(address(z), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        IYrss(YRSS).approve(address(z), type(uint256).max);
        IERC20(USDC).approve(address(z), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(hotPk);
        z.run();
        vm.stopBroadcast();

        (,uint128 b,uint128 c)=IMorpho(MORPHO).position(MID,HOT);
        console2.log("bor",uint256(b));
        console2.log("coll",uint256(c));
        console2.log("rssHot",IERC20(RSS).balanceOf(HOT));
        console2.log("usdcLand",IERC20(USDC).balanceOf(LANDING));
        console2.log("usdcHot",IERC20(USDC).balanceOf(HOT));
        console2.log("DONE", b==0&&c==0?uint256(1):uint256(0));
    }
}
