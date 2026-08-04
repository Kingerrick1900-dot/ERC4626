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
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
}

/// @notice Activate empty RSS/$1200 market: flash USDC → supply → post RSS → borrow → repay flash.
/// @dev Leaves matched supply+borrow (no free wallet USDC). FIRE_SEED_1200=1.
contract FlashSeed1200 {
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

    function run(uint256 seedUsdc, uint256 collRss) external {
        require(msg.sender == hot, "HOT");
        rss.transferFrom(hot, address(this), collRss);
        locking = true;
        morpho.flashLoan(address(usdc), seedUsdc, abi.encode(seedUsdc, collRss));
        locking = false;
        uint256 left = usdc.balanceOf(address(this));
        if (left > 0) usdc.transfer(hot, left);
        uint256 rssLeft = rss.balanceOf(address(this));
        if (rssLeft > 0) rss.transfer(hot, rssLeft);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho) && locking, "FL");
        (uint256 seedUsdc, uint256 collRss) = abi.decode(data, (uint256, uint256));
        usdc.approve(address(morpho), type(uint256).max);
        rss.approve(address(morpho), type(uint256).max);

        // 1) seed market liquidity
        morpho.supply(mp, seedUsdc, 0, hot, "");
        // 2) post RSS coll on hot
        morpho.supplyCollateral(mp, collRss, hot, "");
        // 3) borrow same USDC to hot (liquidity just created)
        morpho.borrow(mp, seedUsdc, 0, hot, address(this));

        require(usdc.balanceOf(address(this)) >= assets, "SHORT");
        usdc.approve(address(morpho), assets);
    }
}

contract FireFlashSeed1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    // $100k seed — activates market; matched books (no free USDC out)
    uint256 constant SEED = 100_000e6;
    // $100k / 0.77 / $1200 ≈ 108.2 RSS → buffer
    uint256 constant COLL = 150 ether;

    function run() external {
        require(vm.envOr("FIRE_SEED_1200", uint256(0)) == 1, "NEED FIRE_SEED_1200=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);

        vm.startBroadcast(pk);
        FlashSeed1200 z = new FlashSeed1200(MORPHO, USDC, RSS, HOT, MID, mp);
        IMorpho(MORPHO).setAuthorization(address(z), true);
        IERC20(RSS).approve(address(z), COLL);
        z.run(SEED, COLL);
        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(MID, HOT);
        (uint128 tsa,, uint128 tba,,,) = IMorpho(MORPHO).market(MID);
        console2.log("supplyAssets", uint256(tsa));
        console2.log("borrowAssets", uint256(tba));
        console2.log("hotBorShares", uint256(bor));
        console2.log("hotCollRss", uint256(coll));
        console2.log("hotUsdc", IERC20(USDC).balanceOf(HOT));
        console2.log("SEED_1200_OK", tba > 0 ? uint256(1) : uint256(0));
    }
}
