// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoC {
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
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function reallocate(MarketAllocation[] calldata allocations) external;
    function skim(address token) external;
    function setSkimRecipient(address) external;
    function withdrawQueue(uint256) external view returns (bytes32);
    function withdrawQueueLength() external view returns (uint256);
}

/// @notice Wipe freer DUST_DEBT leftover — King never received this as cash.
/// @dev FIRE_CLEAR_DUST=1. Pattern from ClearBooksSkim: flash → repay → reallocate(0) → skim → repay flash.
contract FireClearDustDebt is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    DustClearerSkim internal clearer;
    bool internal locking;

    function run() external {
        require(vm.envOr("FIRE_CLEAR_DUST", uint256(0)) == 1, "NEED FIRE_CLEAR_DUST=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        IMorphoC.MarketParams memory mp =
            IMorphoC.MarketParams({loanToken: USDC, collateralToken: RSS, oracle: ORACLE, irm: IRM, lltv: LLTV});

        (, uint128 bor, uint128 coll) = IMorphoC(MORPHO).position(MID, HOT);
        require(bor > 0, "NO_DUST");
        (,, uint128 tba, uint128 tbs,,) = IMorphoC(MORPHO).market(MID);
        uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        console2.log("dustDebt", debt);
        console2.log("dustColl", coll);

        vm.startBroadcast(pk);
        clearer = new DustClearerSkim(MORPHO, USDC, RSS, YRSS, HOT, MID);
        IMorphoC(MORPHO).setAuthorization(address(clearer), true);
        IYrssC(YRSS).setSkimRecipient(address(clearer));
        // hot USDC gap → clearer
        uint256 gap = IERC20C(USDC).balanceOf(HOT);
        if (gap > 0) IERC20C(USDC).transfer(address(clearer), gap);
        clearer.clear(mp, uint256(bor), uint256(coll), debt + 2e6);
        vm.stopBroadcast();

        (, uint128 b2, uint128 c2) = IMorphoC(MORPHO).position(MID, HOT);
        console2.log("borAfter", b2);
        console2.log("collAfter", c2);
        console2.log("rssHot", IERC20C(RSS).balanceOf(HOT));
        console2.log("DUST_CLEARED", uint256(1));
    }
}

contract DustClearerSkim {
    IMorphoC public immutable morpho;
    IERC20C public immutable usdc;
    IERC20C public immutable rss;
    IYrssC public immutable yrss;
    address public immutable king;
    bytes32 public immutable marketId;
    bool private _in;
    uint256 private _flash;

    constructor(address morpho_, address usdc_, address rss_, address yrss_, address king_, bytes32 mid_) {
        morpho = IMorphoC(morpho_);
        usdc = IERC20C(usdc_);
        rss = IERC20C(rss_);
        yrss = IYrssC(yrss_);
        king = king_;
        marketId = mid_;
    }

    function clear(IMorphoC.MarketParams calldata mp, uint256, uint256, uint256 flashAmt) external {
        require(msg.sender == king, "KING");
        _flash = flashAmt;
        _in = true;
        morpho.flashLoan(address(usdc), flashAmt, abi.encode(mp));
        _in = false;
        uint256 left = usdc.balanceOf(address(this));
        if (left > 0) usdc.transfer(king, left);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho) && _in, "FL");
        IMorphoC.MarketParams memory mp = abi.decode(data, (IMorphoC.MarketParams));
        usdc.approve(address(morpho), type(uint256).max);

        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        if (borShares > 0) morpho.repay(mp, 0, borShares, king, "");
        if (coll > 0) morpho.withdrawCollateral(mp, coll, king, king);

        // Pull every withdraw-queue market to vault idle (assets=0), then skim
        uint256 n = yrss.withdrawQueueLength();
        IYrssC.MarketAllocation[] memory allocs = new IYrssC.MarketAllocation[](n);
        for (uint256 i; i < n; i++) {
            bytes32 id = yrss.withdrawQueue(i);
            (address loan, address collT, address ora, address irm, uint256 lltv) = morpho.idToMarketParams(id);
            allocs[i] = IYrssC.MarketAllocation({
                marketParams: IYrssC.MarketParams(loan, collT, ora, irm, lltv),
                assets: 0
            });
        }
        yrss.reallocate(allocs);
        yrss.skim(address(usdc));

        require(usdc.balanceOf(address(this)) >= assets, "SHORT");
        usdc.approve(address(morpho), assets);
    }
}
