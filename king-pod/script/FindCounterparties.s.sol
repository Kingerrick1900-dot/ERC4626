// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IPAF {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IMorphoF {
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IZkF {
    function maxBorrow(address) external view returns (uint256);
    function isProven(address) external view returns (bool);
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Automated counterparty fanout — every live rail, not one option.
/// @dev No broadcast. Prints rails + readiness for keepers / counterparties.
contract FindCounterparties is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    bytes32 constant ELE = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant STEAK_PRIME = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant MOONWELL = 0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;
    address constant SPARK = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;
    address constant YEARN = 0xef417a2512C5a41f69AE4e021648b69a7CdE5D03;
    address constant GAUNTLET_CORE = 0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;

    function run() external view {
        console2.log("=== RAIL A: ZK CREDIT (permissionless supply) ===");
        console2.log("credit", CREDIT);
        console2.log("proven", IZkF(GATE).isProven(HOT) ? uint256(1) : uint256(0));
        console2.log("creditUsdc", IERC20F(USDC).balanceOf(CREDIT));
        console2.log("maxBorrow", IZkF(CREDIT).maxBorrow(HOT));
        console2.log("landing", LANDING);
        console2.log("supplyCalldata_500k_prefix", uint256(0x35403023));
        console2.log("askUsdcRaw", uint256(500000000000));

        console2.log("=== RAIL B: MORPHO PA CURATORS (ELE market) ===");
        _cap("GauntletPrime", GAUNTLET);
        _cap("SteakPrime", STEAK_PRIME);
        _cap("Steak", STEAK);
        _cap("Moonwell", MOONWELL);
        _cap("Spark", SPARK);
        _cap("YearnOG", YEARN);
        _cap("GauntletCore", GAUNTLET_CORE);
        _cap("yELE", YELE);

        (uint128 sa,, uint128 ba,,,) = IMorphoF(MORPHO).market(ELE);
        console2.log("=== RAIL C: ELE MARKET IDLE ===");
        console2.log("idleUsdc", uint256(sa) - uint256(ba));
        console2.log("FIRE_BORROW_IF_IDLE_GT_0", (uint256(sa) - uint256(ba)) > 0 ? uint256(1) : uint256(0));

        console2.log("=== RAIL D: yELE DISTRIBUTION (Coinbase-style mullet) ===");
        console2.log("yele", YELE);
        console2.log("deposit USDC to vault to ELE market depth to borrow headroom");

        console2.log("COUNTERPARTY_FANOUT_OK", uint256(1));
    }

    function _cap(string memory name, address vault) internal view {
        (uint128 maxIn, uint128 maxOut) = IPAF(PA).flowCaps(vault, ELE);
        console2.log(name, vault);
        console2.log("  maxIn", uint256(maxIn));
        console2.log("  maxOut", uint256(maxOut));
        console2.log("  READY_IF_MAXIN_GT_0", maxIn > 0 ? uint256(1) : uint256(0));
    }
}
