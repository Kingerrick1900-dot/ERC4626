// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorpho {
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
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function accrueInterest(MarketParams memory) external;
    function setAuthorization(address, bool) external;
}

interface IMetaMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function reallocate(MarketAllocation[] calldata allocations) external;
    function setSkimRecipient(address) external;
    function setIsAllocator(address, bool) external;
    function skim(address token) external;
    function skimRecipient() external view returns (address);
    function totalAssets() external view returns (uint256);
}

/// @dev Fork: flash-repay ELE debt → yELE reallocate+skim → free coll. No Landing key.
contract EleUnwindSkimForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    bool locking;
    uint256 keepUsdc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_unwind_skim_clean() public {
        keepUsdc = 0;
        _run();
    }

    function test_unwind_try_keep_500k() public {
        keepUsdc = 500_000e6;
        _run();
    }

    function _run() internal {
        uint256 landBefore = IERC20(USDC).balanceOf(LANDING);
        uint256 eleBefore = IERC20(ELE).balanceOf(HOT);

        vm.startPrank(HOT);
        IMorpho(MORPHO).setAuthorization(address(this), true);
        IERC20(USDC).approve(address(this), type(uint256).max);
        IMetaMorpho(YELE).setSkimRecipient(address(this));
        IMetaMorpho(YELE).setIsAllocator(address(this), true);
        vm.stopPrank();

        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(MID, HOT);
        require(bor > 0, "no debt");
        (,, uint128 tba, uint128 tbs,,) = IMorpho(MORPHO).market(MID);
        uint256 flashAmt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs) + 5e6; // +$5 buffer

        // Prefund tiny buffer on freer (hot USDC is flaky under 7702 in fork transfer)
        deal(USDC, address(this), 10e6);

        locking = true;
        IMorpho(MORPHO).flashLoan(USDC, flashAmt, abi.encode(uint256(bor), uint256(coll)));
        locking = false;

        (, uint128 b2, uint128 c2) = IMorpho(MORPHO).position(MID, HOT);
        console2.log("debtAfter", uint256(b2));
        console2.log("collAfter", uint256(c2));
        console2.log("eleFreed", IERC20(ELE).balanceOf(HOT) - eleBefore);
        console2.log("landingUsdc", IERC20(USDC).balanceOf(LANDING));
        console2.log("landingDelta", IERC20(USDC).balanceOf(LANDING) - landBefore);
        console2.log("yeleTA", IMetaMorpho(YELE).totalAssets());
        assertEq(uint256(b2), 0, "debt");
        assertEq(uint256(c2), 0, "coll");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == MORPHO && locking, "cb");
        (uint256 borShares, uint256 coll) = abi.decode(data, (uint256, uint256));
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IMorpho(MORPHO).repay(mp, 0, borShares, HOT, "");
        if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, coll, HOT, HOT);

        IMetaMorpho.MarketParams memory ymp = IMetaMorpho.MarketParams(USDC, ELE, ORACLE, IRM, LLTV);
        IMetaMorpho.MarketAllocation[] memory allocs = new IMetaMorpho.MarketAllocation[](1);
        // Leave 1 wei in market to avoid InconsistentReallocation 1-wei rounding trap
        allocs[0] = IMetaMorpho.MarketAllocation({marketParams: ymp, assets: 1});
        IMetaMorpho(YELE).reallocate(allocs);

        console2.log("vaultUsdc", IERC20(USDC).balanceOf(YELE));
        IMetaMorpho(YELE).skim(USDC);
        console2.log("freerUsdc", IERC20(USDC).balanceOf(address(this)));

        if (keepUsdc > 0) {
            uint256 give = keepUsdc;
            uint256 have = IERC20(USDC).balanceOf(address(this));
            require(have >= assets + give, "NO_KEEP_BUFFER");
            IERC20(USDC).transfer(LANDING, give);
        }

        require(IERC20(USDC).balanceOf(address(this)) >= assets, "SHORT");
        IERC20(USDC).approve(MORPHO, assets);
    }
}
