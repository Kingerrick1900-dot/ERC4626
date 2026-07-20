// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20K {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoK {
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
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

interface IPublicAllocatorK {
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

/// @notice Restore King loan: PA pulls USDC into RSS market (no King cash) → post RSS → borrow to wallet.
/// @dev Morpho Public Allocator = just-in-time liquidity (docs.morpho.org/build/borrow/concepts/public-allocator).
///      yRSS already has PA flow caps ~$700k on RSS market (maxIn/maxOut on-chain).
///      Gates: KING_GO=1 FIRE_RESTORE=1
contract FireKingLoanRestore is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    uint256 constant SOFT_LTV_BPS = 7000;
    uint256 constant DEFAULT_PULL = 500_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "hot");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO");
        require(vm.envOr("FIRE_RESTORE", uint256(0)) == 1, "NO-FIRE");

        address kingWallet = vm.envOr("KING_WALLET", LANDING);
        uint256 borrowWanted = vm.envOr("BORROW_USDC", uint256(9_000_000e6));
        uint256 pullUsdc = vm.envOr("PULL_USDC", DEFAULT_PULL);

        IMorphoK.MarketParams memory rssMp = IMorphoK(MORPHO).idToMarketParams(MARKET_ID);

        (uint128 supply0,, uint128 bor0,,,) = IMorphoK(MORPHO).market(MARKET_ID);
        uint256 idle0 = uint256(supply0) > uint256(bor0) ? uint256(supply0) - uint256(bor0) : 0;
        console2.log("idleBefore", idle0);

        vm.startBroadcast(pk);

        // --- FIX "still needs": Public Allocator JIT pull into RSS market ---
        if (idle0 < borrowWanted && pullUsdc > 0) {
            (uint128 maxIn,) = IPublicAllocatorK(PA).flowCaps(YRSS, MARKET_ID);
            if (pullUsdc > maxIn) pullUsdc = maxIn;

            // Default source: cbBTC/USDC (deep book). Override via env if needed.
            address srcColl = vm.envOr(
                "SRC_COLLATERAL",
                address(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf)
            );
            address srcOracle = vm.envOr(
                "SRC_ORACLE",
                address(0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9)
            );
            uint256 srcLltv = vm.envOr("SRC_LLTV", uint256(860000000000000000));

            IPublicAllocatorK.MarketParams memory src = IPublicAllocatorK.MarketParams({
                loanToken: USDC,
                collateralToken: srcColl,
                oracle: srcOracle,
                irm: IRM,
                lltv: srcLltv
            });

            IPublicAllocatorK.Withdrawal[] memory w = new IPublicAllocatorK.Withdrawal[](1);
            w[0] = IPublicAllocatorK.Withdrawal({marketParams: src, amount: uint128(pullUsdc)});

            uint256 paFee = IPublicAllocatorK(PA).fee(YRSS);
            IPublicAllocatorK(PA).reallocateTo{value: paFee}(
                YRSS,
                w,
                IPublicAllocatorK.MarketParams({
                    loanToken: USDC,
                    collateralToken: RSS,
                    oracle: ORACLE,
                    irm: IRM,
                    lltv: LLTV
                })
            );
            console2.log("paPulled", pullUsdc);
        }

        (uint128 supply,, uint128 bor,,,) = IMorphoK(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(bor) ? uint256(supply) - uint256(bor) : 0;
        console2.log("idleAfterPA", idle);

        uint256 rssBal = IERC20K(RSS).balanceOf(HOT);
        uint256 collValue = (rssBal * 1e24) / 1e36; // oracle $1
        uint256 maxBorrow = (collValue * SOFT_LTV_BPS) / 10_000;
        uint256 borrowUsdc = borrowWanted;
        if (borrowUsdc > maxBorrow) borrowUsdc = maxBorrow;
        if (borrowUsdc > idle) borrowUsdc = idle;

        require(borrowUsdc >= 1e6, "NO LIQUIDITY: PA pull or reallocate yRSS first");

        uint256 rssNeeded = (borrowUsdc * 10_000 * 1e36) / (SOFT_LTV_BPS * 1e24);
        if (rssNeeded > rssBal) rssNeeded = rssBal;

        uint256 walletBefore = IERC20K(USDC).balanceOf(kingWallet);

        IERC20K(RSS).approve(MORPHO, rssNeeded);
        IMorphoK(MORPHO).supplyCollateral(rssMp, rssNeeded, HOT, "");
        IMorphoK(MORPHO).borrow(rssMp, borrowUsdc, 0, HOT, kingWallet);

        vm.stopBroadcast();

        uint256 walletAfter = IERC20K(USDC).balanceOf(kingWallet);
        (, uint128 bShares, uint128 coll) = IMorphoK(MORPHO).position(MARKET_ID, HOT);

        console2.log("RESTORE_DONE");
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("walletDelta", walletAfter - walletBefore);
        console2.log("debtShares", uint256(bShares));
        console2.log("rssColl", uint256(coll));
    }
}
