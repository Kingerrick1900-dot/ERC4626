// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownLoopScoreboard
/// @notice On-chain dashboard — vault depth, HOT hard assets, loop meters. No manual reports.
interface IMorphoSb {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IErc20Sb {
    function balanceOf(address) external view returns (uint256);
}

interface ILoopSb {
    function fires() external view returns (uint256);
    function totalFlashed() external view returns (uint256);
    function totalCollateralPosted() external view returns (uint256);
}

interface IGateSb {
    function gateAPassed() external view returns (bool);
    function gateBPassed() external view returns (bool);
    function paused() external view returns (bool);
    function exitedUsdcToHot() external view returns (uint256);
    function vaultDepth() external view returns (uint256);
    function utilBps() external view returns (uint256);
    function pegBps() external view returns (uint256);
}

interface IYsynthSb {
    function totalAssets() external view returns (uint256);
}

contract CrownLoopScoreboard {
    IMorphoSb public immutable morpho;
    ILoopSb public immutable loop;
    IGateSb public immutable gate;
    IYsynthSb public immutable ysynth;
    IErc20Sb public immutable usdc;
    IErc20Sb public immutable eusd;
    IErc20Sb public immutable cbbtc;
    IErc20Sb public immutable weth;
    address public immutable hot;
    bytes32 public immutable marketId;

    constructor(
        address morpho_,
        address loop_,
        address gate_,
        address ysynth_,
        address usdc_,
        address eusd_,
        address cbbtc_,
        address weth_,
        address hot_,
        bytes32 marketId_
    ) {
        morpho = IMorphoSb(morpho_);
        loop = ILoopSb(loop_);
        gate = IGateSb(gate_);
        ysynth = IYsynthSb(ysynth_);
        usdc = IErc20Sb(usdc_);
        eusd = IErc20Sb(eusd_);
        cbbtc = IErc20Sb(cbbtc_);
        weth = IErc20Sb(weth_);
        hot = hot_;
        marketId = marketId_;
    }

    struct Board {
        uint256 morphoSupply;
        uint256 morphoBorrow;
        uint256 morphoUtilBps;
        uint256 ysynthAssets;
        uint256 hotUsdc;
        uint256 hotCbBtc;
        uint256 hotWeth;
        uint256 hotEusd;
        uint256 hotCollEusd;
        uint256 loopFires;
        uint256 totalFlashed;
        uint256 totalCollPosted;
        bool gateA;
        bool gateB;
        bool paused;
        uint256 exitedUsdc;
        uint256 pegBps;
        uint64 asOf;
    }

    function read() external view returns (Board memory b) {
        (uint128 s,, uint128 br,,,) = morpho.market(marketId);
        (, , uint128 coll) = morpho.position(marketId, hot);
        b.morphoSupply = uint256(s);
        b.morphoBorrow = uint256(br);
        b.morphoUtilBps = s == 0 ? 0 : (uint256(br) * 10_000) / uint256(s);
        b.ysynthAssets = ysynth.totalAssets();
        b.hotUsdc = usdc.balanceOf(hot);
        b.hotCbBtc = cbbtc.balanceOf(hot);
        b.hotWeth = weth.balanceOf(hot);
        b.hotEusd = eusd.balanceOf(hot);
        b.hotCollEusd = uint256(coll);
        b.loopFires = loop.fires();
        b.totalFlashed = loop.totalFlashed();
        b.totalCollPosted = loop.totalCollateralPosted();
        b.gateA = gate.gateAPassed();
        b.gateB = gate.gateBPassed();
        b.paused = gate.paused();
        b.exitedUsdc = gate.exitedUsdcToHot();
        b.pegBps = gate.pegBps();
        b.asOf = uint64(block.timestamp);
    }
}
