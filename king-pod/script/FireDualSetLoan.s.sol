// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Dual-set loan: liberate Set B USDC → seed Set A → borrow Set A.
/// @dev Morpho flashLoan callbacks msg.sender — receiver must initiate the flash.
///      KING_GO=1 ROUTE=1|2|3 X=<usdc6> forge script ... --broadcast

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

    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

interface IPsmSeed {
    function seedUsdc(uint256 amount) external;
}

/// @dev Initiates Morpho flashLoan so callback lands here (not on the EOA).
contract DualSetExecutor {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant RSS18 = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE_B = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_A = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant PSM = 0xfFEd7981f924Edc652E9b767aCa601505dfa4977;

    address public immutable king;
    uint256 public lastBorrowedA;

    error OnlyKing();
    error OnlyMorpho();

    constructor(address king_) {
        king = king_;
    }

    /// @notice King-gated fire. Prefund this contract with rss18Coll before calling.
    function fire(uint8 route, uint256 x, uint256 rss18Coll) external {
        if (msg.sender != king) revert OnlyKing();
        IMorphoD(MORPHO).flashLoan(USDC, x, abi.encode(route, x, rss18Coll));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != MORPHO) revert OnlyMorpho();
        (uint8 route, uint256 x, uint256 rss18Coll) = abi.decode(data, (uint8, uint256, uint256));
        require(assets == x, "amt");

        IMorphoD.MarketParams memory setB = IMorphoD.MarketParams(USDC, ELE, ORACLE_B, IRM, LLTV);
        IMorphoD.MarketParams memory setA = IMorphoD.MarketParams(USDC, RSS18, ORACLE_A, IRM, LLTV);

        // Phase 0: flash USDC is on THIS contract. Repay king's Set B debt, withdraw king's supply here.
        IERC20D(USDC).approve(MORPHO, x);
        IMorphoD(MORPHO).repay(setB, x, 0, king, "");
        IMorphoD(MORPHO).withdraw(setB, x, 0, king, address(this));

        // Post Set A coll (prefunded)
        uint256 bal = IERC20D(RSS18).balanceOf(address(this));
        require(bal >= rss18Coll && rss18Coll > 0, "RSS18 coll");
        IERC20D(RSS18).approve(MORPHO, rss18Coll);
        IMorphoD(MORPHO).supplyCollateral(setA, rss18Coll, address(this), "");

        // Seed Set A idle + borrow against Set A
        IERC20D(USDC).approve(MORPHO, x);
        IMorphoD(MORPHO).supply(setA, x, 0, address(this), "");
        (uint256 borrowed,) = IMorphoD(MORPHO).borrow(setA, x, 0, address(this), address(this));
        lastBorrowedA = borrowed;

        if (route == 2) {
            // Push to Landing then seed PSM — but must keep `x` for flash repay.
            // Route 2 atomic: migrate like route 1; king pulls post-tx via pullUsdc after
            // separate non-flash funding. Keep USDC here for repay.
        }

        // Morpho pulls flash repayment via transferFrom(this, morpho, x)
        IERC20D(USDC).approve(MORPHO, x);
    }

    function pullUsdc(address to, uint256 amt) external {
        if (msg.sender != king) revert OnlyKing();
        IERC20D(USDC).transfer(to, amt);
    }

    function pullRss18(address to, uint256 amt) external {
        if (msg.sender != king) revert OnlyKing();
        IERC20D(RSS18).transfer(to, amt);
    }

    function seedPsm(uint256 amt) external {
        if (msg.sender != king) revert OnlyKing();
        IERC20D(USDC).approve(PSM, amt);
        IPsmSeed(PSM).seedUsdc(amt);
    }

    function toLanding(uint256 amt) external {
        if (msg.sender != king) revert OnlyKing();
        IERC20D(USDC).transfer(LAND, amt);
    }
}

contract FireDualSetLoan is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
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
        // Default $500k — fits 700k OTC RSS18 @ 77% with buffer
        uint256 x = vm.envOr("X", uint256(500_000e6));
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
            uint256 idleA = uint256(sA) > uint256(bA) ? uint256(sA) - uint256(bA) : 0;
            require(idleA > 0, "no SetA idle");
            uint256 collNeed = vm.envOr("RSS18_COLL", (idleA * 1e12) * 100 / 77);
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

        // Full OTC bag as Set A coll (700k RSS18 covers ~$539k at 77%; X default 500k)
        uint256 rss18Coll = vm.envOr("RSS18_COLL", uint256(700_000 ether));
        console2.log("RSS18 coll", rss18Coll);

        (bool okUnstock,) = OTC.call(abi.encodeWithSelector(0xf644448f, rss18Coll, HOT));
        require(okUnstock, "unstock OTC");

        DualSetExecutor exec = new DualSetExecutor(HOT);
        require(IERC20D(RSS18).transfer(address(exec), rss18Coll), "fund exec");

        // Authorize executor to repay/withdraw Set B on behalf of king
        IMorphoD(MORPHO).setAuthorization(address(exec), true);

        DualSetExecutor(exec).fire(uint8(route), x, rss18Coll);

        console2.log("exec USDC", IERC20D(USDC).balanceOf(address(exec)));
        console2.log("Landing USDC", IERC20D(USDC).balanceOf(LAND));
        console2.log("PSM USDC", IERC20D(USDC).balanceOf(PSM));
        console2.log("lastBorrowedA", exec.lastBorrowedA());
        console2.log("exec", address(exec));

        // Route 2: after successful migrate, nothing left on exec (flash repaid).
        // Optional: seed PSM from Landing if route 3 style dust exists.
        if (route == 2) {
            uint256 landBal = IERC20D(USDC).balanceOf(LAND);
            console2.log("route2 landing", landBal);
        }

        vm.stopBroadcast();
    }
}
