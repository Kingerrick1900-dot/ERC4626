// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Dual-set loan: liberate Set B USDC → seed Set A → borrow Set A → Landing/PSM.
/// @dev Docs: deployments/DUAL-SET-LOAN-PLAN.md
///      KING_GO=1 ROUTE=1|2|3 X=<usdc 6dp> forge script ... --broadcast
///      FROZEN by default (reverts without KING_GO=1).

interface IERC20D {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoD {
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

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;

    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IOtcUnstock {
    // selector 0xf644448f — owner unstock(uint256 amount, address to); verified live
    function f644448f(uint256 amount, address to) external;
}

interface IPsmSeed {
    function seedUsdc(uint256 amount) external;
}

/// @dev Morpho flash callback target — must be the contract Morpho calls back.
contract DualSetFlashReceiver {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant RSS18 = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE_B = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_A = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    address constant OTC = 0x683886A3911323e92A6C764c3331CAC168D0029E;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant PSM = 0xfFEd7981f924Edc652E9b767aCa601505dfa4977;

    address public immutable king;
    uint256 public lastBorrowedA;

    constructor(address king_) {
        king = king_;
    }

    /// @notice Morpho flash callback. `data` = abi.encode(uint8 route, uint256 x, uint256 rss18Coll)
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO, "only Morpho");
        (uint8 route, uint256 x, uint256 rss18Coll) = abi.decode(data, (uint8, uint256, uint256));
        require(assets == x, "amt");

        IMorphoD.MarketParams memory setB = IMorphoD.MarketParams(USDC, ELE, ORACLE_B, IRM, LLTV);
        IMorphoD.MarketParams memory setA = IMorphoD.MarketParams(USDC, RSS18, ORACLE_A, IRM, LLTV);

        // Phase 0: repay Set B + withdraw supply → free USDC on this contract
        IERC20D(USDC).approve(MORPHO, x);
        IMorphoD(MORPHO).repay(setB, x, 0, king, "");
        IMorphoD(MORPHO).withdraw(setB, x, 0, king, address(this));

        if (route == 1) {
            // MIGRATE B→A: seed Set A, borrow X, leave USDC here to repay flash
            _unstockAndPostA(setA, rss18Coll);
            IERC20D(USDC).approve(MORPHO, x);
            IMorphoD(MORPHO).supply(setA, x, 0, address(this), "");
            // authorize king? borrow onBehalf this contract
            (uint256 borrowed,) = IMorphoD(MORPHO).borrow(setA, x, 0, address(this), address(this));
            lastBorrowedA = borrowed;
        } else if (route == 2) {
            // ELEPAN: send freed USDC to Landing + seed PSM; flash repay MUST be pre-funded
            // For atomic flash safety: supply/borrow Set A to refill repay, send only surplus=0
            // True Route 2 without circularity needs external X (see plan). Here: PSM seed dust path
            // after migrating like route 1, then push borrowed to Landing — flash still repaid from borrow.
            _unstockAndPostA(setA, rss18Coll);
            IERC20D(USDC).approve(MORPHO, x);
            IMorphoD(MORPHO).supply(setA, x, 0, address(this), "");
            (uint256 borrowed,) = IMorphoD(MORPHO).borrow(setA, x, 0, address(this), address(this));
            lastBorrowedA = borrowed;
            // Move to Landing then pull back for flash repay would fail — keep for repay.
            // Post-flash, king pulls from this contract / Set A borrow receiver was this.
        } else {
            revert("ROUTE");
        }

        // Morpho pulls flash repayment via transferFrom(this)
        IERC20D(USDC).approve(MORPHO, x);
    }

    function _unstockAndPostA(IMorphoD.MarketParams memory setA, uint256 rss18Coll) internal {
        if (rss18Coll > 0) {
            // OTC unstock to this receiver (king must have approved/ownership — OTC owner is king;
            // unstock must be called by king. For flash callback we expect coll already on this or king.
            // Safer: script pre-unstocks to king, king transfers coll in before flash.
        }
        uint256 bal = IERC20D(RSS18).balanceOf(address(this));
        require(bal >= rss18Coll && rss18Coll > 0, "RSS18 coll");
        IERC20D(RSS18).approve(MORPHO, rss18Coll);
        IMorphoD(MORPHO).supplyCollateral(setA, rss18Coll, address(this), "");
    }

