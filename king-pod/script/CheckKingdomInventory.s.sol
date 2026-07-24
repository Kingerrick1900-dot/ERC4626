// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20I {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IMorphoI {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

interface IVaultI {
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
}

interface ICdpI {
    function coll() external view returns (uint256);
    function debt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function maxMintable() external view returns (uint256);
    function maxWithdrawable() external view returns (uint256);
    function liquidatable() external view returns (bool);
    function treasury() external view returns (address);
}

interface IZkGateI {
    function isProven(address) external view returns (bool);
    function minThreshold() external view returns (uint256);
    function attestations(address) external view returns (uint256 value, uint256 ts, uint256 flag);
}

interface IZkCreditI {
    function maxBorrow(address) external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function lltv() external view returns (uint256);
    function landing() external view returns (address);
}

interface IOracleI {
    function price() external view returns (uint256);
}

interface IPAI {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice Read-only inventory: credit lines vs what is actually withdrawable/borrowable.
/// @dev No KING_GO. No broadcast.
contract CheckKingdomInventory is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant CDP = 0x46b1D159b3a2694e7b70F550b7d5dEf6df451174;
    address constant ZK_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant ZK_CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant ELE_ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_ELE = 770000000000000000;

    function run() external view {
        console2.log("=== CASH ===");
        console2.log("hotUsdc", IERC20I(USDC).balanceOf(HOT));
        console2.log("landingUsdc", IERC20I(USDC).balanceOf(LANDING));
        console2.log("hotElepan", IERC20I(ELEPAN).balanceOf(HOT));
        console2.log("landingEusd", IERC20I(EUSD).balanceOf(LANDING));

        console2.log("=== YELE / YRSS ===");
        console2.log("yeleTotalAssets", IVaultI(YELE).totalAssets());
        console2.log("yeleSharesLanding", IVaultI(YELE).balanceOf(LANDING));
        console2.log("yeleMaxWithdrawLanding", IVaultI(YELE).maxWithdraw(LANDING));
        console2.log("yrssTotalAssets", IVaultI(YRSS).totalAssets());
        console2.log("yrssMaxWithdrawLanding", IVaultI(YRSS).maxWithdraw(LANDING));

        (uint128 supplyA,, uint128 borrowA,,,) = IMorphoI(MORPHO).market(ELE_USDC);
        (, uint128 borShares, uint128 coll) = IMorphoI(MORPHO).position(ELE_USDC, HOT);
        uint256 idle = uint256(supplyA) - uint256(borrowA);
        uint256 price = IOracleI(ELE_ORACLE).price();
        uint256 collVal = uint256(coll) * price / 1e36;
        uint256 maxBorrow = collVal * LLTV_ELE / 1e18;
        uint256 headroom = maxBorrow > uint256(borrowA) ? maxBorrow - uint256(borrowA) : 0;

        console2.log("=== MORPHO ELE (King posted coll) ===");
        console2.log("collElepan", uint256(coll));
        console2.log("borrowUsdc", uint256(borrowA));
        console2.log("borrowShares", uint256(borShares));
        console2.log("idleUsdc", idle);
        console2.log("collValueUsdc", collVal);
        console2.log("maxBorrowUsdc", maxBorrow);
        console2.log("unusedCreditUsdc", headroom);
        console2.log("CREDIT_BLOCKED_NO_IDLE", idle == 0 ? uint256(1) : uint256(0));

        (uint128 paIn, uint128 paOut) = IPAI(PA).flowCaps(YELE, ELE_USDC);
        console2.log("yelePaMaxIn", uint256(paIn));
        console2.log("yelePaMaxOut", uint256(paOut));
        (uint128 gIn,) = IPAI(PA).flowCaps(GAUNTLET, ELE_USDC);
        (uint128 sIn,) = IPAI(PA).flowCaps(STEAK, ELE_USDC);
        console2.log("gauntletPaMaxInEle", uint256(gIn));
        console2.log("steakPaMaxInEle", uint256(sIn));

        ICdpI cdp = ICdpI(CDP);
        console2.log("=== CDP (King posted coll) ===");
        console2.log("coll", cdp.coll());
        console2.log("debtEusd", cdp.debt());
        console2.log("hf", cdp.healthFactor());
        console2.log("maxWithdrawableElepan", cdp.maxWithdrawable());
        console2.log("maxMintableEusd", cdp.maxMintable());
        console2.log("liquidatable", cdp.liquidatable() ? uint256(1) : uint256(0));
        console2.log("treasuryIsLanding", cdp.treasury() == LANDING ? uint256(1) : uint256(0));

        IZkGateI gate = IZkGateI(ZK_GATE);
        (uint256 attest,,) = gate.attestations(HOT);
        console2.log("=== ZK ===");
        console2.log("isProven", gate.isProven(HOT) ? uint256(1) : uint256(0));
        console2.log("attestUsd6", attest);
        console2.log("minThresholdUsd6", gate.minThreshold());
        console2.log("creditLltv", IZkCreditI(ZK_CREDIT).lltv());
        console2.log("maxBorrow", IZkCreditI(ZK_CREDIT).maxBorrow(HOT));
        console2.log("creditUsdcBal", IERC20I(USDC).balanceOf(ZK_CREDIT));
        console2.log("creditTotalDebt", IZkCreditI(ZK_CREDIT).totalDebt());
        console2.log("ZK_BLOCKED_NO_POOL", IZkCreditI(ZK_CREDIT).maxBorrow(HOT) == 0 ? uint256(1) : uint256(0));

        console2.log("=== ACCESS NOW (no counterparty) ===");
        console2.log("elepanFromCdpWithdraw", cdp.maxWithdrawable());
        console2.log("eusdFromCdpMint", cdp.maxMintable());
        console2.log("usdcOpsDust", IERC20I(USDC).balanceOf(HOT) + IERC20I(USDC).balanceOf(LANDING));
        console2.log("usdcFromYrss", IVaultI(YRSS).maxWithdraw(LANDING));
        console2.log("usdcFromYele", IVaultI(YELE).maxWithdraw(LANDING));
        console2.log("usdcFromMorphoHeadroom", idle == 0 ? uint256(0) : headroom);
        console2.log("usdcFromZk", IZkCreditI(ZK_CREDIT).maxBorrow(HOT));
    }
}
