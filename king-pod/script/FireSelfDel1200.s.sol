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
    function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function accrueInterest(MarketParams memory marketParams) external;
}

/// @notice Self-deleverage matched $1200 book: flash → repay → free RSS to HOT → withdraw supply → repay flash.
/// @dev No RSS stuck in helper. King can fire anytime (FIRE_SELF_DEL_1200=1).
contract SelfDel1200 {
    IMorpho immutable morpho;
    IERC20 immutable usdc;
    IERC20 immutable rss;
    address immutable hot;
    bytes32 immutable mid;
    IMorpho.MarketParams mp;
    bool locking;

    constructor(address morpho_, address usdc_, address rss_, address hot_, bytes32 mid_, IMorpho.MarketParams memory mp_) {
        morpho = IMorpho(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        hot = hot_;
        mid = mid_;
        mp = mp_;
    }

    function run() external {
        require(msg.sender == hot, "HOT");
        morpho.accrueInterest(mp);
        (uint256 supShares, uint128 borShares, uint128 coll) = morpho.position(mid, hot);
        if (borShares == 0 && coll == 0 && supShares == 0) return;

        if (borShares > 0) {
            (,, uint128 tba, uint128 tbs,,) = morpho.market(mid);
            uint256 flashAmt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
            flashAmt += 1_000e6; // $1k buffer covers interest + 1-wei share rounding
            locking = true;
            morpho.flashLoan(address(usdc), flashAmt, abi.encode(supShares, uint256(borShares), uint256(coll)));
            locking = false;
        } else {
            if (coll > 0) morpho.withdrawCollateral(mp, coll, hot, hot);
            if (supShares > 0) morpho.withdraw(mp, 0, supShares, hot, hot);
        }

        uint256 u = usdc.balanceOf(address(this));
        if (u > 0) usdc.transfer(hot, u);
        uint256 r = rss.balanceOf(address(this));
        if (r > 0) rss.transfer(hot, r);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho) && locking, "FL");
        (uint256 supShares, uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);

        if (borShares > 0) morpho.repay(mp, 0, borShares, hot, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, hot, hot);
        if (supShares > 0) morpho.withdraw(mp, 0, supShares, hot, address(this));

        uint256 have = usdc.balanceOf(address(this));
        if (have < assets) {
            // Pull dust from HOT (pre-approved) to cover 1-wei / interest gap
            uint256 need = assets - have;
            require(usdc.transferFrom(hot, address(this), need), "DUST");
        }
        require(usdc.balanceOf(address(this)) >= assets, "SHORT");
        usdc.approve(address(morpho), assets);
    }
}

contract FireSelfDel1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        require(vm.envOr("FIRE_SELF_DEL_1200", uint256(0)) == 1, "NEED FIRE_SELF_DEL_1200=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);

        vm.startBroadcast(pk);
        SelfDel1200 z = new SelfDel1200(MORPHO, USDC, RSS, HOT, MID, mp);
        IMorpho(MORPHO).setAuthorization(address(z), true);
        IERC20(USDC).approve(address(z), 2_000e6); // dust cover for interest gap
        z.run();
        IMorpho(MORPHO).setAuthorization(address(z), false);
        IERC20(USDC).approve(address(z), 0);
        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(MID, HOT);
        (uint256 sup,,) = IMorpho(MORPHO).position(MID, HOT);
        console2.log("hotSupShares", sup);
        console2.log("hotBorShares", uint256(bor));
        console2.log("hotCollRss", uint256(coll));
        console2.log("hotRssFree", IERC20(RSS).balanceOf(HOT));
        console2.log("SELF_DEL_1200_OK", (bor == 0 && coll == 0) ? uint256(1) : uint256(0));
    }
}