    function pullUsdc(address to, uint256 amt) external {
        require(msg.sender == king, "king");
        IERC20D(USDC).transfer(to, amt);
    }

    function seedPsm(uint256 amt) external {
        require(msg.sender == king, "king");
        IERC20D(USDC).approve(PSM, amt);
        IPsmSeed(PSM).seedUsdc(amt);
    }
}

contract FireDualSetLoan is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant RSS18 = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant OTC = 0x683886A3911323e92A6C764c3331CAC168D0029E;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant PSM = 0xfFEd7981f924Edc652E9b767aCa601505dfa4977;
    bytes32 constant MID8 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant MID18 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "FROZEN: need KING_GO=1");
        uint256 route = vm.envOr("ROUTE", uint256(1));
        uint256 x = vm.envOr("X", uint256(700_000e6));
        require(route == 1 || route == 2 || route == 3, "ROUTE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT key");

        console2.log("ROUTE", route);
        console2.log("X", x);

        (uint128 sB,, uint128 bB,,,) = IMorphoD(MORPHO).market(MID8);
        (uint128 sA,, uint128 bA,,,) = IMorphoD(MORPHO).market(MID18);
        console2.log("SetB idle", uint256(sB) > uint256(bB) ? uint256(sB) - uint256(bB) : 0);
        console2.log("SetA idle", uint256(sA) > uint256(bA) ? uint256(sA) - uint256(bA) : 0);

        vm.startBroadcast(pk);

        if (route == 3) {
            // Dust: borrow existing Set A idle to Landing (unstock dust coll if needed)
            uint256 idleA = uint256(sA) > uint256(bA) ? uint256(sA) - uint256(bA) : 0;
            require(idleA > 0, "no SetA idle");
            uint256 collNeed = (idleA * 1e12) / 77 * 100 / 100; // rough 18dp RSS @ $1, 77% — override via RSS18_COLL
            collNeed = vm.envOr("RSS18_COLL", (idleA * 1e12) * 100 / 77); // USDC6 → RSS18: *1e12 at $1
            // unstock from OTC to hot
            (bool ok,) = OTC.call(abi.encodeWithSelector(0xf644448f, collNeed, HOT));
            require(ok, "unstock");
            IMorphoD.MarketParams memory setA = IMorphoD.MarketParams(
                USDC, RSS18, 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e, 0x46415998764C29aB2a25CbeA6254146D50D22687, 770000000000000000
            );
            IERC20D(RSS18).approve(MORPHO, collNeed);
            IMorphoD(MORPHO).supplyCollateral(setA, collNeed, HOT, "");
            IMorphoD(MORPHO).borrow(setA, idleA, 0, HOT, LAND);
            console2.log("Landing USDC", IERC20D(USDC).balanceOf(LAND));
            vm.stopBroadcast();
            return;
        }

        // RSS18 coll for X at $1 and 77% LLTV with 5% buffer
        uint256 rss18Coll = vm.envOr("RSS18_COLL", (x * 1e12) * 105 / 77);
        console2.log("RSS18 coll", rss18Coll);

        // Pre-unstock RSS18 to hot, then fund receiver
        {
            (bool ok,) = OTC.call(abi.encodeWithSelector(0xf644448f, rss18Coll, HOT));
            require(ok, "unstock OTC");
        }

        DualSetFlashReceiver recv = new DualSetFlashReceiver(HOT);
        IERC20D(RSS18).transfer(address(recv), rss18Coll);

        // King must authorize receiver to repay/withdraw on behalf of king for Set B
        // Morpho authorization
        (bool authOk,) = MORPHO.call(abi.encodeWithSignature("setAuthorization(address,bool)", address(recv), true));
        require(authOk, "auth");

        IMorphoD(MORPHO).flashLoan(USDC, x, abi.encode(uint8(route), x, rss18Coll));

        console2.log("recv USDC", IERC20D(USDC).balanceOf(address(recv)));
        console2.log("Landing USDC", IERC20D(USDC).balanceOf(LAND));
        console2.log("PSM USDC", IERC20D(USDC).balanceOf(PSM));
        console2.log("lastBorrowedA", recv.lastBorrowedA());

        vm.stopBroadcast();
    }
}
