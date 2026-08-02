// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

/// @notice Minimal CCIP / LayerZero message router surface.
interface ICcipRouter {
    function ccipSend(uint64 destinationChainSelector, bytes calldata message) external payable returns (bytes32);
}

interface ILayerZeroEndpointV2 {
    function send(
        uint32 dstEid,
        bytes32 receiver,
        bytes calldata message,
        bytes calldata options,
        bool payInLzToken
    ) external payable returns (bytes32);
}

interface IBaseEusdLink {
    function lockForScroll(uint256 amt, address scrollTo) external;
    function unlock(address to, uint256 amt, bytes32 scrollBurnId) external;
}

interface IScrollEusdLink {
    function mintFromBase(address to, uint256 amt, bytes32 baseLockId, bytes32 baseTx) external;
    function burnForBase(uint256 amt, address baseTo) external;
}

/// @notice Cross-chain settlement layer: Base eUSD ↔ Scroll kXAU PSM balance sheet sync.
/// @dev Speaks CCIP + LayerZero endpoints when wired; falls back to kingdom eUSD links already live.
contract CrownCrossChainSettlement is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    enum Rail {
        Link, // existing Base/Scroll eUSD links
        Ccip,
        LayerZero
    }

    IERC20 public immutable eusd;
    address public peerAddr; // twin settlement on the other chain
    address public baseLink; // Base: CrownBaseEusdLink
    address public scrollLink; // Scroll: CrownScrollEusdLink
    address public ccipRouter;
    address public lzEndpoint;
    uint64 public peerCcipSelector;
    uint32 public peerLzEid;
    Rail public defaultRail = Rail.Link;

    bytes32 public constant MSG_LOCK = keccak256("LOCK");
    bytes32 public constant MSG_BURN = keccak256("BURN");
    bytes32 public constant MSG_SYNC = keccak256("SYNC");

    mapping(bytes32 => bool) public processed;
    uint256 public lockedTowardScroll;
    uint256 public mintedFromBase;

    event RailSet(Rail rail);
    event PeerSet(address peer, uint64 ccipSelector, uint32 lzEid);
    event EndpointsSet(address ccip, address lz, address baseLink, address scrollLink);
    event LockedForScroll(address indexed from, address indexed scrollTo, uint256 amt, bytes32 msgId, Rail rail);
    event ReleasedOnScroll(address indexed to, uint256 amt, bytes32 srcId);
    event BurnedForBase(address indexed from, address indexed baseTo, uint256 amt, bytes32 msgId, Rail rail);
    event UnlockedOnBase(address indexed to, uint256 amt, bytes32 srcId);
    event SyncPosted(bytes32 indexed kind, uint256 amt, bytes32 msgId);

    error BadRail();
    error BadPeer();
    error Replay();
    error BadAmt();

    constructor(address eusd_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0), "EUSD");
        eusd = IERC20(eusd_);
    }

    function setDefaultRail(Rail r) external onlyOwner {
        defaultRail = r;
        emit RailSet(r);
    }

    function setPeer(address peer_, uint64 ccipSelector, uint32 lzEid) external onlyOwner {
        peerAddr = peer_;
        peerCcipSelector = ccipSelector;
        peerLzEid = lzEid;
        emit PeerSet(peer_, ccipSelector, lzEid);
    }

    function setEndpoints(address ccip, address lz, address baseLink_, address scrollLink_) external onlyOwner {
        ccipRouter = ccip;
        lzEndpoint = lz;
        baseLink = baseLink_;
        scrollLink = scrollLink_;
        emit EndpointsSet(ccip, lz, baseLink_, scrollLink_);
    }

    /// @notice Base → Scroll: lock Base eUSD and dispatch mint instruction.
    function settleToScroll(uint256 amt, address scrollTo, Rail rail) external payable nonReentrant returns (bytes32 msgId) {
        if (amt == 0) revert BadAmt();
        if (scrollTo == address(0)) scrollTo = msg.sender;
        if (uint8(rail) > uint8(Rail.LayerZero)) rail = defaultRail;

        eusd.safeTransferFrom(msg.sender, address(this), amt);

        if (rail == Rail.Link) {
            require(baseLink != address(0), "BASE_LINK");
            eusd.safeApprove(baseLink, amt);
            IBaseEusdLink(baseLink).lockForScroll(amt, scrollTo);
            msgId = keccak256(abi.encode(MSG_LOCK, msg.sender, scrollTo, amt, block.number));
        } else {
            msgId = _dispatch(rail, abi.encode(MSG_LOCK, scrollTo, amt, msg.sender));
        }

        lockedTowardScroll += amt;
        emit LockedForScroll(msg.sender, scrollTo, amt, msgId, rail);
    }

    /// @notice Scroll inbox: mint from Base lock (king/relay or LZ/CCIP callback).
    function receiveLockOnScroll(address to, uint256 amt, bytes32 srcId) external nonReentrant {
        require(msg.sender == owner || msg.sender == peerAddr || msg.sender == lzEndpoint || msg.sender == ccipRouter, "AUTH");
        if (processed[srcId]) revert Replay();
        processed[srcId] = true;
        require(scrollLink != address(0), "SCROLL_LINK");
        IScrollEusdLink(scrollLink).mintFromBase(to, amt, srcId, srcId);
        mintedFromBase += amt;
        emit ReleasedOnScroll(to, amt, srcId);
    }

    /// @notice Scroll → Base: burn Scroll eUSD and dispatch unlock.
    function settleToBase(uint256 amt, address baseTo, Rail rail) external payable nonReentrant returns (bytes32 msgId) {
        if (amt == 0) revert BadAmt();
        if (baseTo == address(0)) baseTo = msg.sender;
        if (uint8(rail) > uint8(Rail.LayerZero)) rail = defaultRail;

        eusd.safeTransferFrom(msg.sender, address(this), amt);

        if (rail == Rail.Link) {
            require(scrollLink != address(0), "SCROLL_LINK");
            eusd.safeApprove(scrollLink, amt);
            IScrollEusdLink(scrollLink).burnForBase(amt, baseTo);
            msgId = keccak256(abi.encode(MSG_BURN, msg.sender, baseTo, amt, block.number));
        } else {
            msgId = _dispatch(rail, abi.encode(MSG_BURN, baseTo, amt, msg.sender));
        }
        emit BurnedForBase(msg.sender, baseTo, amt, msgId, rail);
    }

    /// @notice Base inbox: unlock from Scroll burn.
    function receiveBurnOnBase(address to, uint256 amt, bytes32 srcId) external nonReentrant {
        require(msg.sender == owner || msg.sender == peerAddr || msg.sender == lzEndpoint || msg.sender == ccipRouter, "AUTH");
        if (processed[srcId]) revert Replay();
        processed[srcId] = true;
        require(baseLink != address(0), "BASE_LINK");
        IBaseEusdLink(baseLink).unlock(to, amt, srcId);
        emit UnlockedOnBase(to, amt, srcId);
    }

    /// @notice Balance-sheet sync ping (PoR snapshot hash across chains).
    function syncReserve(bytes32 kind, uint256 amt) external onlyOwner returns (bytes32 msgId) {
        msgId = keccak256(abi.encode(MSG_SYNC, kind, amt, block.timestamp));
        emit SyncPosted(kind, amt, msgId);
        if (defaultRail == Rail.Ccip || defaultRail == Rail.LayerZero) {
            _dispatch(defaultRail, abi.encode(MSG_SYNC, kind, amt));
        }
    }

    /// @notice CCIP receive entrypoint (router-compatible).
    function ccipReceive(bytes calldata message) external {
        require(msg.sender == ccipRouter || msg.sender == owner, "AUTH");
        _handleMessage(message);
    }

    /// @notice LayerZero receive entrypoint (endpoint-compatible).
    function lzReceive(uint32, bytes32, bytes calldata message, address, bytes calldata) external {
        require(msg.sender == lzEndpoint || msg.sender == owner, "AUTH");
        _handleMessage(message);
    }

    function _dispatch(Rail rail, bytes memory payload) internal returns (bytes32 msgId) {
        if (rail == Rail.Ccip) {
            require(ccipRouter != address(0) && peerCcipSelector != 0, "CCIP");
            msgId = ICcipRouter(ccipRouter).ccipSend{value: msg.value}(peerCcipSelector, payload);
        } else if (rail == Rail.LayerZero) {
            require(lzEndpoint != address(0) && peerAddr != address(0), "LZ");
            msgId = ILayerZeroEndpointV2(lzEndpoint).send{value: msg.value}(
                peerLzEid, bytes32(uint256(uint160(peerAddr))), payload, bytes(""), false
            );
        } else {
            revert BadRail();
        }
    }

    function _handleMessage(bytes calldata message) internal {
        bytes32 kind = abi.decode(message, (bytes32));
        if (kind == MSG_LOCK) {
            (, address to, uint256 amt, ) = abi.decode(message, (bytes32, address, uint256, address));
            bytes32 srcId = keccak256(message);
            if (processed[srcId]) revert Replay();
            // mint path when this contract is on Scroll
            if (scrollLink != address(0)) {
                processed[srcId] = true;
                IScrollEusdLink(scrollLink).mintFromBase(to, amt, srcId, srcId);
                mintedFromBase += amt;
                emit ReleasedOnScroll(to, amt, srcId);
            }
        } else if (kind == MSG_BURN) {
            (, address to, uint256 amt, ) = abi.decode(message, (bytes32, address, uint256, address));
            bytes32 srcId = keccak256(message);
            if (processed[srcId]) revert Replay();
            if (baseLink != address(0)) {
                processed[srcId] = true;
                IBaseEusdLink(baseLink).unlock(to, amt, srcId);
                emit UnlockedOnBase(to, amt, srcId);
            }
        }
    }
}
