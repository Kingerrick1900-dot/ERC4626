// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

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
    function fee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function asset() external view returns (address);
}

/// @notice Deploy + configure King RSS/USDC MetaMorpho vault via official Morpho factory.
contract DeployKingMetaMorpho is Script {
    address constant FACTORY = 0xFf62A7c278C62eD665133147129245053Bbf5918; // MetaMorpho Factory v1.1 Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // 77%
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    // Target book $100k → 15% allocation cap = $15k USDC absolute
    uint256 constant TARGET_TVL_USDC = 100_000e6;
    uint256 constant ALLOC_BPS = 1500; // 15%
    uint256 constant PERF_FEE = 0.1e18; // 10%
    uint256 constant TIMELOCK = 0; // industry simple; raise later if King wants

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address king = vm.addr(pk);

        uint256 supplyCap = (TARGET_TVL_USDC * ALLOC_BPS) / 10_000;
        bytes32 salt = keccak256(abi.encodePacked("KingRSS-USDC-yVault-v1", king));

        vm.startBroadcast(pk);
        address vault = IMetaMorphoFactory(FACTORY).createMetaMorpho(
            king,
            TIMELOCK,
            USDC,
            "King RSS USDC Vault",
            "yRSS-USDC",
            salt
        );

        IMetaMorpho mm = IMetaMorpho(vault);
        mm.setCurator(king);
        mm.setIsAllocator(king, true);
        mm.setFeeRecipient(king);
        mm.setFee(PERF_FEE);

        IMetaMorpho.MarketParams memory mp = IMetaMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
        mm.submitCap(mp, supplyCap);
        mm.acceptCap(mp);

        bytes32[] memory queue = new bytes32[](1);
        queue[0] = MARKET_ID;
        mm.setSupplyQueue(queue);
        vm.stopBroadcast();

        console2.log("MetaMorpho vault", vault);
        console2.log("curator", mm.curator());
        console2.log("fee", mm.fee());
        console2.log("feeRecipient", mm.feeRecipient());
        console2.log("supplyCapUSDC", supplyCap);
        console2.log("NOTE: seed needs USDC; King dust too low; seed deferred");
    }
}
