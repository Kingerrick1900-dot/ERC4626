// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Morpho-standard vault bootstrap: emit Elepan to EXTERNAL yELEPAN depositors.
/// @dev Morpho docs call this "Bootstrap a new vault to attract initial liquidity"
///      (vault-level incentives). Forum standard: focus incentives on lenders first;
///      blacklist treasury so budget does not self-pay (Morpho reward-campaign blacklisting).
///
///      When eligibleSupply == 0 (today: Landing holds ~100% shares), the rate does not
///      advance — budget waits for the first external USDC depositor. That is intentional.
interface IERC20Stream {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IShareVault {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract CrownYelepanStream {
    IERC20Stream public immutable rewardToken;
    IShareVault public immutable vault;
    address public owner;

    uint256 public rewardRate; // reward-token raw units / second
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerShareStored; // 1e18 scale

    mapping(address => bool) public blacklisted;
    address[] public blacklistList;

    mapping(address => uint256) public userRewardPerSharePaid;
    mapping(address => uint256) public rewards;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BlacklistSet(address indexed account, bool blocked);
    event Notified(uint256 amount, uint256 duration, uint256 rewardRate, uint256 periodFinish);
    event RewardPaid(address indexed user, uint256 amount);
    event Recovered(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER");
        _;
    }

    constructor(address rewardToken_, address vault_, address owner_) {
        require(rewardToken_ != address(0) && vault_ != address(0) && owner_ != address(0), "ZERO");
        rewardToken = IERC20Stream(rewardToken_);
        vault = IShareVault(vault_);
        owner = owner_;
        lastUpdateTime = block.timestamp;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setBlacklist(address account, bool blocked) external onlyOwner {
        require(account != address(0), "ZERO");
        if (blocked && !blacklisted[account]) {
            blacklisted[account] = true;
            blacklistList.push(account);
        } else if (!blocked && blacklisted[account]) {
            blacklisted[account] = false;
            // leave hole in list; eligibleSupply skips non-blacklisted entries
        } else {
            blacklisted[account] = blocked;
        }
        emit BlacklistSet(account, blocked);
    }

    /// @notice Shares that earn rewards = totalSupply − blacklisted balances.
    function eligibleSupply() public view returns (uint256) {
        uint256 ts = vault.totalSupply();
        uint256 blocked;
        uint256 n = blacklistList.length;
        for (uint256 i; i < n; ++i) {
            address a = blacklistList[i];
            if (blacklisted[a]) {
                blocked += vault.balanceOf(a);
            }
        }
        return ts > blocked ? ts - blocked : 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        if (periodFinish == 0) {
            return lastUpdateTime;
        }
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerShare() public view returns (uint256) {
        uint256 supply = eligibleSupply();
        uint256 applicable = lastTimeRewardApplicable();
        if (supply == 0 || applicable <= lastUpdateTime || rewardRate == 0) {
            return rewardPerShareStored;
        }
        uint256 dt = applicable - lastUpdateTime;
        return rewardPerShareStored + (dt * rewardRate * 1e18) / supply;
    }

    function earned(address account) public view returns (uint256) {
        if (blacklisted[account]) {
            return 0;
        }
        uint256 shares = vault.balanceOf(account);
        return (shares * (rewardPerShare() - userRewardPerSharePaid[account])) / 1e18 + rewards[account];
    }

    function _updateReward(address account) internal {
        rewardPerShareStored = rewardPerShare();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0) && !blacklisted[account]) {
            rewards[account] = earned(account);
            userRewardPerSharePaid[account] = rewardPerShareStored;
        }
    }

    /// @notice Pull `amount` reward tokens from owner and stream them over `duration` seconds.
    /// @dev Morpho forum default lens: 90 days, front-loaded later; King chooses duration.
    function notifyRewardAmount(uint256 amount, uint256 duration) external onlyOwner {
        require(amount > 0 && duration > 0, "PARAMS");
        _updateReward(address(0));

        require(rewardToken.transferFrom(msg.sender, address(this), amount), "PULL");

        if (block.timestamp >= periodFinish) {
            rewardRate = amount / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (amount + leftover) / duration;
        }
        require(rewardRate > 0, "RATE_ZERO");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit Notified(amount, duration, rewardRate, periodFinish);
    }

    function claim(address account) public {
        _updateReward(account);
        uint256 due = rewards[account];
        if (due > 0) {
            rewards[account] = 0;
            require(rewardToken.transfer(account, due), "XFER");
            emit RewardPaid(account, due);
        }
    }

    function claim() external {
        claim(msg.sender);
    }

    /// @notice Rescue leftover reward tokens after the stream ends (or mistaken ERC20s).
    function recover(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "ZERO");
        if (token == address(rewardToken)) {
            require(block.timestamp >= periodFinish, "STREAM_LIVE");
        }
        require(IERC20Stream(token).transfer(owner, amount), "XFER");
        emit Recovered(token, amount);
    }
}
