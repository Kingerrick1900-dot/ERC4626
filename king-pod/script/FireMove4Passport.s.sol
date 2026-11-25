// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Move 4 fire: post cbBTC or WETH on Morpho -> borrow USDC to KingVault.
/// @dev Env:
///   PRIVATE_KEY (HOT)
///   ASSET=cbbtc|weth (default cbbtc)
///   COLL_AMT (raw; 0 = full wallet balance)
///   BORROW_AMT (USDC raw; 0 = min(idle, 80% LTV estimate skipped - uses idle cap only; Morpho enforces LTV)
///   BROADCAST=1 to send (default dry)
///   PASSPORT (optional module). If unset, HOT calls Morpho directly.

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128 totalSupplyAssets, uint128, uint128 totalBorrowAssets, uint128, uint128, uint256);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IPassportF {
    function passport(bool useCbBtc, uint256 collAmt, uint256 pullAmt, uint256 borrowAmt) external returns (uint256);
    function marketIdle(bool useCbBtc) external view returns (uint256);
}

contract FireMove4Passport is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORACLE_CBBTC = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    uint256 constant LLTV_86 = 860000000000000000;

    bytes32 constant CBBTC_ID = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;
    bytes32 constant WETH_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant MIN_CBBTC = 1e5; // 0.001 cbBTC (8dp)
    uint256 constant MIN_WETH = 1e15; // 0.001 WETH

    function run() external {
        bool useCbBtc = _isCbBtc();
        address coll = useCbBtc ? CBBTC : WETH;
        bytes32 mid = useCbBtc ? CBBTC_ID : WETH_ID;
        uint256 collBal = IERC20F(coll).balanceOf(HOT);
        uint256 collAmt = vm.envOr("COLL_AMT", uint256(0));
        if (collAmt == 0) collAmt = collBal;
        uint256 borrowAmt = vm.envOr("BORROW_AMT", uint256(0));
        bool doBroadcast = vm.envOr("BROADCAST", uint256(0)) == 1;
        address passport = vm.envOr("PASSPORT", address(0));

        (uint128 supply,, uint128 borrow,,,) = IMorphoF(MORPHO).market(mid);
        uint256 idle = uint256(supply) > uint256(borrow) ? uint256(supply) - uint256(borrow) : 0;
        (, , uint128 collPosted) = IMorphoF(MORPHO).position(mid, HOT);
        uint256 vaultUsdc = IERC20F(USDC).balanceOf(KING_VAULT);

        console2.log("asset", useCbBtc ? "cbBTC" : "WETH");
        console2.log("hotCollBal", collBal);
        console2.log("collAmt", collAmt);
        console2.log("mktIdleUsdc", idle);
        console2.log("hotPosted", uint256(collPosted));
        console2.log("kingVaultUsdc", vaultUsdc);
        console2.log("borrowAmt", borrowAmt);

        uint256 minColl = useCbBtc ? MIN_CBBTC : MIN_WETH;
        if (collAmt < minColl && collPosted == 0) {
            console2.log("NOOP: blue-chip inventory below min - seed HOT first");
            return;
        }
        if (idle == 0) {
            console2.log("NOOP: market idle 0 - wait for PA fill or repay");
            return;
        }
        if (borrowAmt == 0) {
            // Default ask: $100k test size capped by idle (King can override)
            uint256 ask = 100_000e6;
            borrowAmt = ask < idle ? ask : idle;
        }
        if (borrowAmt > idle) borrowAmt = idle;

        if (!doBroadcast) {
            console2.log("DRY OK - set BROADCAST=1 PRIVATE_KEY=... to fire");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        if (passport != address(0)) {
            IERC20F(coll).approve(passport, collAmt);
            IPassportF(passport).passport(useCbBtc, collAmt, collAmt, borrowAmt);
        } else {
            IMorphoF.MarketParams memory mp = IMorphoF.MarketParams({
                loanToken: USDC,
                collateralToken: coll,
                oracle: useCbBtc ? ORACLE_CBBTC : ORACLE_WETH,
                irm: IRM,
                lltv: LLTV_86
            });
            if (collAmt > 0) {
                IERC20F(coll).approve(MORPHO, collAmt);
                IMorphoF(MORPHO).supplyCollateral(mp, collAmt, HOT, "");
            }
            IMorphoF(MORPHO).borrow(mp, borrowAmt, 0, HOT, KING_VAULT);
        }

        vm.stopBroadcast();
        console2.log("FIRE done vaultUsdc", IERC20F(USDC).balanceOf(KING_VAULT));
    }

    function _isCbBtc() internal view returns (bool) {
        string memory a = vm.envOr("ASSET", string("cbbtc"));
        bytes memory b = bytes(a);
        if (b.length >= 4 && b[0] == "w") return false;
        return true;
    }
}
