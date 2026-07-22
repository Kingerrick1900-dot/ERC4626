// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFixedElepanLoanOracle} from "../src/MorphoFixedElepanLoanOracle.sol";
import {CrownElepanFatFlashSeed} from "../src/CrownElepanFatFlashSeed.sol";

interface IMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20E {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IMetaMorphoFactory {
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address);
}

interface IMetaMorphoE {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setCurator(address) external;
    function setIsAllocator(address, bool) external;
    function setFee(uint256) external;
    function setFeeRecipient(address) external;
    function submitCap(MarketParams memory, uint256) external;
    function acceptCap(MarketParams memory) external;
    function setSupplyQueue(bytes32[] calldata) external;
}

/// @notice Elepan core: oracles + Elepan/cbBTC (main) + Elepan/WETH markets + cbBTC MetaMorpho vault.
/// @dev KING_GO=1 FIRE=1 → create markets (+ vault). FIRE_SEED=1 → flash-seed depth (Kingdom debt books).
contract FireElepanCore is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant MM_FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918;
    uint256 constant LLTV = 770000000000000000; // 77%
    uint8 constant ELEPAN_DEC = 8;

    address constant WETH_USDC_500 = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant CBTC_USDC_500 = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        bool doFire = vm.envOr("FIRE", uint256(0)) == 1;
        bool doVault = vm.envOr("FIRE_VAULT", uint256(0)) == 1;
        bool doSeed = vm.envOr("FIRE_SEED", uint256(0)) == 1;
        uint32 twap = uint32(vm.envOr("TWAP_SEC", uint256(1800)));
        // Main pair seed defaults modest; King can raise
        uint256 flashCbtc = vm.envOr("FLASH_CBTC", uint256(0.5e8)); // 0.5 cbBTC
        uint256 flashWeth = vm.envOr("FLASH_WETH", uint256(10 ether));

        require(IERC20E(ELEPAN).decimals() == ELEPAN_DEC, "ELEPAN_DEC");
        console2.log("elepanHot", IERC20E(ELEPAN).balanceOf(HOT));
        console2.log("doFire", doFire ? 1 : 0);
        console2.log("doSeed", doSeed ? 1 : 0);

        address oraCExisting = vm.envOr("ORACLE_CBTC", address(0));
        address oraWExisting = vm.envOr("ORACLE_WETH", address(0));
        address seederExisting = vm.envOr("SEEDER", address(0));
        address vaultExisting = vm.envOr("VAULT", address(0));

        vm.startBroadcast(pk);

        MorphoFixedElepanLoanOracle oraC;
        MorphoFixedElepanLoanOracle oraW;
        if (oraCExisting == address(0)) {
            oraC = new MorphoFixedElepanLoanOracle(CBTC_USDC_500, CBTC, USDC, twap, 8, ELEPAN_DEC);
        } else {
            oraC = MorphoFixedElepanLoanOracle(oraCExisting);
        }
        if (oraWExisting == address(0)) {
            oraW = new MorphoFixedElepanLoanOracle(WETH_USDC_500, WETH, USDC, twap, 18, ELEPAN_DEC);
        } else {
            oraW = MorphoFixedElepanLoanOracle(oraWExisting);
        }
        console2.log("Oracle Elepan/cbBTC", address(oraC));
        console2.log("Oracle Elepan/WETH", address(oraW));
        console2.log("pxC", oraC.price());
        console2.log("pxW", oraW.price());

        IMorphoE.MarketParams memory mpC = IMorphoE.MarketParams({
            loanToken: CBTC,
            collateralToken: ELEPAN,
            oracle: address(oraC),
            irm: IRM,
            lltv: LLTV
        });
        IMorphoE.MarketParams memory mpW = IMorphoE.MarketParams({
            loanToken: WETH,
            collateralToken: ELEPAN,
            oracle: address(oraW),
            irm: IRM,
            lltv: LLTV
        });

        bytes32 idC = keccak256(abi.encode(mpC));
        bytes32 idW = keccak256(abi.encode(mpW));

        if (doFire) {
            // createMarket reverts if exists — check loan token
            (address loanC,,,,) = IMorphoE(MORPHO).idToMarketParams(idC);
            if (loanC == address(0)) {
                IMorphoE(MORPHO).createMarket(mpC);
                console2.log("created Elepan/cbBTC");
            } else {
                console2.log("exists Elepan/cbBTC");
            }
            (address loanW,,,,) = IMorphoE(MORPHO).idToMarketParams(idW);
            if (loanW == address(0)) {
                IMorphoE(MORPHO).createMarket(mpW);
                console2.log("created Elepan/WETH");
            } else {
                console2.log("exists Elepan/WETH");
            }
        }

        console2.log("MarketId Elepan/cbBTC");
        console2.logBytes32(idC);
        console2.log("MarketId Elepan/WETH");
        console2.logBytes32(idW);

        // Primary vault: WETH MetaMorpho → Elepan/WETH (cbBTC factory path deferred / use FireElepanVaultWeth)
        address vault = vaultExisting;
        if (doVault && vault == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked("King-Elepan-WETH-yVault-v1", HOT));
            uint256 capWeth = vm.envOr("CAP_WETH", uint256(20_000 ether));
            vault = IMetaMorphoFactory(MM_FACTORY).createMetaMorpho(
                HOT, 0, WETH, "King Elepan WETH Vault", "yELEPAN-WETH", salt
            );
            IMetaMorphoE mm = IMetaMorphoE(vault);
            mm.setCurator(HOT);
            mm.setIsAllocator(HOT, true);
            mm.setFeeRecipient(HOT);
            mm.setFee(0.1e18); // 10%
            IMetaMorphoE.MarketParams memory mmp = IMetaMorphoE.MarketParams({
                loanToken: WETH,
                collateralToken: ELEPAN,
                oracle: address(oraW),
                irm: IRM,
                lltv: LLTV
            });
            mm.submitCap(mmp, capWeth);
            mm.acceptCap(mmp);
            bytes32[] memory q = new bytes32[](1);
            q[0] = idW;
            mm.setSupplyQueue(q);
            console2.log("Vault yELEPAN-WETH", vault);
        } else if (vault != address(0)) {
            console2.log("Vault existing", vault);
        } else {
            console2.log("Vault skipped (set FIRE_VAULT=1 or use FireElepanVaultWeth)");
        }

        CrownElepanFatFlashSeed seeder;
        if (seederExisting == address(0)) {
            seeder = new CrownElepanFatFlashSeed(MORPHO, ELEPAN, HOT, HOT);
        } else {
            seeder = CrownElepanFatFlashSeed(seederExisting);
        }
        console2.log("Seeder", address(seeder));

        if (doSeed) {
            IMorphoE(MORPHO).setAuthorization(address(seeder), true);
            uint256 collC = _collForHf(flashCbtc, oraC.price(), 1.55e18) * 101 / 100;
            uint256 collW = _collForHf(flashWeth, oraW.price(), 1.55e18) * 101 / 100;
            console2.log("Elepan for cbBTC seed", collC);
            console2.log("Elepan for WETH seed", collW);
            require(IERC20E(ELEPAN).balanceOf(HOT) >= collC + collW, "ELEPAN_SHORT");
            IERC20E(ELEPAN).approve(address(seeder), collC + collW);
            // Main pair first
            seeder.flashSeed(CBTC, address(oraC), IRM, LLTV, flashCbtc, collC);
            seeder.flashSeed(WETH, address(oraW), IRM, LLTV, flashWeth, collW);
            (uint128 sC,, uint128 bC,,,) = IMorphoE(MORPHO).market(idC);
            (uint128 sW,, uint128 bW,,,) = IMorphoE(MORPHO).market(idW);
            console2.log("cbBTC supply", uint256(sC));
            console2.log("cbBTC borrow", uint256(bC));
            console2.log("WETH supply", uint256(sW));
            console2.log("WETH borrow", uint256(bW));
        }

        vm.stopBroadcast();
        console2.log("READY", doFire ? 1 : 0);
    }

    function _collForHf(uint256 flashAmt, uint256 px, uint256 hfWad) internal pure returns (uint256) {
        return flashAmt * hfWad * 1e36 / (px * 1e18);
    }
}
