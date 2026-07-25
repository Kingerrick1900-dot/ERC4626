// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoU {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
}

interface IYeleU {
    function balanceOf(address) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

/// @notice Unlock yELE-K shares → USDC. KING_GO=1 FIRE_POT_UNLOCK=1
/// @dev Requires COLD_KEY (share owner). Flash-repays king debt so vault can withdraw.
///      Net: pot deleverages to USDC on `TO` (default cold). Matched book → ~full flash repay.
///      Ops float needs a separate ELE sale / Landing USDC — this frees the claim to tokens.
contract FirePotUnlock is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant COLD = 0xd2511FFa5F720A3d0cB7D1C9b44A9539c42BDf41;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant YELE_K = 0x0D96ba80502Eb8A08A6d3bd4680134b20C229532;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;

    // callback state
    address internal _unlocker;
    address internal _to;
    uint256 internal _shares;
    bool internal _locking;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_POT_UNLOCK", uint256(0)) == 1, "NEED FIRE_POT_UNLOCK=1");

        uint256 coldPk = vm.envUint("COLD_KEY");
        require(vm.addr(coldPk) == COLD, "COLD");
        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "HOT");

        address to = vm.envOr("TO", COLD);
        uint256 shares = IYeleU(YELE_K).balanceOf(COLD);
        require(shares > 0, "NO_SHARES");
        uint256 assets = IYeleU(YELE_K).convertToAssets(shares);
        console2.log("shares", shares);
        console2.log("assets", assets);

        // Deploy minimal unlock helper that Morpho flash can callback
        vm.startBroadcast(hotPk);
        PotUnlockHelper h = new PotUnlockHelper(HOT, YELE_K);
        console2.log("helper", address(h));
        // hot authorizes helper to repay on Morpho? repay uses USDC from helper; onBehalf king
        // Morpho repay does not need authorization for onBehalf when msg.sender provides USDC
        vm.stopBroadcast();

        // Cold: approve helper to pull shares for redeem
        vm.startBroadcast(coldPk);
        IERC20U(YELE_K).approve(address(h), shares);
        vm.stopBroadcast();

        vm.startBroadcast(hotPk);
        h.unlock(assets, shares, COLD, to);
        vm.stopBroadcast();

        console2.log("toUsdc", IERC20U(USDC).balanceOf(to));
        console2.log("vaultTA", IYeleU(YELE_K).totalAssets());
        console2.log("POT_UNLOCK_OK", uint256(1));
    }
}

contract PotUnlockHelper {
    address public immutable king;
    address public immutable vault;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV_77 = 770000000000000000;

    bool private locking;
    address private shareOwner;
    address private receiver;
    uint256 private shareAmt;

    constructor(address king_, address vault_) {
        king = king_;
        vault = vault_;
    }

    function unlock(uint256 flashAssets, uint256 shares, address owner_, address to_) external {
        require(msg.sender == king, "KING");
        shareOwner = owner_;
        receiver = to_;
        shareAmt = shares;
        locking = true;
        IMorphoU(MORPHO).flashLoan(USDC, flashAssets, abi.encode(flashAssets));
        locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        require(msg.sender == MORPHO && locking, "CB");
        IMorphoU.MarketParams memory mp =
            IMorphoU.MarketParams(USDC, ELE, ORACLE, IRM, LLTV_77);
        IMorphoU(MORPHO).accrueInterest(mp);

        // 1) Repay king debt → frees idle for vault withdraw
        IERC20U(USDC).approve(MORPHO, assets);
        IMorphoU(MORPHO).repay(mp, assets, 0, king, "");

        // 2) Redeem shares from owner → USDC here
        uint256 out = IYeleU(vault).redeem(shareAmt, address(this), shareOwner);
        require(out + 1e6 >= assets, "SHORT"); // allow dust

        // 3) Repay flash; send remainder (if any) to receiver
        IERC20U(USDC).approve(MORPHO, assets);
        uint256 bal = IERC20U(USDC).balanceOf(address(this));
        // Morpho pulls `assets` via transferFrom after callback
        if (bal > assets) {
            IERC20U(USDC).transfer(receiver, bal - assets);
        }
    }
}
