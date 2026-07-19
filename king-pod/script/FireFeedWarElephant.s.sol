// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice FEED: pull King's Vault V2 USDC to cold landing via forceDeallocate (gas-only flash).
/// @dev Requires KING_GO=1 and FIRE_FEED=1. Temporarily sets penalty 0 for full arrival, restores 1%.
///      Does NOT repay Morpho debt / free RSS - that is a separate unwind. FEED = liquid USDC control.

import {Script, console2} from "forge-std/Script.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function supply(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

interface IVaultV2F {
    function submit(bytes calldata data) external;
    function setForceDeallocatePenalty(address adapter, uint256 penalty) external;
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
    function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
        external
        returns (uint256);
    function withdraw(uint256 assets, address receiver, address onBehalf) external returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @dev Deployed by FireFeedWarElephant; king must approve vault shares to this freer.
contract CrownFeedElephant {
    address public immutable morpho;
    address public immutable usdc;
    address public immutable vault;
    address public immutable adapter;
    address public immutable king;
    address public immutable landing;
    IMorphoF.MarketParams public mp;

    bool public done;
    uint256 public fedAssets;

    error OnlyMorpho();
    error OnlyKing();
    error Already();

    event Fed(uint256 assets, address landing);

    constructor(
        address morpho_,
        address usdc_,
        address vault_,
        address adapter_,
        address king_,
        address landing_,
        IMorphoF.MarketParams memory mp_
    ) {
        morpho = morpho_;
        usdc = usdc_;
        vault = vault_;
        adapter = adapter_;
        king = king_;
        landing = landing_;
        mp = mp_;
    }

    /// @param assets USDC amount to forceDeallocate/withdraw (typically full convertToAssets(shares))
    function feed(uint256 assets) external {
        if (msg.sender != king) revert OnlyKing();
        if (done) revert Already();
        // Flash `assets` for IKR supply; vault withdraw returns `assets` (penalty must be 0)
        IMorphoF(morpho).flashLoan(usdc, assets, abi.encode(assets));
        done = true;
        fedAssets = assets;
        emit Fed(assets, landing);
    }

    function onMorphoFlashLoan(uint256 flashAssets, bytes calldata data) external {
        if (msg.sender != morpho) revert OnlyMorpho();
        uint256 assets = abi.decode(data, (uint256));
        require(flashAssets == assets, "flash");

        IERC20F(usdc).approve(morpho, assets);
        IMorphoF(morpho).supply(mp, assets, 0, address(this), hex"");

        // Pull king's shares via allowance, forceDeallocate on behalf of king, withdraw to landing
        IVaultV2F(vault).forceDeallocate(adapter, abi.encode(mp), assets, king);
        IVaultV2F(vault).withdraw(assets, landing, king);

        // Keep Morpho IKR supply as freer's position briefly, withdraw to repay flash
        IMorphoF(morpho).withdraw(mp, assets, 0, address(this), address(this));
        IERC20F(usdc).approve(morpho, assets);
    }
}

contract FireFeedWarElephant is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant PENALTY_1PCT = 0.01e18;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "hot");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: need KING_GO=1");
        require(vm.envOr("FIRE_FEED", uint256(0)) == 1, "NO-FEED: need FIRE_FEED=1");

        IMorphoF.MarketParams memory mp = IMorphoF(MORPHO).idToMarketParams(MARKET_ID);
        uint256 shares = IVaultV2F(VAULT).balanceOf(HOT);
        require(shares > 0, "no vault shares");
        uint256 assets = IVaultV2F(VAULT).convertToAssets(shares);
        console2.log("feed assets", assets);
        console2.log("landing", LANDING);

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);

        IVaultV2F(VAULT).submit(abi.encodeCall(IVaultV2F.setForceDeallocatePenalty, (ADAPTER, 0)));
        IVaultV2F(VAULT).setForceDeallocatePenalty(ADAPTER, 0);

        CrownFeedElephant freer = new CrownFeedElephant(MORPHO, USDC, VAULT, ADAPTER, HOT, LANDING, mp);

        // ERC4626 shares approve for withdraw onBehalf
        IVaultV2F(VAULT).approve(address(freer), type(uint256).max);
        freer.feed(assets);

        IVaultV2F(VAULT).submit(abi.encodeCall(IVaultV2F.setForceDeallocatePenalty, (ADAPTER, PENALTY_1PCT)));
        IVaultV2F(VAULT).setForceDeallocatePenalty(ADAPTER, PENALTY_1PCT);

        vm.stopBroadcast();

        uint256 landAfter = IERC20F(USDC).balanceOf(LANDING);
        console2.log("FEED DONE");
        console2.log("landBefore", landBefore);
        console2.log("landAfter", landAfter);
        console2.log("received", landAfter - landBefore);
        console2.log("penalty", IVaultV2F(VAULT).forceDeallocatePenalty(ADAPTER));
        console2.log("hotSharesLeft", IVaultV2F(VAULT).balanceOf(HOT));
    }
}
