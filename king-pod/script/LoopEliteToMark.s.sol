// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20L {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IDeskL {
    function seed(uint256 usdcAmount) external;
}

interface IFlashCloserL {
    function eliteFlashClose(uint256 rssCollateral, uint256 borrowUsdc, uint256 rssForFill) external;
}

interface IMorphoL {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

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

    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
}

/// @notice Loop the proven $2 elite-flash pattern until vault hits mark or rails are dry.
/// @dev Each iteration: harvest Morpho leftover → seed desk with all King USDC → fire flash close.
///      Vault grows by exactly the USDC that was on the rails that round.
///      Re-run anytime new USDC hits King — loop keeps stacking toward $700k.
contract LoopEliteToMark is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant DESK = 0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF;
    address constant CLOSER = 0x2192251a8FD4a31843fDE1222C43Ac0ad64ccD25;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant MARK = 700_000e6;
    uint256 constant MIN_SHOT = 1e5; // $0.10 floor — same pattern as $2 test
    uint256 constant PRICE = 50_000; // $0.05 / RSS
    uint256 constant MAX_LOOPS = 50;

    function run() external {
        uint256 vault = IERC20L(USDC).balanceOf(VAULT);
        console2.log("loop start vault", vault);
        console2.log("mark", MARK);

        vm.startBroadcast();

        // Ensure closer can pull RSS.
        if (IERC20L(RSS).allowance(KING, CLOSER) < type(uint256).max / 2) {
            IERC20L(RSS).approve(CLOSER, type(uint256).max);
        }

        uint256 loops;
        while (loops < MAX_LOOPS) {
            vault = IERC20L(USDC).balanceOf(VAULT);
            if (vault >= MARK) {
                console2.log("MARK HIT", vault);
                break;
            }

            _harvestMorpho();

            uint256 fuel = IERC20L(USDC).balanceOf(KING);
            uint256 deskBal = IERC20L(USDC).balanceOf(DESK);
            // Prefer seeding King balance; desk may already hold inventory.
            if (fuel >= MIN_SHOT) {
                IERC20L(USDC).approve(DESK, fuel);
                IDeskL(DESK).seed(fuel);
                deskBal = IERC20L(USDC).balanceOf(DESK);
            }

            if (deskBal < MIN_SHOT) {
                console2.log("RAILS_DRY desk", deskBal);
                console2.log("vault", vault);
                console2.log("loops_fired", loops);
                console2.log("rails dry - reload desk USDC and re-run");
                break;
            }

            uint256 B = deskBal;
            uint256 rssFill = (B * 1e18) / PRICE;
            uint256 rssColl = (rssFill * 100) / 70;

            uint256 rssBal = IERC20L(RSS).balanceOf(KING);
            if (rssBal < rssColl) {
                console2.log("RSS_SHORT have", rssBal, "need", rssColl);
                break;
            }

            console2.log("fire loop", loops + 1);
            console2.log("shot USDC", B);
            IFlashCloserL(CLOSER).eliteFlashClose(rssColl, B, rssFill);

            vault = IERC20L(USDC).balanceOf(VAULT);
            console2.log("vault after", vault);
            loops++;
        }

        vm.stopBroadcast();
        console2.log("loop done vault", IERC20L(USDC).balanceOf(VAULT));
        console2.log("loops", loops);
    }

    function _harvestMorpho() internal {
        (uint256 shares,,) = IMorphoL(MORPHO).position(MARKET_ID, KING);
        if (shares == 0) return;
        (uint128 supplyAssets, uint128 supplyShares,,,,) = IMorphoL(MORPHO).market(MARKET_ID);
        if (supplyShares == 0 || supplyAssets == 0) return;

        IMorphoL.MarketParams memory p = IMorphoL.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: 770000000000000000
        });
        IMorphoL(MORPHO).withdraw(p, 0, shares, KING, KING);
        console2.log("harvested Morpho shares", shares);
    }
}
