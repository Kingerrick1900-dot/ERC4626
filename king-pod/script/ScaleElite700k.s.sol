// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IDesk {
    function seed(uint256 usdcAmount) external;
}

interface ICloser {
    function eliteClose(uint256 rssCollateral, uint256 borrowUsdc, uint256 rssForFill) external;
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes calldata data)
        external
        returns (uint256, uint256);
}

/// @notice Load desk + Morpho at $700k, fire elite close → Cake vault.
/// @dev King must hold >= $1.4M USDC before broadcast (700k desk + 700k Morpho liquidity).
contract ScaleElite700k is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant DESK = 0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF;
    address constant CLOSER = 0x7CF0499E68D3444a47f4d85B4325C32475E922D9;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant B = 700_000e6;
    uint256 constant RSS_FILL = 14_000_000 ether; // $700k @ $0.05
    uint256 constant RSS_COLL = 18_200_000 ether; // LLTV buffer

    function run() external {
        uint256 bal = IERC20(USDC).balanceOf(KING);
        require(bal >= 2 * B, "NEED_1_4M_USDC");

        vm.startBroadcast();
        IERC20(USDC).approve(DESK, B);
        IDesk(DESK).seed(B);

        IERC20(USDC).approve(MORPHO, B);
        IMorpho.MarketParams memory p = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: 770000000000000000
        });
        IMorpho(MORPHO).supply(p, B, 0, KING, bytes(""));

        ICloser(CLOSER).eliteClose(RSS_COLL, B, RSS_FILL);
        vm.stopBroadcast();
        console2.log("elite 700k fired to Cake vault");
    }
}
