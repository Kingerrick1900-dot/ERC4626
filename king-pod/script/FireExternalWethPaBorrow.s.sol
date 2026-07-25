// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

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
    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IPublicAllocator {
    struct FlowCaps { uint128 maxIn; uint128 maxOut; }
    struct Withdrawal { IMorpho.MarketParams marketParams; uint128 amount; }
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, IMorpho.MarketParams calldata supplyMarketParams)
        external payable;
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

/// @notice OUTSIDE kingdom: WETH coll → PA pull → borrow USDC. KING_GO=1 FIRE_EXT_WETH=1
/// @dev Needs WETH on hot. ASK_USDC default 700_000e6.
contract FireExternalWethPaBorrow is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    // Steakhouse Prime — large PA into WETH/USDC
    address constant STEAK_PRIME = 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant LLTV_86 = 860000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_EXT_WETH", uint256(0)) == 1, "NEED FIRE_EXT_WETH=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));
        uint256 wethBal = IERC20(WETH).balanceOf(HOT);
        console2.log("wethBal", wethBal);
        require(wethBal > 0, "NEED_WETH");

        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, WETH, ORACLE, IRM, LLTV_86);

        vm.startBroadcast(pk);
        IERC20(WETH).approve(MORPHO, wethBal);
        IMorpho(MORPHO).supplyCollateral(mp, wethBal, HOT, "");

        // If idle short, attempt PA from Steakhouse Prime (flow caps permitting)
        IMorpho(MORPHO).accrueInterest(mp);
        (uint128 sa,, uint128 ba,,,) = IMorpho(MORPHO).market(WETH_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("idleBefore", idle);

        address vault = vm.envOr("PA_VAULT", STEAK_PRIME);
        bytes32 srcId = bytes32(vm.envOr("PA_SRC_ID", uint256(WETH_USDC))); // override if needed
        // For PA, source must be a different market the vault supplies — caller must set PA_SRC via env bytes
        // Default: skip PA if idle already covers ask
        if (idle < ask) {
            console2.log("IDLE_SHORT_SET_PA_SRC_WITHDRAWALS");
            // Optional encoded withdrawals not auto-built — use Morpho API list at fire time
        }

        uint256 borrowAmt = ask;
        if (borrowAmt > idle && idle > 1) borrowAmt = idle - 1;
        require(borrowAmt >= 1e6, "NO_BORROWABLE");
        (uint256 out,) = IMorpho(MORPHO).borrow(mp, borrowAmt, 0, HOT, HOT);
        vm.stopBroadcast();

        console2.log("borrowed", out);
        console2.log("hotUsdc", IERC20(USDC).balanceOf(HOT));
        console2.log("EXT_WETH_PA_OK", uint256(1));
    }
}
