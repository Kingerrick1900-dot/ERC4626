// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MorphoFixedRssLoanOracle} from "../src/MorphoFixedRssLoanOracle.sol";
import {CrownFatFlashSeed} from "../src/CrownFatFlashSeed.sol";

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

contract FatFlashSeedForkTest is Test {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    uint256 constant LLTV = 770000000000000000;
    address constant WETH_USDC_500 = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant CBTC_USDC_500 = 0xfBB6Eed8e7aa03B138556eeDaF5D271A5E1e43ef;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_flashSeed_weth_from_morpho_fat() public {
        MorphoFixedRssLoanOracle ora = new MorphoFixedRssLoanOracle(WETH_USDC_500, WETH, USDC, 1800, 18);
        IMorphoT.MarketParams memory mp = IMorphoT.MarketParams({
            loanToken: WETH,
            collateralToken: RSS,
            oracle: address(ora),
            irm: IRM,
            lltv: LLTV
        });
        // createMarket is permissionless
        IMorphoT(MORPHO).createMarket(mp);
        bytes32 id = keccak256(abi.encode(mp));

        CrownFatFlashSeed seeder = new CrownFatFlashSeed(MORPHO, RSS, HOT, LANDING, address(this));

        uint256 flashAmt = 10 ether;
        // HF_raw >= 1.55
        uint256 rssColl = flashAmt * 1.55e18 * 1e36 / (ora.price() * 1e18) * 101 / 100;

        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(seeder), rssColl);
        (bool ok,) = MORPHO.call(abi.encodeWithSignature("setAuthorization(address,bool)", address(seeder), true));
        require(ok, "auth");
        vm.stopPrank();

        // Owner is this test contract - but transferFrom pulls from king (HOT)
        seeder.flashSeed(WETH, address(ora), IRM, LLTV, flashAmt, rssColl);

        (uint128 supply,, uint128 borrow,,,) = IMorphoT(MORPHO).market(id);
        console2.log("supply", uint256(supply));
        console2.log("borrow", uint256(borrow));
        assertGe(uint256(supply), flashAmt);
        assertGe(uint256(borrow), flashAmt);
    }
}
