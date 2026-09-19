// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";

interface IMorphoWithdraw {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external;
}

/// @dev Pull liquid RSS off Morpho while respecting HF floor. Env: RSS_WITHDRAW (0 = max safe).
contract WithdrawMorphoRss is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant LLTV = 770000000000000000;
    uint256 constant HF_FLOOR = 1005000000000000000; // 1.005

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        uint256 withdrawAmt = vm.envOr("RSS_WITHDRAW", uint256(0));

        IMorphoWithdraw morpho = IMorphoWithdraw(MORPHO);
        IMorphoWithdraw.MarketParams memory params = IMorphoWithdraw.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        bytes32 marketId = keccak256(abi.encode(params));
        (,, uint128 collateral) = IMorpho(MORPHO).position(marketId, KING);
        require(collateral > 0, "NO_COLL");

        if (withdrawAmt == 0) {
            withdrawAmt = _maxWithdraw(collateral);
        }
        require(withdrawAmt > 0 && withdrawAmt <= collateral, "AMT");

        console2.log("collateral", uint256(collateral));
        console2.log("withdraw", withdrawAmt);

        vm.startBroadcast(pk);
        morpho.withdrawCollateral(params, withdrawAmt, KING, KING);
        vm.stopBroadcast();

        console2.log("kingRss", IERC20(RSS).balanceOf(KING));
    }

    function _maxWithdraw(uint128 collateral) internal view returns (uint256) {
        (bool ok, bytes memory data) = ORACLE.staticcall(abi.encodeWithSignature("price()"));
        require(ok && data.length >= 32, "ORACLE");
        uint256 px = abi.decode(data, (uint256));

        bytes32 marketId = keccak256(
            abi.encode(USDC, RSS, ORACLE, IRM, LLTV)
        );
        (, uint128 borrowShares,) = IMorpho(MORPHO).position(marketId, KING);
        if (borrowShares == 0) return collateral;

        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = IMorpho(MORPHO).market(marketId);
        uint256 borrowAssets =
            (uint256(borrowShares) * uint256(totalBorrowAssets) + uint256(totalBorrowShares) - 1) / uint256(totalBorrowShares);

        // Binary search max withdraw keeping HF >= floor
        uint256 lo = 0;
        uint256 hi = collateral;
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 rem = uint256(collateral) - mid;
            uint256 collValue = (rem * px) / 1e36;
            uint256 maxBorrow = (collValue * LLTV) / 1e18;
            uint256 hf = (maxBorrow * 1e18) / borrowAssets;
            if (hf >= HF_FLOOR) lo = mid;
            else hi = mid - 1;
        }
        return lo;
    }
}

interface IMorpho {
    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}
