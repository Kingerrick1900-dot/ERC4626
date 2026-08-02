// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IFactory {
    function createMetaMorpho(address, uint256, address, string memory, string memory, bytes32)
        external
        returns (address);
}

interface IMm {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setCurator(address) external;
    function setIsAllocator(address, bool) external;
    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setSupplyQueue(bytes32[] calldata) external;
    function timelock() external view returns (uint256);
    function config(bytes32) external view returns (uint184, bool, uint64);
}

/// @notice Prove: timelock-0 vault enables WETH+ELE instantly — no wait for yELE pendingCap.
contract CreateKingdomMarketForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_timelock0_instant_caps() public {
        vm.startPrank(HOT);
        address vault = IFactory(FACTORY).createMetaMorpho(
            HOT, 0, USDC, "Kingdom Elepan USDC Test", "yELE-KT", bytes32(uint256(0xC0FFEE))
        );
        IMm mm = IMm(vault);
        mm.setCurator(HOT);
        mm.setIsAllocator(HOT, true);
        mm.submitCap(IMm.MarketParams(USDC, WETH, WETH_ORACLE, IRM, 860000000000000000), 50_000_000e6);
        mm.acceptCap(IMm.MarketParams(USDC, WETH, WETH_ORACLE, IRM, 860000000000000000));
        mm.submitCap(IMm.MarketParams(USDC, ELE, ORACLE, IRM, 770000000000000000), 50_000_000e6);
        mm.acceptCap(IMm.MarketParams(USDC, ELE, ORACLE, IRM, 770000000000000000));
        bytes32[] memory q = new bytes32[](2);
        q[0] = WETH_USDC;
        q[1] = ELE_USDC;
        mm.setSupplyQueue(q);
        vm.stopPrank();

        assertEq(mm.timelock(), 0, "tl");
        (, bool wethOn,) = mm.config(WETH_USDC);
        (, bool eleOn,) = mm.config(ELE_USDC);
        assertTrue(wethOn, "weth");
        assertTrue(eleOn, "ele");
        console2.log("vault", vault);
        console2.log("INSTANT_MARKET_OK", uint256(1));
    }
}
