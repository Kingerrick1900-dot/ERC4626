// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorphoPa {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPublicAllocatorPa {
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

/// @notice PA pull USDC from a named vault WETH book into RSS/$1200. Phase 2 step 2.
/// @dev KING_OK=1. Env: PA_VAULT (default Gauntlet Prime), PULL_USDC (default 700_000e6).
///      Withdraw source defaults to WETH/USDC on Base.
contract PaSeedRss1200 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORACLE_1200 = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    uint256 constant LLTV_WETH = 860000000000000000;
    uint256 constant LLTV_RSS = 770000000000000000;

    address constant STEAKHOUSE = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;

    bytes32 constant MID_1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    error NOT_HOT();
    error NO_GO();
    error MAXIN(uint128 cap);
    error MAXOUT(uint128 cap);

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();

        address paVault = vm.envOr("PA_VAULT", STEAKHOUSE);
        uint256 pullUsdc = vm.envOr("PULL_USDC", uint256(700_000e6));

        (uint128 maxIn,) = IPublicAllocatorPa(PA).flowCaps(paVault, MID_1200);
        (, uint128 maxOut) = IPublicAllocatorPa(PA).flowCaps(paVault, MID_WETH);
        if (uint256(maxIn) < pullUsdc) revert MAXIN(maxIn);
        if (uint256(maxOut) < pullUsdc) revert MAXOUT(maxOut);

        (uint128 s0,, uint128 b0,,,) = IMorphoPa(MORPHO).market(MID_1200);
        uint256 idle0 = uint256(s0) > uint256(b0) ? uint256(s0) - uint256(b0) : 0;
        console2.log("idleBefore", idle0);
        console2.log("pullUsdc", pullUsdc);
        console2.log("paVault", paVault);

        IPublicAllocatorPa.Withdrawal[] memory withdrawals = new IPublicAllocatorPa.Withdrawal[](1);
        withdrawals[0] = IPublicAllocatorPa.Withdrawal({
            marketParams: IPublicAllocatorPa.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_WETH),
            amount: uint128(pullUsdc)
        });

        vm.startBroadcast(pk);
        uint256 fee = IPublicAllocatorPa(PA).fee(paVault);
        IPublicAllocatorPa(PA).reallocateTo{value: fee}(
            paVault,
            withdrawals,
            IPublicAllocatorPa.MarketParams(USDC, RSS, ORACLE_1200, IRM, LLTV_RSS)
        );
        vm.stopBroadcast();

        (uint128 s1,, uint128 b1,,,) = IMorphoPa(MORPHO).market(MID_1200);
        uint256 idle1 = uint256(s1) > uint256(b1) ? uint256(s1) - uint256(b1) : 0;
        console2.log("idleAfter", idle1);
        console2.log("PA_SEED_RSS1200_OK", uint256(1));
    }

    bytes32 internal constant MID_WETH = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
}
