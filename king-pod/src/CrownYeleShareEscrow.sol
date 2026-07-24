// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Buyer pays USDC to Landing, receives yELE shares. Permissionless take after list.
interface IERC20E {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract CrownYeleShareEscrow {
    address public immutable yele;
    address public immutable usdc;
    address public immutable landing;
    address public owner;

    uint256 public listedShares;
    uint256 public usdcAsk;

    event Listed(uint256 shares, uint256 usdcAsk);
    event Taken(address indexed buyer, uint256 shares, uint256 usdcPaid);

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER");
        _;
    }

    constructor(address yele_, address usdc_, address landing_, address owner_) {
        yele = yele_;
        usdc = usdc_;
        landing = landing_;
        owner = owner_;
    }

    function list(uint256 shares, uint256 ask) external onlyOwner {
        require(shares > 0 && ask > 0, "PARAMS");
        require(IERC20E(yele).transferFrom(msg.sender, address(this), shares), "PULL");
        listedShares += shares;
        usdcAsk = ask;
        emit Listed(shares, ask);
    }

    /// @notice Pay exact usdcAsk to Landing, receive listedShares.
    function take() external {
        uint256 shares = listedShares;
        uint256 ask = usdcAsk;
        require(shares > 0 && ask > 0, "EMPTY");
        listedShares = 0;
        usdcAsk = 0;
        require(IERC20E(usdc).transferFrom(msg.sender, landing, ask), "USDC");
        require(IERC20E(yele).transfer(msg.sender, shares), "SHARES");
        emit Taken(msg.sender, shares, ask);
    }

    function cancel() external onlyOwner {
        uint256 shares = listedShares;
        listedShares = 0;
        usdcAsk = 0;
        if (shares > 0) require(IERC20E(yele).transfer(landing, shares), "RET");
    }
}
