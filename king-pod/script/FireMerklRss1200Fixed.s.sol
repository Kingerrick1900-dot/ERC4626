// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IMerklCreator {
    struct Campaign {
        bytes32 campaignId;
        address creator;
        address rewardToken;
        uint256 amount;
        uint32 campaignType;
        uint32 startTimestamp;
        uint32 duration;
        bytes campaignData;
    }

    function acceptConditions() external;
    function createCampaign(Campaign memory newCampaign) external returns (bytes32);
    function userSignatures(address) external view returns (bytes32);
    function messageHash() external view returns (bytes32);
    function defaultFees() external view returns (uint256);
    function rewardTokenMinAmounts(address) external view returns (uint256);
}

/// @notice Merkl FIXED_RATE supply amp on RSS/$1200 — follow-up after Peapods scream.
/// @dev KING_OK=1 FIRE_MERKL=1
///      Reward = USDC (Merkl-whitelisted). ELE min=0 → not usable until whitelist.
///      Env: CAMPAIGN_DATA, START_TS from encode_rss1200_fixed.sh or Merkl Studio.
///      MERKL_BUDGET raw USDC (default 50_000e6). Hot must hold budget.
contract FireMerklRss1200Fixed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CREATOR = 0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint32 constant TYPE_MORPHO_MARKET = 18;
    uint32 constant DURATION = 28 days;

    error NO_GO();
    error NOT_HOT();
    error NOT_WHITELISTED();
    error BUDGET();
    error DATA();

    function run() external {
        if (vm.envOr("KING_OK", uint256(0)) != 1) revert NO_GO();
        if (vm.envOr("FIRE_MERKL", uint256(0)) != 1) revert NO_GO();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(pk) != HOT) revert NOT_HOT();

        uint256 budget = vm.envOr("MERKL_BUDGET", uint256(50_000e6));
        IMerklCreator creator = IMerklCreator(CREATOR);
        if (creator.rewardTokenMinAmounts(USDC) == 0) revert NOT_WHITELISTED();
        if (IERC20M(USDC).balanceOf(HOT) < budget) revert BUDGET();

        bytes memory campaignData = vm.envBytes("CAMPAIGN_DATA");
        uint32 start = uint32(vm.envUint("START_TS"));
        if (campaignData.length == 0) revert DATA();
        if (start <= block.timestamp) revert DATA();

        console2.log("market", uint256(MID));
        console2.log("budgetUsdc", budget);
        console2.log("start", uint256(start));

        vm.startBroadcast(pk);
        if (creator.userSignatures(HOT) != creator.messageHash()) {
            creator.acceptConditions();
        }
        IERC20M(USDC).approve(CREATOR, budget);
        bytes32 id = creator.createCampaign(
            IMerklCreator.Campaign({
                campaignId: bytes32(0),
                creator: HOT,
                rewardToken: USDC,
                amount: budget,
                campaignType: TYPE_MORPHO_MARKET,
                startTimestamp: start,
                duration: DURATION,
                campaignData: campaignData
            })
        );
        vm.stopBroadcast();

        console2.logBytes32(id);
        console2.log("MERKL_RSS1200_FIXED_OK", uint256(1));
    }
}
