// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZkGateBook, ZkKingGate} from "./lib/ZkKingGate.sol";

interface IERC20X {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoX {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IPublicAllocatorX {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Withdrawal {
        MarketParams marketParams;
        uint128 amount;
    }

    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, MarketParams calldata supplyMarketParams)
        external
        payable;

    function fee(address vault) external view returns (uint256);
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IMetaMorphoX {
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
    function isAllocator(address) external view returns (bool);
}

/// @notice King-owned disk fill: move vault USDC into ELE/USDC, borrow → Landing.
/// @dev Prefer curator `reallocate` (no PA flow caps). PA path kept for foreign vaults.
contract CrownLeverageExtractor {
    using ZkKingGate for IZkGateBook;

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
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

    IZkGateBook public immutable gate;
    address public immutable king;
    address public immutable landing;

    event Extracted(uint256 pulled, uint256 borrowed, uint256 landUsdc);

    constructor(address king_, address landing_) {
        gate = IZkGateBook(GATE);
        king = king_;
        landing = landing_;
    }

    function depositCollateral(uint256 amount) external {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        if (amount == 0) amount = IERC20X(ELE).balanceOf(king);
        if (amount == 0) return;
        require(IERC20X(ELE).transferFrom(king, address(this), amount), "ELE");
        IERC20X(ELE).approve(MORPHO, amount);
        IMorphoX(MORPHO).supplyCollateral(_eleMp(), amount, king, "");
    }

    /// @notice Curator disk-fill: yELE.reallocate WETH→ELE, then borrow `amount` → Landing.
    /// @dev Vault must already hold USDC in WETH/USDC (deposit after acceptCap). King must be allocator.
    function curatorDiskFill(uint256 amount) external {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        require(amount > 0, "AMT");
        require(IMetaMorphoX(YELE).isAllocator(address(this)) || IMetaMorphoX(YELE).isAllocator(king), "ALLOC");

        IMorphoX.MarketParams memory eleBlue = _eleMp();
        IMorphoX(MORPHO).accrueInterest(eleBlue);

        IMetaMorphoX.MarketParams memory wethMp =
            IMetaMorphoX.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86);
        IMetaMorphoX.MarketParams memory eleMp =
            IMetaMorphoX.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);

        IMetaMorphoX.MarketAllocation[] memory allocs = new IMetaMorphoX.MarketAllocation[](2);
        // Leave 1 wei on WETH; park the rest into ELE/USDC.
        allocs[0] = IMetaMorphoX.MarketAllocation({marketParams: wethMp, assets: 1});
        allocs[1] = IMetaMorphoX.MarketAllocation({marketParams: eleMp, assets: type(uint256).max});
        IMetaMorphoX(YELE).reallocate(allocs);

        (uint128 sa1,, uint128 ba1,,,) = IMorphoX(MORPHO).market(ELE_USDC);
        uint256 idle1 = uint256(sa1) > uint256(ba1) ? uint256(sa1) - uint256(ba1) : 0;
        // Need liquid idle ≥ ask (+ $1 buffer kept in _borrowIdle).
        require(idle1 >= amount, "NO_DISK");

        uint256 borrowed = _borrowIdle(eleBlue, amount);
        // Allow dust (share rounding) under ask — within $1.
        require(borrowed + 1e6 >= amount, "BORROW_SHORT");
        emit Extracted(amount, borrowed, IERC20X(USDC).balanceOf(landing));
    }

    /// @notice PA path for foreign vaults (or yELE when flow caps + liquid supply allow).
    function reallocateAndBorrow(
        address vault,
        IPublicAllocatorX.MarketParams calldata from,
        uint128 pull,
        uint256 borrowAmt
    ) external payable {
        require(msg.sender == king, "KING");
        gate.requireProven(king);

        IMorphoX.MarketParams memory ele = _eleMp();
        IMorphoX(MORPHO).accrueInterest(ele);

        uint256 pulled;
        if (pull > 0) {
            require(vault != address(0), "VAULT");
            (uint128 maxIn,) = IPublicAllocatorX(PA).flowCaps(vault, ELE_USDC);
            require(uint256(maxIn) >= uint256(pull), "MAXIN");

            (uint128 sa0,, uint128 ba0,,,) = IMorphoX(MORPHO).market(ELE_USDC);
            uint256 idle0 = uint256(sa0) > uint256(ba0) ? uint256(sa0) - uint256(ba0) : 0;

            IPublicAllocatorX.Withdrawal[] memory withdrawals = new IPublicAllocatorX.Withdrawal[](1);
            withdrawals[0] = IPublicAllocatorX.Withdrawal({marketParams: from, amount: pull});

            IPublicAllocatorX.MarketParams memory to = IPublicAllocatorX.MarketParams({
                loanToken: USDC,
                collateralToken: ELE,
                oracle: ORACLE,
                irm: IRM,
                lltv: LLTV_77
            });

            uint256 fee = IPublicAllocatorX(PA).fee(vault);
            IPublicAllocatorX(PA).reallocateTo{value: fee}(vault, withdrawals, to);

            (uint128 sa1,, uint128 ba1,,,) = IMorphoX(MORPHO).market(ELE_USDC);
            uint256 idle1 = uint256(sa1) > uint256(ba1) ? uint256(sa1) - uint256(ba1) : 0;
            require(idle1 >= idle0 + uint256(pull), "PA_NO_LIQ");
            pulled = uint256(pull);
            if (borrowAmt == 0) borrowAmt = pulled;
        }

        uint256 borrowed = _borrowIdle(ele, borrowAmt);
        if (pulled > 0) require(borrowed >= pulled, "BORROW_SHORT");
        emit Extracted(pulled, borrowed, IERC20X(USDC).balanceOf(landing));
    }

    function borrowIdle(uint256 borrowAmt) external {
        require(msg.sender == king, "KING");
        gate.requireProven(king);
        IMorphoX.MarketParams memory ele = _eleMp();
        IMorphoX(MORPHO).accrueInterest(ele);
        uint256 borrowed = _borrowIdle(ele, borrowAmt);
        emit Extracted(0, borrowed, IERC20X(USDC).balanceOf(landing));
    }

    function wethUsdcParams() external pure returns (IPublicAllocatorX.MarketParams memory) {
        return IPublicAllocatorX.MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: WETH_ORACLE,
            irm: IRM,
            lltv: LLTV_86
        });
    }

    function _borrowIdle(IMorphoX.MarketParams memory ele, uint256 borrowAmt) internal returns (uint256 borrowed) {
        (uint128 sa,, uint128 ba,,,) = IMorphoX(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        if (idle <= 1e6) return 0;
        uint256 maxDraw = idle - 1e6;
        borrowed = borrowAmt == 0 || borrowAmt > maxDraw ? maxDraw : borrowAmt;
        if (borrowed == 0) return 0;
        IMorphoX(MORPHO).borrow(ele, borrowed, 0, king, landing);
    }

    function _eleMp() internal pure returns (IMorphoX.MarketParams memory) {
        return IMorphoX.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
    }

    receive() external payable {}
}
