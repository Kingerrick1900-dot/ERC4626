// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IYeleE {
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

    function deposit(uint256 assets, address receiver) external returns (uint256);
    function reallocate(MarketAllocation[] calldata allocations) external;
    function isAllocator(address) external view returns (bool);
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
}

/// @notice Exit ladder — borrow liquid USDC to Landing. No fake headroom borrows.
/// @dev Headroom (LLTV room) ≠ idle (cash in market). `drawIdle` / `leverageLoop` need idle > 0.
///      leverageLoop = DeepSeek sequence once idle exists: borrow→seed yELE→realloc→borrow Landing.
contract CrownExitLadder {
    using ZkKingGate for IZkGateBook;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    IZkGateBook public immutable gate;
    address public immutable king;
    address public immutable landing;

    event IdleDrawn(uint256 assets, uint256 landUsdc);
    event LeverageLooped(uint256 seed, uint256 landUsdc);

    constructor(address king_, address landing_) {
        gate = IZkGateBook(GATE);
        king = king_;
        landing = landing_;
    }

    /// @notice Borrow liquid idle USDC → Landing (capped by LLTV room).
    function drawIdle(uint256 maxAmt) external returns (uint256 borrowed) {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        IMorphoE.MarketParams memory mp = _eleMp();
        IMorphoE(MORPHO).accrueInterest(mp);
        borrowed = _borrowTo(landing, maxAmt == 0 ? type(uint256).max : maxAmt);
        emit IdleDrawn(borrowed, IERC20E(USDC).balanceOf(landing));
    }

    /// @notice DeepSeek loop when idle ≥ seed and yELE WETH enabled.
    /// @dev borrow seed → deposit yELE → realloc WETH→ELE → borrow seed → Landing.
    ///      Net Landing +seed; debt +2*seed; requires FIRST seed of liquid idle (not headroom).
    function leverageLoop(uint256 seed) external returns (uint256 landed) {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        require(seed > 0, "SEED");
        (, bool wethOn,) = IYeleE(YELE).config(WETH_USDC);
        require(wethOn, "WETH_OFF");
        require(IYeleE(YELE).isAllocator(address(this)), "ALLOC");

        IMorphoE.MarketParams memory mp = _eleMp();
        IMorphoE(MORPHO).accrueInterest(mp);

        // 1) Borrow seed from live idle → this contract
        uint256 got = _borrowTo(address(this), seed);
        require(got + 1e6 >= seed, "NO_IDLE");

        // 2) Seed yELE (supply queue must prefer WETH — set off-contract / prior tx)
        IERC20E(USDC).approve(YELE, got);
        IYeleE(YELE).deposit(got, king);

        // 3) Realloc vault USDC into ELE/USDC
        IYeleE.MarketAllocation[] memory allocs = new IYeleE.MarketAllocation[](2);
        allocs[0] = IYeleE.MarketAllocation({
            marketParams: IYeleE.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86),
            assets: 1
        });
        allocs[1] = IYeleE.MarketAllocation({
            marketParams: IYeleE.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77),
            assets: type(uint256).max
        });
        IYeleE(YELE).reallocate(allocs);

        // 4) Borrow seed again → Landing
        landed = _borrowTo(landing, seed);
        require(landed + 1e6 >= seed, "LOOP_SHORT");
        emit LeverageLooped(seed, IERC20E(USDC).balanceOf(landing));
    }

    function idleAndRoom() external view returns (uint256 idle, uint256 room) {
        (uint128 sa,, uint128 ba,,,) = IMorphoE(MORPHO).market(ELE_USDC);
        idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        room = _lltvRoom();
    }

    function _borrowTo(address receiver, uint256 want) internal returns (uint256 borrowed) {
        (uint128 sa,, uint128 ba,,,) = IMorphoE(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle <= 1e6) return 0;
        uint256 maxDraw = idle - 1e6;
        uint256 room = _lltvRoom();
        borrowed = want;
        if (borrowed > maxDraw) borrowed = maxDraw;
        if (borrowed > room) borrowed = room;
        if (borrowed == 0) return 0;
        IMorphoE(MORPHO).borrow(_eleMp(), borrowed, 0, king, receiver);
    }

    function _lltvRoom() internal view returns (uint256 room) {
        (, uint128 borShares, uint128 coll) = IMorphoE(MORPHO).position(ELE_USDC, king);
        (,, uint128 ba, uint128 bs,,) = IMorphoE(MORPHO).market(ELE_USDC);
        uint256 debt = (borShares == 0 || bs == 0)
            ? 0
            : (uint256(ba) * uint256(borShares) + uint256(bs) - 1) / uint256(bs);
        // $1 ELE oracle: coll 8dp → USDC 6dp value = coll/100
        uint256 collUsd = uint256(coll) / 100;
        uint256 maxDebt = (collUsd * LLTV_77) / 1e18;
        room = maxDebt > debt ? maxDebt - debt : 0;
    }

    function _eleMp() internal pure returns (IMorphoE.MarketParams memory) {
        return IMorphoE.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
    }
}
