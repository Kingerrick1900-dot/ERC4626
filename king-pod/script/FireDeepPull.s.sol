// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDeepPull} from "../src/CrownDeepPull.sol";

interface IERC20D {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IEusdMint {
    function setMinter(address, bool) external;
    function isMinter(address) external view returns (bool);
    function mint(address, uint256) external;
}

interface IUniPoolD {
    function slot0()
        external
        view
        returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
    function tickSpacing() external view returns (int24);
}

/// @notice Deploy CrownDeepPull, grant minter, seed Uni V3 eUSD/USDC with Kingdom USDC + minted eUSD.
/// @dev KING_OK=1 FIRE_DEEP_PULL=1
contract FireDeepPull is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant BALANCER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant POOL = 0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666; // fee 500
    uint24 constant FEE = 500;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_DEEP_PULL", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 usdcBal = IERC20D(USDC).balanceOf(HOT);
        uint256 yrssBal = IERC20D(YRSS).balanceOf(HOT);
        require(yrssBal > 0, "NO_YRSS");
        require(usdcBal > 0, "NO_USDC");

        (, int24 tick,,,,,) = IUniPoolD(POOL).slot0();
        int24 spacing = IUniPoolD(POOL).tickSpacing();
        // Full-range-ish around current tick (± full practical band for spacing 10)
        int24 tickLower = -887200; // nearest below max range for spacing 10
        int24 tickUpper = 887200;
        tickLower = (tickLower / spacing) * spacing;
        tickUpper = (tickUpper / spacing) * spacing;
        if (tickLower >= tickUpper) {
            tickLower = ((tick / spacing) - 1000) * spacing;
            tickUpper = ((tick / spacing) + 1000) * spacing;
        }

        // Match eUSD notional ~ USDC (both $1)
        uint256 usdcAmt = usdcBal;
        uint256 eusdAmt = usdcAmt * 1e12; // 6dp → 18dp

        vm.startBroadcast(pk);

        CrownDeepPull pull = new CrownDeepPull(
            BALANCER, NPM, EUSD, USDC, YRSS, HOT, POOL, FEE, 1, HOT
        );

        if (!IEusdMint(EUSD).isMinter(address(pull))) {
            IEusdMint(EUSD).setMinter(address(pull), true);
        }

        IERC20D(USDC).approve(address(pull), usdcAmt);
        uint256 tokenId = pull.seed(usdcAmt, eusdAmt, tickLower, tickUpper);

        vm.stopBroadcast();

        console2.log("CrownDeepPull", address(pull));
        console2.log("tokenId", tokenId);
        console2.log("usdcSeeded", usdcAmt);
        console2.log("eusdMinted", eusdAmt);
        console2.log("poolUsdc", IERC20D(USDC).balanceOf(POOL));
        console2.log("DEEP_PULL_FIRED", uint256(1));
    }
}
