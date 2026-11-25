// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title KarSniper - Move 3 PublicAllocator rebalancer (thin executor)
/// @notice Calls Morpho PublicAllocator.reallocateTo on a MetaMorpho vault, then
///         optionally borrows idle USDC on the target market to KingVault.
/// @dev Physics: PA only moves liquidity *within* one vault between enabled markets.
///      It cannot siphon foreign Coinbase/Steakhouse idle into yRSS shares.
///      Off-chain KarRebalancer decides amounts; this contract executes.

interface IPublicAllocator {
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
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128 totalSupplyAssets, uint128, uint128 totalBorrowAssets, uint128, uint128, uint256);

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

contract KarSniper {
    address public immutable morpho;
    address public immutable publicAllocator;
    address public immutable vault; // yRSS MetaMorpho
    address public immutable kingVault;
    address public immutable operator; // HOT / KAR key

    error NotOperator();
    error BadFee();
    error NoIdle();

    event Reallocated(address indexed vault, bytes32 indexed supplyMarketId, uint256 pulled);
    event Borrowed(bytes32 indexed marketId, uint256 assets, address receiver);

    constructor(address morpho_, address pa_, address vault_, address kingVault_, address operator_) {
        morpho = morpho_;
        publicAllocator = pa_;
        vault = vault_;
        kingVault = kingVault_;
        operator = operator_;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert NotOperator();
        _;
    }

    /// @notice Elite sniper: IF idle sources >= ask -> PA pull into supply market; optional borrow.
    /// @param withdrawals Sorted by market id ascending (PA requirement).
    /// @param supplyMarketParams Target market (usually RSS/USDC).
    /// @param borrowAssets 0 = reallocate only; else borrow that amount to KingVault (capped by idle).
    function sniper(
        IPublicAllocator.Withdrawal[] calldata withdrawals,
        IPublicAllocator.MarketParams calldata supplyMarketParams,
        uint256 borrowAssets
    ) external payable onlyOperator {
        uint256 need = IPublicAllocator(publicAllocator).fee(vault);
        if (msg.value != need) revert BadFee();

        uint256 pulled;
        for (uint256 i; i < withdrawals.length; ++i) {
            pulled += withdrawals[i].amount;
        }

        IPublicAllocator(publicAllocator).reallocateTo{value: msg.value}(vault, withdrawals, supplyMarketParams);

        bytes32 sid = _id(supplyMarketParams);
        emit Reallocated(vault, sid, pulled);

        if (borrowAssets > 0) {
            (uint128 supply,, uint128 borrow,,,) = IMorpho(morpho).market(sid);
            uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
            if (idle == 0) revert NoIdle();
            if (borrowAssets > idle) borrowAssets = idle;

            IMorpho.MarketParams memory mp = IMorpho.MarketParams({
                loanToken: supplyMarketParams.loanToken,
                collateralToken: supplyMarketParams.collateralToken,
                oracle: supplyMarketParams.oracle,
                irm: supplyMarketParams.irm,
                lltv: supplyMarketParams.lltv
            });
            IMorpho(morpho).borrow(mp, borrowAssets, 0, operator, kingVault);
            emit Borrowed(sid, borrowAssets, kingVault);
        }
    }

    function _id(IPublicAllocator.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p.loanToken, p.collateralToken, p.oracle, p.irm, p.lltv));
    }

    receive() external payable {}
}
