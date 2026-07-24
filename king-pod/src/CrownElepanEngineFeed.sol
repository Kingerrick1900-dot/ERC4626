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

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

/// @notice Re-arm ELE/USDC Morpho loan engine + draw every liquid USDC wei to Landing.
/// @dev 1) Post ELE coll  2) Borrow existing idle → Landing  3) Flash self-seed (Blue) to reopen engine.
///      Self-seed does not mint net USDC; it rebuilds the borrow engine against posted ELE.
contract CrownElepanEngineFeed {
    using ZkKingGate for IZkGateBook;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    IZkGateBook public immutable gate;
    address public immutable king;
    address public immutable landing;

    bool private locking;

    event Fed(uint256 elePosted, uint256 idleDrawn, uint256 engineAsk, uint256 landUsdc);

    constructor(address king_, address landing_) {
        gate = IZkGateBook(GATE);
        king = king_;
        landing = landing_;
    }

    /// @param eleAmount ELE to post (0 = all free on king).
    /// @param engineAsk USDC flash/seed size (6dp). 0 = skip engine reopen.
    function feed(uint256 eleAmount, uint256 engineAsk) external {
        require(msg.sender == king, "KING");
        gate.requireProven(king);

        IMorphoE.MarketParams memory mp = IMorphoE.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IMorphoE(MORPHO).accrueInterest(mp);

        if (eleAmount == 0) eleAmount = IERC20E(ELE).balanceOf(king);
        if (eleAmount > 0) {
            require(IERC20E(ELE).transferFrom(king, address(this), eleAmount), "ELE");
            IERC20E(ELE).approve(MORPHO, eleAmount);
            IMorphoE(MORPHO).supplyCollateral(mp, eleAmount, king, "");
        }

        // Extract every liquid wei sitting in the market against posted coll.
        uint256 drawn = _drawIdle(mp);

        // Re-arm engine: flash → Blue supply → borrow → repay (matched book).
        if (engineAsk > 0) {
            locking = true;
            IMorphoE(MORPHO).flashLoan(USDC, engineAsk, abi.encode(engineAsk));
            locking = false;
            // Dust idle after open (prior leftover / rounding) → Landing
            drawn += _drawIdle(mp);
        }

        // Sweep any USDC on this contract + pull king's wallet dust to Landing.
        uint256 here = IERC20E(USDC).balanceOf(address(this));
        if (here > 0) require(IERC20E(USDC).transfer(landing, here), "LAND");
        uint256 kingUsdc = IERC20E(USDC).balanceOf(king);
        if (kingUsdc > 0) {
            require(IERC20E(USDC).transferFrom(king, landing, kingUsdc), "HOT_USDC");
        }

        emit Fed(eleAmount, drawn, engineAsk, IERC20E(USDC).balanceOf(landing));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO && locking, "CB");
        uint256 ask = abi.decode(data, (uint256));
        require(assets == ask, "AMT");

        IMorphoE.MarketParams memory mp = IMorphoE.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IERC20E(USDC).approve(MORPHO, assets);
        IMorphoE(MORPHO).supply(mp, assets, 0, king, "");

        (uint128 sa,, uint128 ba,,,) = IMorphoE(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        require(idle >= assets, "NO_IDLE");

        IMorphoE(MORPHO).borrow(mp, assets, 0, king, address(this));
        IERC20E(USDC).approve(MORPHO, assets);
    }

    function _drawIdle(IMorphoE.MarketParams memory mp) internal returns (uint256 drawn) {
        (uint128 sa,, uint128 ba,,,) = IMorphoE(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle <= 1e6) return 0; // keep $1 buffer
        drawn = idle - 1e6;
        IMorphoE(MORPHO).borrow(mp, drawn, 0, king, landing);
    }
}
