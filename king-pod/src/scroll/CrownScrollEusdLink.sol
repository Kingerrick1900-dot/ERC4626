// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable, ReentrancyGuard} from "../core/Core.sol";

interface IScrollEusdMint {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
    function transferFrom(address from, address to, uint256 amt) external returns (bool);
    function isMinter(address) external view returns (bool);
}

/// @notice Scroll leg of Base↔Scroll eUSD link. Mint Scroll eUSD against Base locks.
/// @dev King (or minter) mints after Base lock; burn path for reverse bridge.
contract CrownScrollEusdLink is Ownable, ReentrancyGuard {
    IScrollEusdMint public immutable eusd;
    address public immutable landing;

    mapping(uint256 => bool) public baseLockUsed; // base lockId consumed
    mapping(bytes32 => bool) public baseTxUsed;

    event MintedFromBase(address indexed to, uint256 amt, uint256 indexed baseLockId, bytes32 baseTx);
    event BurnedForBase(address indexed from, uint256 amt, uint256 indexed ticketId);
    event TicketOpened(uint256 indexed ticketId, address indexed from, uint256 amt, address baseTo);

    uint256 public burnNonce;

    struct BurnTicket {
        address from;
        address baseTo;
        uint256 amt;
        bool open;
    }

    mapping(uint256 => BurnTicket) public tickets;

    error BadAmt();
    error Used();
    error NotMinter();

    constructor(address eusd_, address landing_, address owner_) Ownable(owner_) {
        eusd = IScrollEusdMint(eusd_);
        landing = landing_;
    }

    /// @notice Mint Scroll eUSD 1:1 for a Base lock (king-attested).
    function mintFromBase(address to, uint256 amt, uint256 baseLockId, bytes32 baseTx)
        external
        onlyOwner
        nonReentrant
    {
        if (amt == 0 || to == address(0)) revert BadAmt();
        if (baseLockUsed[baseLockId] || baseTxUsed[baseTx]) revert Used();
        if (!eusd.isMinter(address(this))) revert NotMinter();
        baseLockUsed[baseLockId] = true;
        baseTxUsed[baseTx] = true;
        eusd.mint(to, amt);
        emit MintedFromBase(to, amt, baseLockId, baseTx);
    }

    /// @notice User burns Scroll eUSD to open a Base unlock ticket.
    function burnForBase(uint256 amt, address baseTo) external nonReentrant returns (uint256 ticketId) {
        if (amt == 0) revert BadAmt();
        if (baseTo == address(0)) baseTo = msg.sender;
        if (!eusd.isMinter(address(this))) revert NotMinter();
        // pull then burn
        require(eusd.transferFrom(msg.sender, address(this), amt), "PULL");
        eusd.burn(address(this), amt);
        ticketId = ++burnNonce;
        tickets[ticketId] = BurnTicket({from: msg.sender, baseTo: baseTo, amt: amt, open: true});
        emit BurnedForBase(msg.sender, amt, ticketId);
        emit TicketOpened(ticketId, msg.sender, amt, baseTo);
    }

    function closeTicket(uint256 ticketId) external onlyOwner {
        tickets[ticketId].open = false;
    }
}
