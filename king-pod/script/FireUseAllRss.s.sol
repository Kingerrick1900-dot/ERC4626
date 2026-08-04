// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

/// @notice Post ALL free hot RSS as Morpho collateral; borrow any idle USDC → Landing.
/// @dev FIRE_USE_ALL_RSS=1. Prefers $1200 market (MARKET=1200) or OLD $1 book (MARKET=old).
contract FireUseAllRss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    bytes32 constant M1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant MOLD = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        require(vm.envOr("FIRE_USE_ALL_RSS", uint256(0)) == 1, "NEED FIRE_USE_ALL_RSS=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory which = vm.envOr("MARKET", string("1200"));
        bytes32 id = keccak256(bytes(which)) == keccak256(bytes("old")) ? MOLD : M1200;

        (
            address loanToken,
            address collateralToken,
            address oracle,
            address irm,
            uint256 lltv
        ) = IMorphoU(MORPHO).idToMarketParams(id);
        require(collateralToken == RSS && loanToken == USDC, "BAD_MKT");

        IMorphoU.MarketParams memory mp = IMorphoU.MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });

        uint256 freeRss = IERC20U(RSS).balanceOf(HOT);
        require(freeRss > 0, "NO_RSS");

        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoU(MORPHO).market(id);
        uint256 idle = uint256(supplyAssets) > uint256(borrowAssets)
            ? uint256(supplyAssets) - uint256(borrowAssets)
            : 0;

        console2.log("market", uint256(id));
        console2.log("freeRss", freeRss);
        console2.log("idleUsdc", idle);
        console2.log("lltv", lltv);

        vm.startBroadcast(pk);
        require(IERC20U(RSS).approve(MORPHO, freeRss), "APPROVE");
        IMorphoU(MORPHO).supplyCollateral(mp, freeRss, HOT, "");
        console2.log("POSTED_ALL_RSS", freeRss);

        (, uint128 borrowShares, uint128 collAfter) = IMorphoU(MORPHO).position(id, HOT);
        console2.log("collAfter", collAfter);
        console2.log("borrowShares", borrowShares);

        // Borrow every wei of idle to Landing (hard Morpho path — no buyers).
        if (idle > 0) {
            IMorphoU(MORPHO).borrow(mp, idle, 0, HOT, LAND);
            console2.log("BORROWED_USDC_TO_LANDING", idle);
        } else {
            console2.log("IDLE_ZERO_NO_BORROW", uint256(1));
        }

        console2.log("landUsdc", IERC20U(USDC).balanceOf(LAND));
        console2.log("hotRssLeft", IERC20U(RSS).balanceOf(HOT));
        console2.log("USE_ALL_RSS_OK", uint256(1));
        vm.stopBroadcast();
    }
}
