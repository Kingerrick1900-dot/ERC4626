// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Borrow $700k USDC to Landing IFF Morpho RSS/USDC already has unmatched idle.
/// Reverts IDLE_LT_700K otherwise. No flash. No self-supply.
interface IERC20B {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function accrueInterest(MarketParams memory marketParams) external;
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

contract BorrowIdleToLanding is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant WANT = 700_000e6;
    /// 70% of 14.98M free RSS — enough at $1 oracle / 77% LLTV for $700k.
    uint256 constant RSS_POST = 10_486_000 ether;

    error IDLE_LT_700K(uint256 idle);
    error SCOREBOARD();
    error NOT_HOT();
    error NO_GO();

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();

        IMorphoB morpho = IMorphoB(MORPHO);
        IMorphoB.MarketParams memory mp =
            IMorphoB.MarketParams(USDC, RSS, ORACLE, IRM, LLTV);

        morpho.accrueInterest(mp);
        (uint128 supply,, uint128 borrow,,,) = morpho.market(MID);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        console2.log("idle", idle);
        console2.log("landingBefore", IERC20B(USDC).balanceOf(LANDING));
        if (idle < WANT) revert IDLE_LT_700K(idle);

        vm.startBroadcast(pk);
        (, , uint128 coll) = morpho.position(MID, HOT);
        if (uint256(coll) < RSS_POST) {
            uint256 need = RSS_POST - uint256(coll);
            IERC20B(RSS).approve(MORPHO, need);
            morpho.supplyCollateral(mp, need, HOT, "");
        }
        morpho.borrow(mp, WANT, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 landed = IERC20B(USDC).balanceOf(LANDING);
        console2.log("landingAfter", landed);
        if (landed < WANT) revert SCOREBOARD();
    }
}
