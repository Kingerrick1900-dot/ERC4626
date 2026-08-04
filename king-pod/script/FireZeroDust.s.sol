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
}

contract ZeroDust {
    IMorpho immutable morpho; IERC20 immutable usdc; IYrss immutable yrss; address immutable hot; bytes32 immutable mid;
    IMorpho.MarketParams mp; bool locking;
    constructor(address m, address u, address y, address h, bytes32 id, IMorpho.MarketParams memory mp_) {
        morpho=IMorpho(m); usdc=IERC20(u); yrss=IYrss(y); hot=h; mid=id; mp=mp_;
    }
    function run() external {
        require(msg.sender==hot,"HOT");
        (,uint128 bor,uint128 coll)=morpho.position(mid,hot);
        if(bor==0&&coll==0)return;
        uint256 flashAmt;
        if(bor>0){
            (,,uint128 tba,uint128 tbs,,)=morpho.market(mid);
            flashAmt=(uint256(tba)*uint256(bor)+uint256(tbs)-1)/uint256(tbs)+2e6;
        }
        locking=true;
        if(flashAmt>0) morpho.flashLoan(address(usdc), flashAmt, abi.encode(uint256(bor), uint256(coll)));
        else if(coll>0) morpho.withdrawCollateral(mp, coll, hot, hot);
        locking=false;
        uint256 left=usdc.balanceOf(address(this));
        if(left>0) usdc.transfer(hot,left);
    }
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender==address(morpho)&&locking,"FL");
        (uint256 borShares,uint256 collAmt)=abi.decode(data,(uint256,uint256));
        usdc.approve(address(morpho), type(uint256).max);
        if(borShares>0) morpho.repay(mp, 0, borShares, hot, "");
        (, , uint128 coll)=morpho.position(mid,hot);
        if(coll>0) morpho.withdrawCollateral(mp, coll, hot, hot);
        uint256 pull=yrss.maxWithdraw(hot);
        if(pull>assets) pull=assets;
        if(pull>0) yrss.withdraw(pull, address(this), hot);
        if(usdc.balanceOf(address(this))<assets){
            uint256 need=assets-usdc.balanceOf(address(this));
            uint256 bal=usdc.balanceOf(hot);
            if(bal>0) usdc.transferFrom(hot,address(this), need<=bal?need:bal);
        }
        require(usdc.balanceOf(address(this))>=assets,"SHORT");
        usdc.approve(address(morpho), assets);
    }
}

contract FireZeroDust is Script {
    address constant HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE=0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM=0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV=770000000000000000;
    bytes32 constant MID=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    function run() external {
        uint256 pk=vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk)==HOT,"HOT");
        IMorpho.MarketParams memory mp=IMorpho.MarketParams(USDC,RSS,ORACLE,IRM,LLTV);
        vm.startBroadcast(pk);
        ZeroDust z=new ZeroDust(MORPHO,USDC,YRSS,HOT,MID,mp);
        IMorpho(MORPHO).setAuthorization(address(z), true);
        IYrss(YRSS).approve(address(z), type(uint256).max);
        IERC20(USDC).approve(address(z), type(uint256).max);
        z.run();
        vm.stopBroadcast();
        (,uint128 b,uint128 c)=IMorpho(MORPHO).position(MID,HOT);
        console2.log("bor",uint256(b));
        console2.log("coll",uint256(c));
        console2.log("rss",IERC20(RSS).balanceOf(HOT));
        console2.log("DONE", b==0&&c==0?uint256(1):uint256(0));
    }
}
