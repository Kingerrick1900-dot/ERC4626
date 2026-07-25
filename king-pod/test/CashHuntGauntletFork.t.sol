// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IMorphoC {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function owner() external view returns (address);
    function curator() external view returns (address);
    function timelock() external view returns (uint256);
    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setIsAllocator(address, bool) external;
    function config(bytes32) external view returns (uint184, bool, uint64);
}

interface IPac {
    struct FlowCaps {
        uint128 maxIn;
        uint128 maxOut;
    }

    struct FlowCapsConfig {
        bytes32 id;
        FlowCaps caps;
    }

    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
    function flowCaps(address vault, bytes32 id) external view returns (uint128, uint128);
    function fee(address vault) external view returns (uint256);
}

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Prove the cash hunt: Gauntlet already holds WETH/USDC supply — open ELE door → Landing $700k.
contract CashHuntGauntletForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant EXTRACTOR = 0x3734658F1b86bD0EE86b5ac15015fE98B7Ad8947;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant ASK = 700_000e6;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_86 = 860000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_gauntlet_weth_cash_to_landing_700k() public {
        (uint256 gShares,,) = IMorphoC(MORPHO).position(WETH_USDC, GAUNTLET);
        require(gShares > 0, "no gauntlet weth cash");
        console2.log("gauntletWethShares", gShares);

        _openGauntletEleDoor(ASK);
        // Timelock warp ages the live ZK attestation; keep king proven for the raise.
        vm.mockCall(address(0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30), abi.encodeWithSignature("isProven(address)", HOT), abi.encode(true));

        uint256 landBefore = IERC20C(USDC).balanceOf(LAND);
        (uint128 sa0,, uint128 ba0,,,) = IMorphoC(MORPHO).market(ELE_USDC);
        uint256 idle0 = uint256(sa0) > uint256(ba0) ? uint256(sa0) - uint256(ba0) : 0;

        vm.startPrank(HOT);
        CrownLeverageExtractor x = EXTRACTOR.code.length > 0
            ? CrownLeverageExtractor(payable(EXTRACTOR))
            : new CrownLeverageExtractor(HOT, LAND);
        if (!IMorphoC(MORPHO).isAuthorized(HOT, address(x))) {
            IMorphoC(MORPHO).setAuthorization(address(x), true);
        }
        uint256 fee = IPac(PA).fee(GAUNTLET);
        vm.deal(HOT, fee + 0.01 ether);
        x.reallocateAndBorrow{value: fee}(GAUNTLET, x.wethUsdcParams(), uint128(ASK), 0);
        vm.stopPrank();

        uint256 landAfter = IERC20C(USDC).balanceOf(LAND);
        (uint128 sa1,, uint128 ba1,,,) = IMorphoC(MORPHO).market(ELE_USDC);
        uint256 idle1 = uint256(sa1) > uint256(ba1) ? uint256(sa1) - uint256(ba1) : 0;
        uint256 landed = landAfter > landBefore ? landAfter - landBefore : 0;
        console2.log("idleBefore", idle0);
        console2.log("idleAfter", idle1);
        console2.log("landed", landed);
        assertGe(landed, ASK - 1e6, "cash");
    }

    function _openGauntletEleDoor(uint256 flow) internal {
        address owner = IMetaC(GAUNTLET).owner();
        address curator = IMetaC(GAUNTLET).curator();
        IMetaC.MarketParams memory eleMp =
            IMetaC.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);

        vm.prank(curator);
        IMetaC(GAUNTLET).submitCap(eleMp, 50_000_000e6);
        vm.warp(block.timestamp + IMetaC(GAUNTLET).timelock() + 1);
        IMetaC(GAUNTLET).acceptCap(eleMp);

        (, bool on,) = IMetaC(GAUNTLET).config(ELE_USDC);
        require(on, "ele off");

        IPac.FlowCapsConfig[] memory caps = new IPac.FlowCapsConfig[](2);
        caps[0] = IPac.FlowCapsConfig({
            id: WETH_USDC, caps: IPac.FlowCaps({maxIn: 0, maxOut: uint128(flow)})
        });
        caps[1] = IPac.FlowCapsConfig({
            id: ELE_USDC, caps: IPac.FlowCaps({maxIn: uint128(flow), maxOut: 0})
        });
        // PA setFlowCaps: vault owner (or PA admin). Try owner first.
        vm.prank(owner);
        IPac(PA).setFlowCaps(GAUNTLET, caps);

        (uint128 maxIn,) = IPac(PA).flowCaps(GAUNTLET, ELE_USDC);
        (, uint128 maxOut) = IPac(PA).flowCaps(GAUNTLET, WETH_USDC);
        require(maxIn >= flow && maxOut >= flow, "caps");
    }
}
