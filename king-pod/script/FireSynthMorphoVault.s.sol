// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IMetaMorphoFactory {
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address metaMorpho);
}

interface IMetaMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setCurator(address newCurator) external;
    function setIsAllocator(address allocator, bool isAllocator) external;
    function setFee(uint256 newFee) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function acceptCap(MarketParams memory marketParams) external;
    function setSupplyQueue(bytes32[] calldata ids) external;
    function owner() external view returns (address);
    function curator() external view returns (address);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

interface IERC20b {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracle {
    function price() external view returns (uint256);
}

/// @notice Falcon-style: permissionless Morpho market (eUSD synth coll / USDC loan) + MetaMorpho USDC vault.
/// @dev Precedent: Ethena USDe on Morpho · Falcon sUSDf borrow USDC. Risk = high (synth). ZK/yRSS backs eUSD thesis.
///      Oracle: existing FixedOracle $1 (1e24) — eUSD 18dp / USDC 6dp.
contract FireSynthMorphoVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918; // MetaMorpho v1.1 Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a; // Kingdom synthetic dollar
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525; // gold rail (NAV attest)
    // Fixed $1 oracle already live for 18dp coll / 6dp loan
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 860000000000000000; // 86% — stablecoin-class synth (Ethena-style)
    uint256 constant TIMELOCK = 0;
    uint256 constant PERF_FEE = 0.1e18; // 10%
    // Open cap so borrowers can pull USDC once vault fills (permissionless demand)
    uint256 constant SUPPLY_CAP = 200_000_000e6; // $200M USDC

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        if (pk == 0) pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 px = IOracle(ORACLE).price();
        require(px == 1e24, "ORACLE_NOT_1USD"); // 18dp coll / 6dp loan @ $1

        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
        bytes32 marketId = keccak256(abi.encode(mp));

        vm.startBroadcast(pk);

        // 1) List synth as Morpho Blue collateral (permissionless createMarket)
        (address loan,,,,) = IMorpho(MORPHO).idToMarketParams(marketId);
        if (loan == address(0)) {
            IMorpho(MORPHO).createMarket(mp);
        }

        // 2) Deploy Kingdom MetaMorpho USDC vault — borrowers fill by taking USDC against eUSD
        bytes32 salt = keccak256(abi.encodePacked("King-Synth-eUSD-USDC-v1", HOT, block.chainid));
        address vault = IMetaMorphoFactory(FACTORY).createMetaMorpho(
            HOT,
            TIMELOCK,
            USDC,
            "King Synth eUSD USDC Vault",
            "ySYNTH-USDC",
            salt
        );

        IMetaMorpho mm = IMetaMorpho(vault);
        mm.setCurator(HOT);
        mm.setIsAllocator(HOT, true);
        mm.setIsAllocator(LANDING, true);
        mm.setFeeRecipient(HOT);
        mm.setFee(PERF_FEE);

        IMetaMorpho.MarketParams memory mmp = IMetaMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: EUSD,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
        mm.submitCap(mmp, SUPPLY_CAP);
        mm.acceptCap(mmp);

        bytes32[] memory queue = new bytes32[](1);
        queue[0] = marketId;
        mm.setSupplyQueue(queue);

        // Tiny dead seed if HOT has ≥ $1 USDC (private bootstrap; not Morpho-app $1M listing)
        uint256 bal = IERC20b(USDC).balanceOf(HOT);
        if (bal >= 1e6) {
            IERC20b(USDC).approve(vault, 1e6);
            mm.deposit(1e6, address(0xdead));
        }

        vm.stopBroadcast();

        console2.log("FIRE", "synth-morpho-vault");
        console2.log("marketId");
        console2.logBytes32(marketId);
        console2.log("vault", vault);
        console2.log("collateral", EUSD);
        console2.log("loan", USDC);
        console2.log("oracle", ORACLE);
        console2.log("lltv", LLTV);
        console2.log("supplyCapUSDC", SUPPLY_CAP);
        console2.log("yrssGoldNav6dp", IMetaMorpho(YRSS).totalAssets());
        console2.log("vaultTotalAssets", mm.totalAssets());
        console2.log("RISK", "HIGH-synth-collateral-ZK-backed-eUSD");
        console2.log("PRECEDENT", "Falcon-sUSDf-Morpho + Ethena-USDe-Steakhouse");
    }
}
