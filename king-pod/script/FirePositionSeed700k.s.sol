// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoSeed {
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
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IPublicAllocatorSeed {
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

interface IERC20Seed {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Position → seed fire. PA pull into RSS (up to $700k), borrow full idle to KingVault.
/// @dev Env: PRIVATE_KEY. Optional: PA_VAULT, WITHDRAW_LOAN, WITHDRAW_COLLATERAL, WITHDRAW_ORACLE,
///      WITHDRAW_IRM, WITHDRAW_LLTV, PULL_USDC (raw). If PULL_USDC=0 or unset, skip PA and borrow idle only.
contract FirePositionSeed700k is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    uint256 constant CAP_700K = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IMorphoSeed.MarketParams memory rssMp = IMorphoSeed.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        uint256 pullUsdc = vm.envOr("PULL_USDC", uint256(0));
        address paVault = vm.envOr("PA_VAULT", address(0));

        uint256 vaultBefore = IERC20Seed(USDC).balanceOf(KING_VAULT);
        (uint128 supplyBefore,, uint128 borrowBefore,,,) = IMorphoSeed(MORPHO).market(MARKET_ID);
        console2.log("position supply", uint256(supplyBefore));
        console2.log("position borrow", uint256(borrowBefore));
        console2.log("vaultBefore", vaultBefore);

        vm.startBroadcast(pk);

        if (pullUsdc > 0) {
            require(paVault != address(0), "PA_VAULT");
            require(pullUsdc <= CAP_700K, "GT_700K");
            (uint128 maxIn,) = IPublicAllocatorSeed(PA).flowCaps(paVault, MARKET_ID);
            require(uint256(maxIn) >= pullUsdc, "MAXIN");

            IPublicAllocatorSeed.MarketParams memory wMp = IPublicAllocatorSeed.MarketParams({
                loanToken: vm.envAddress("WITHDRAW_LOAN"),
                collateralToken: vm.envAddress("WITHDRAW_COLLATERAL"),
                oracle: vm.envAddress("WITHDRAW_ORACLE"),
                irm: vm.envAddress("WITHDRAW_IRM"),
                lltv: vm.envUint("WITHDRAW_LLTV")
            });

            IPublicAllocatorSeed.Withdrawal[] memory withdrawals = new IPublicAllocatorSeed.Withdrawal[](1);
            withdrawals[0] = IPublicAllocatorSeed.Withdrawal({marketParams: wMp, amount: uint128(pullUsdc)});

            uint256 fee = IPublicAllocatorSeed(PA).fee(paVault);
            IPublicAllocatorSeed(PA).reallocateTo{value: fee}(
                paVault,
                withdrawals,
                IPublicAllocatorSeed.MarketParams({
                    loanToken: USDC,
                    collateralToken: RSS,
                    oracle: ORACLE,
                    irm: IRM,
                    lltv: LLTV
                })
            );
            console2.log("pulled", pullUsdc);
        }

        (uint128 supply,, uint128 borrow,,,) = IMorphoSeed(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        console2.log("idle", idle);
        require(idle > 0, "NO_IDLE");

        IMorphoSeed(MORPHO).borrow(rssMp, idle, 0, KING, KING_VAULT);
        vm.stopBroadcast();

        console2.log("vaultAfter", IERC20Seed(USDC).balanceOf(KING_VAULT));
        console2.log("seed out of position");
    }
}
