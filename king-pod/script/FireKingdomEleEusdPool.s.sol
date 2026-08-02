// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";

interface IERC20K {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IZkK {
    function isProven(address) external view returns (bool);
}

interface INonfungiblePositionManagerK {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

/// @notice Create REAL ELE/eUSD pool from kingdom ELE only.
/// @dev Deploys CDP with treasury=HOT so mint proceeds can LP (Landing has no signer).
///      KING_GO=1 FIRE_KINGDOM_POOL=1
contract FireKingdomEleEusdPool is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ZK = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    uint24 constant FEE = 3000;
    uint160 constant SQRT_PRICE_X96 = 7922816251426433759354395033600000;
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;

    uint256 constant LR = 1.5e18;
    uint256 constant FLOOR = 1.55e18;
    uint256 constant FEE_BPS = 500;

    uint256 constant DEFAULT_MINT = 500_000e18;
    uint256 constant DEFAULT_LP_ELE = 500_000e8;
    uint256 constant DEFAULT_CDP_ELE = 1_000_000e8;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_KINGDOM_POOL", uint256(0)) == 1, "NEED FIRE_KINGDOM_POOL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(IZkK(ZK).isProven(HOT), "ZK");
        require(ELE < EUSD, "ORDER");

        uint256 mintAmt = vm.envOr("MINT_EUSD", DEFAULT_MINT);
        uint256 lpEle = vm.envOr("LP_ELE", DEFAULT_LP_ELE);
        uint256 cdpEle = vm.envOr("CDP_ELE", DEFAULT_CDP_ELE);
        require(mintAmt >= 100_000e18 && lpEle >= 100_000e8, "SIZE");
        require(IERC20K(ELE).balanceOf(HOT) >= cdpEle + lpEle, "ELE_SHORT");

        vm.startBroadcast(pk);

        // CDP treasury = HOT so eUSD proceeds are LPable (own inventory loop)
        CrownElepanCdpVault vault = new CrownElepanCdpVault(
            ELE, EUSD, ORACLE, ZK, HOT, LANDING, HOT, LR, FLOOR, FEE_BPS
        );
        CrownElepanUsd(EUSD).setMinter(address(vault), true);
        console2.log("cdp", address(vault));

        IERC20K(ELE).approve(address(vault), cdpEle);
        vault.deposit(cdpEle);
        vault.mint(mintAmt);
        require(vault.healthFactor() >= vault.safetyFloor(), "HF");
        console2.log("hf", vault.healthFactor());
        console2.log("eusdHot", IERC20K(EUSD).balanceOf(HOT));

        address pool = INonfungiblePositionManagerK(NPM).createAndInitializePoolIfNecessary(
            ELE, EUSD, FEE, SQRT_PRICE_X96
        );
        console2.log("pool", pool);

        uint256 eusdBal = IERC20K(EUSD).balanceOf(HOT);
        require(eusdBal >= mintAmt, "EUSD_NOT_ON_HOT");

        IERC20K(ELE).approve(NPM, lpEle);
        IERC20K(EUSD).approve(NPM, mintAmt);

        (uint256 tokenId, uint128 liq, uint256 a0, uint256 a1) = INonfungiblePositionManagerK(NPM).mint(
            INonfungiblePositionManagerK.MintParams({
                token0: ELE,
                token1: EUSD,
                fee: FEE,
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                amount0Desired: lpEle,
                amount1Desired: mintAmt,
                amount0Min: (lpEle * 95) / 100,
                amount1Min: (mintAmt * 95) / 100,
                recipient: HOT,
                deadline: block.timestamp + 600
            })
        );

        vm.stopBroadcast();

        console2.log("tokenId", tokenId);
        console2.log("liquidity", uint256(liq));
        console2.log("amount0", a0);
        console2.log("amount1", a1);
        console2.log("poolEle", IERC20K(ELE).balanceOf(pool));
        console2.log("poolEusd", IERC20K(EUSD).balanceOf(pool));
        require(IERC20K(ELE).balanceOf(pool) >= 100_000e8, "DUST_ELE");
        require(IERC20K(EUSD).balanceOf(pool) >= 100_000e18, "DUST_EUSD");
        console2.log("KINGDOM_ELE_EUSD_POOL_OK", uint256(1));
    }
}
