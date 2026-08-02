// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IVault {
    function balanceOf(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}

contract NavDonateForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV = 770000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function _mp() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
    }

    /// @dev "Resolv loophole" on matched yELE-K: inflate NAV, withdraw idle = flash body, net ops ≈ 0.
    function test_nav_donate_nets_zero() public {
        uint256 shares = IVault(YELE_K).balanceOf(HOT);
        uint256 ta0 = IVault(YELE_K).totalAssets();
        assertGt(shares, 0);

        uint256 flash = ta0;
        address donor = makeAddr("donor");
        deal(USDC, donor, flash);

        vm.startPrank(donor);
        IERC20(USDC).approve(MORPHO, flash);
        IMorpho(MORPHO).supply(_mp(), flash, 0, YELE_K, "");
        vm.stopPrank();

        (uint128 sa,, uint128 ba,,,) = IMorpho(MORPHO).market(ELE77);
        uint256 idle = uint256(sa) - uint256(ba);
        console2.log("idle_after_donate", idle);

        vm.startPrank(HOT);
        vm.expectRevert();
        IVault(YELE_K).redeem(shares, HOT, HOT);

        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);
        uint256 take = idle - 1e6;
        IVault(YELE_K).withdraw(take, HOT, HOT);
        uint256 gained = IERC20(USDC).balanceOf(HOT) - usdc0;
        int256 net = int256(gained) - int256(flash);
        console2.log("gained", gained);
        console2.log("net_after_flash_repay");
        console2.logInt(net);
        assertLe(net, int256(1e6));
        assertGe(net, -int256(2e6));
        vm.stopPrank();
    }

    /// @dev Real share clear: repay king debt with flash → redeem → repay flash ≈ net 0, shares gone.
    function test_repay_debt_then_redeem_clears_shares() public {
        uint256 shares = IVault(YELE_K).balanceOf(HOT);
        uint256 assets = IVault(YELE_K).convertToAssets(shares);
        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);

        address flasher = makeAddr("flasher");
        deal(USDC, flasher, assets);

        vm.startPrank(flasher);
        IERC20(USDC).approve(MORPHO, assets);
        IMorpho(MORPHO).repay(_mp(), assets, 0, HOT, "");
        vm.stopPrank();

        vm.startPrank(HOT);
        uint256 out = IVault(YELE_K).redeem(shares, HOT, HOT);
        vm.stopPrank();

        uint256 gained = IERC20(USDC).balanceOf(HOT) - usdc0;
        int256 net = int256(gained) - int256(assets);
        console2.log("redeem_out", out);
        console2.log("net_after_flash_repay");
        console2.logInt(net);
        assertEq(IVault(YELE_K).balanceOf(HOT), 0, "shares cleared");
        assertLe(net, int256(1e6));
        assertGe(net, -int256(5e6));
    }
}
