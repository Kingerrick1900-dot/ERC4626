// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoP {
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
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IYeleP {
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
    function totalAssets() external view returns (uint256);
    function isAllocator(address) external view returns (bool);
}

/// @notice Fill the kingdom pot — Morpho flash USDC → yELE-K → ELE Blue → borrow repay flash.
/// @dev Keyrock pattern: own vault holds the working USDC (Morpho supply). No foreign curator.
///      Net: vault TVL = `ask`, king debt += `ask`, Landing unchanged (flash repaid).
///      Optional skim: any dust idle after open → Landing.
contract CrownPotFill {
    using ZkKingGate for IZkGateBook;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;

    IZkGateBook public immutable gate;
    address public immutable king;
    address public immutable landing;
    address public immutable vault;

    bool private locking;

    event PotFilled(uint256 ask, uint256 vaultAssets, uint256 landDust);

    constructor(address king_, address landing_, address vault_) {
        gate = IZkGateBook(GATE);
        king = king_;
        landing = landing_;
        vault = vault_ == address(0) ? YELE_K : vault_;
    }

    /// @notice Fill pot with `ask` USDC via Morpho flash (system float — not waiting on users).
    function fill(uint256 ask) external {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        require(ask > 0, "ASK");
        require(IYeleP(vault).isAllocator(address(this)) || IYeleP(vault).isAllocator(king), "ALLOC");

        locking = true;
        IMorphoP(MORPHO).flashLoan(USDC, ask, abi.encode(ask));
        locking = false;

        // Skim any dust idle left on ELE Blue → Landing
        uint256 dust = _skimDust();
        emit PotFilled(ask, IYeleP(vault).totalAssets(), dust);
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO && locking, "CB");
        uint256 ask = abi.decode(data, (uint256));
        require(assets == ask, "AMT");

        // 1) Deposit into kingdom vault (supply queue → WETH market)
        IERC20P(USDC).approve(vault, assets);
        IYeleP(vault).deposit(assets, king);

        // 2) Curator realloc WETH → ELE/USDC Blue (pot sits in Morpho earning)
        IYeleP.MarketAllocation[] memory allocs = new IYeleP.MarketAllocation[](2);
        allocs[0] = IYeleP.MarketAllocation({
            marketParams: IYeleP.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86),
            assets: 1
        });
        allocs[1] = IYeleP.MarketAllocation({
            marketParams: IYeleP.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77),
            assets: type(uint256).max
        });
        IYeleP(vault).reallocate(allocs);

        // 3) Borrow the same USDC against king's ELE engine → repay flash
        IMorphoP.MarketParams memory mp = IMorphoP.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMorphoP(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorphoP(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        require(idle >= assets, "NO_IDLE");
        IMorphoP(MORPHO).borrow(mp, assets, 0, king, address(this));

        // 4) Repay flash
        IERC20P(USDC).approve(MORPHO, assets);
    }

    function _skimDust() internal returns (uint256 drawn) {
        IMorphoP.MarketParams memory mp = IMorphoP.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMorphoP(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorphoP(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle <= 1e6) return 0;
        drawn = idle - 1e6;
        IMorphoP(MORPHO).borrow(mp, drawn, 0, king, landing);
    }
}
