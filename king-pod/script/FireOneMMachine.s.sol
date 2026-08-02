// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface ICdpM {
    function deposit(uint256 elepanAmt) external;
    function mint(uint256 eusdAmt) external;
    function mintTo(address to, uint256 eusdAmt) external;
    function coll() external view returns (uint256);
    function accruedDebt() external view returns (uint256);
    function healthFactor() external view returns (uint256);
    function safetyFloor() external view returns (uint256);
    function maxMintable() external view returns (uint256);
    function previewMintHf(uint256 eusdAmt) external view returns (uint256);
    function zkGate() external view returns (address);
    function treasury() external view returns (address);
}

interface IZkM {
    function isProven(address) external view returns (bool);
}

interface IInvPsmM {
    function seedEusd(uint256 amount) external;
    function reserves() external view returns (uint256 usdcBal, uint256 eusdBal);
    function owner() external view returns (address);
}

/// @notice 1M Machine: mint 1M eUSD, deploy 100k to inventory PSM, keep 900k reserve.
/// @dev KING_GO=1 FIRE_ONE_M=1
///      Deposits ELE onto kingdom CDP (treasury=hot) to hold HF≥1.60 after mint.
contract FireOneMMachine is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant CDP = 0xda19793ad426E05213C7B38B85028811A80177Fa;
    /// @dev Inventory PSM (eUSD↔USDC clear) — accepts seedEusd.
    address constant INV_PSM = 0x9199E5099C2C46A688F982E377a146Ab6db8060b;

    uint256 constant MINT_EUSD = 1_000_000e18;
    uint256 constant DEPLOY_EUSD = 100_000e18;
    uint256 constant HF_MIN = 1.60e18;
    uint256 constant DEFAULT_MIN_ETH = 3e14;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ONE_M", uint256(0)) == 1, "NEED FIRE_ONE_M=1");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(ICdpM(CDP).treasury() == HOT, "TREASURY");
        require(IZkM(ICdpM(CDP).zkGate()).isProven(HOT), "ZK");
        require(IInvPsmM(INV_PSM).owner() == HOT, "PSM_OWNER");
        require(HOT.balance >= vm.envOr("MIN_ETH_WEI", DEFAULT_MIN_ETH), "GAS_FLOOR");

        uint256 mintAmt = vm.envOr("MINT_EUSD", MINT_EUSD);
        uint256 deployAmt = vm.envOr("DEPLOY_EUSD", DEPLOY_EUSD);
        require(mintAmt == 1_000_000e18, "MINT_1M");
        require(deployAmt == 100_000e18, "DEPLOY_100K");
        require(mintAmt > deployAmt, "RESERVE");

        uint256 debtBefore = ICdpM(CDP).accruedDebt();
        uint256 collBefore = ICdpM(CDP).coll();
        uint256 debtAfter = debtBefore + mintAmt;

        // min coll for HF≥1.60: coll = debt * 1.60 * 1e24 / (price * 1e18), price=1e34
        uint256 minColl = (debtAfter * HF_MIN * 1e24) / (uint256(1e34) * 1e18);
        minColl += 1e8; // +1 ELE buffer
        require(minColl > collBefore, "COLL_ALREADY");
        uint256 depositEle = minColl - collBefore;

        uint256 eleBal = IERC20M(ELE).balanceOf(HOT);
        console2.log("debtBefore", debtBefore);
        console2.log("collBefore", collBefore);
        console2.log("depositEle", depositEle);
        console2.log("eleBal", eleBal);
        require(eleBal >= depositEle, "ELE_SHORT");

        uint256 eusdBefore = IERC20M(EUSD).balanceOf(HOT);

        vm.startBroadcast(pk);
        IERC20M(ELE).approve(CDP, depositEle);
        ICdpM(CDP).deposit(depositEle);
        require(ICdpM(CDP).previewMintHf(mintAmt) >= ICdpM(CDP).safetyFloor(), "PREVIEW_FLOOR");
        require(ICdpM(CDP).previewMintHf(mintAmt) >= HF_MIN, "PREVIEW_HF");
        ICdpM(CDP).mint(mintAmt);

        uint256 eusdHot = IERC20M(EUSD).balanceOf(HOT);
        require(eusdHot >= eusdBefore + mintAmt, "MINT_LAND");
        require(ICdpM(CDP).healthFactor() >= HF_MIN, "HF");

        // Deploy 100k into inventory PSM (eUSD rail seed). Keep 900k on hot.
        IERC20M(EUSD).approve(INV_PSM, deployAmt);
        IInvPsmM(INV_PSM).seedEusd(deployAmt);
        vm.stopBroadcast();

        uint256 eusdAfter = IERC20M(EUSD).balanceOf(HOT);
        (, uint256 psmEusd) = IInvPsmM(INV_PSM).reserves();
        console2.log("hfAfter", ICdpM(CDP).healthFactor());
        console2.log("debtAfter", ICdpM(CDP).accruedDebt());
        console2.log("collAfter", ICdpM(CDP).coll());
        console2.log("eusdHotReserve", eusdAfter);
        console2.log("psmEusd", psmEusd);
        console2.log("deployed", deployAmt);
        require(eusdAfter >= mintAmt - deployAmt, "RESERVE_SHORT");
        // Allow tiny fee dust; reserve target 900k
        require(eusdAfter >= 900_000e18, "RESERVE_900K");
        console2.log("ONE_M_MACHINE_OK", uint256(1));
    }
}
