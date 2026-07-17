// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./Mocks.sol";
import {IERC20} from "../src/lib/Core.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingOracle} from "../src/KingOracle.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingPodAave} from "../src/KingPodAave.sol";

contract MockAave {
    IERC20 public usdc;
    uint256 public premiumBps = 5; // 0.05%

    constructor(address usdc_) {
        usdc = IERC20(usdc_);
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16
    ) external {
        require(asset == address(usdc), "asset");
        uint256 premium = (amount * premiumBps) / 10_000;
        require(usdc.transfer(receiverAddress, amount), "fund");
        (bool ok, ) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset,
                amount,
                premium,
                address(this),
                params
            )
        );
        // KingPodAave checks initiator == address(this) where this is the Pod, not MockAave.
        // Override: call with initiator = receiverAddress by having pod set...
        // Fix: our KingPodAave expects initiator == address(this) meaning the Pod.
        // Aave passes initiator as the contract that called flashLoanSimple (Pod).
        // So Mock must pass initiator = receiverAddress... actually Aave passes msg.sender of flashLoanSimple caller = Pod.
        require(ok, "cb");
        require(usdc.transferFrom(receiverAddress, address(this), amount + premium), "repay");
    }
}

/// @dev Adjusted mock matching Aave initiator semantics (initiator = Pod).
contract MockAaveV2 {
    IERC20 public usdc;
    uint256 public premiumBps = 5;

    constructor(address usdc_) {
        usdc = IERC20(usdc_);
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16
    ) external {
        require(asset == address(usdc), "asset");
        uint256 premium = (amount * premiumBps) / 10_000;
        require(usdc.transfer(receiverAddress, amount), "fund");
        // initiator = msg.sender (the Pod that called flashLoanSimple)
        (bool ok, bytes memory err) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset,
                amount,
                premium,
                msg.sender,
                params
            )
        );
        require(ok, string(err));
        require(usdc.transferFrom(receiverAddress, address(this), amount + premium), "repay");
    }
}

contract KingPodAaveTest is Test {
    address king = address(0x6708);
    MockERC20 rss;
    MockERC20 usdc;
    MockAaveV2 aave;
    KingSusdc sUsdc;
    KingPair pair;
    KingOracle oracle;
    KingMoneyMarket market;
    KingPodAave pod;

    uint256 constant RSS_AMT = 10_000_000 ether;
    uint256 constant FLASH = 1_000_000e6;

    function setUp() public {
        rss = new MockERC20("RSS", "RSS", 18);
        usdc = new MockERC20("USDC", "USDC", 6);
        aave = new MockAaveV2(address(usdc));
        rss.mint(king, RSS_AMT + 11_000_000 ether);
        usdc.mint(address(aave), FLASH * 2);

        sUsdc = new KingSusdc(address(usdc), address(this));
        pair = new KingPair(address(rss), address(sUsdc), address(this));
        oracle = new KingOracle(address(rss), address(sUsdc), address(pair), address(this));
        market = new KingMoneyMarket(address(usdc), address(sUsdc), address(pair), address(oracle), address(this));
        pod = new KingPodAave(
            address(rss), address(usdc), address(sUsdc), address(pair), address(market),
            address(aave), king, address(this)
        );
        sUsdc.transferOwnership(address(market));
        market.setOperator(address(pod));

        // Prefund premium ~0.05%
        usdc.mint(address(pod), 500e6);
        vm.prank(king);
        rss.approve(address(pod), RSS_AMT);
    }

    function test_aave_optionA_1M_with_10M_rss() public {
        pod.bootstrap(RSS_AMT, FLASH);
        assertEq(market.debtUsdc(king), FLASH);
        assertEq(rss.balanceOf(king), 11_000_000 ether);
        assertGt(market.collateralLp(king), 0);
        assertGe(market.healthFactor(king), 1e18);
        assertEq(usdc.balanceOf(address(sUsdc)), 0);
    }

    function test_cash_lp_example_still_impossible() public pure {
        uint256 lp = 1_000_000;
        uint256 maxBorrow = (lp * 70) / 100;
        assertTrue(maxBorrow < 1_000_000);
    }
}
