// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";

interface IMorpho {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256, uint256);
    function withdraw(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory m, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}
interface IERC20 { function approve(address,uint256) external returns (bool); function balanceOf(address) external view returns (uint256); function transfer(address,uint256) external returns (bool); }

contract DustCloser {
    IMorpho immutable morpho;
    IERC20 immutable usdc;
    address immutable king;
    IMorpho.MarketParams mp;
    bytes32 immutable marketId;
    bool locking;
    constructor(address morpho_, address usdc_, address eusd_, address king_, address oracle_, address irm_, uint256 lltv_) {
        morpho = IMorpho(morpho_); usdc = IERC20(usdc_); king = king_;
        mp = IMorpho.MarketParams(usdc_, eusd_, oracle_, irm_, lltv_);
        marketId = keccak256(abi.encode(mp));
    }
    function close() external {
        (, uint128 borShares,) = morpho.position(marketId, king);
        require(borShares > 0, "no debt");
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        uint256 debt = (uint256(borShares) * uint256(tba) + uint256(tbs) - 1) / uint256(tbs);
        (uint256 supShares,,) = morpho.position(marketId, king);
        (uint128 tsa, uint128 tss,,,,) = morpho.market(marketId);
        uint256 sup = (uint256(supShares) * uint256(tsa)) / uint256(tss);
        uint256 flashAmt = debt > sup ? debt : sup; // cover repay; withdraw returns supply
        // if debt > supply need external USDC — should not happen after top-up
        locking = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(flashAmt));
        locking = false;
        (, uint128 bor2, uint128 coll) = morpho.position(marketId, king);
        if (bor2 == 0 && coll > 0) morpho.withdrawCollateral(mp, coll, king, king);
        uint256 dust = usdc.balanceOf(address(this));
        if (dust > 0) usdc.transfer(king, dust);
    }
    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == address(morpho) && locking, "x");
        usdc.approve(address(morpho), type(uint256).max);
        (, uint128 borShares,) = morpho.position(marketId, king);
        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        (uint256 supShares,,) = morpho.position(marketId, king);
        if (supShares > 0) morpho.withdraw(mp, 0, supShares, king, address(this));
        usdc.approve(address(morpho), assets);
    }
}

contract FireDustClose is Script {
    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk==0) pk = vm.envUint("PRIVATE_KEY");
        address HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
        require(vm.addr(pk)==HOT,"NOT_HOT");
        vm.startBroadcast(pk);
        DustCloser c = new DustCloser(
            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb,
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a,
            HOT,
            0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e,
            0x46415998764C29aB2a25CbeA6254146D50D22687,
            860000000000000000
        );
        IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb).setAuthorization(address(c), true);
        c.close();
        vm.stopBroadcast();
        console2.log("DustCloser", address(c));
        (uint256 s, uint128 b, uint128 coll) = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb).position(
            0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd, HOT);
        console2.log("sup", s); console2.log("bor", uint256(b)); console2.log("coll", uint256(coll));
        console2.log("eusd", IERC20(0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a).balanceOf(HOT));
        console2.log("usdc", IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913).balanceOf(HOT));
    }
}
interface IMorphoAuth { function setAuthorization(address,bool) external; }
