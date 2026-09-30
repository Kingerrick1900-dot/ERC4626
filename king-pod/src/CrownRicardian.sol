// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @title CrownRicardian
/// @notice On-chain Ricardian document for KE-Sov (King Errick Sovereignty).
/// @dev Legal prose is hashed + URI-bound; settlement address is the on-chain sink of the same document.
contract CrownRicardian is Ownable {
    string public constant ENTITY = "KE-Sov";
    string public constant ENTITY_LONG = "King Errick Sovereignty";

    bytes32 public legalProseHash;
    string public legalProseURI;
    address public settlement;
    uint256 public version;
    bool public incorporated; // flipped when King records EIN/bank live

    mapping(bytes32 => Offer) public offers;
    bytes32[] public offerIds;

    struct Offer {
        bytes32 counterparty; // keccak256("AnchorX"|"Conflux"|"SBI")
        address counterpartyAddr; // 0 until named
        uint256 usdcAsk; // 6 decimals
        bytes32 termsHash;
        uint8 status; // 0 draft 1 sent 2 accepted 3 rejected 4 expired
        uint64 sentAt;
    }

    event ProseBound(bytes32 indexed hash, string uri, uint256 version);
    event SettlementSet(address indexed settlement);
    event Incorporated(string ein, string bankLabel);
    event OfferOpened(bytes32 indexed id, bytes32 indexed counterparty, uint256 usdcAsk, bytes32 termsHash);
    event OfferStatus(bytes32 indexed id, uint8 status);

    error Bad();

    constructor(address owner_, address settlement_, bytes32 proseHash_, string memory proseURI_) Ownable(owner_) {
        if (settlement_ == address(0) || proseHash_ == bytes32(0)) revert Bad();
        settlement = settlement_;
        legalProseHash = proseHash_;
        legalProseURI = proseURI_;
        version = 1;
        emit SettlementSet(settlement_);
        emit ProseBound(proseHash_, proseURI_, 1);
    }

    function bindProse(bytes32 hash_, string calldata uri_) external onlyOwner {
        if (hash_ == bytes32(0)) revert Bad();
        legalProseHash = hash_;
        legalProseURI = uri_;
        unchecked {
            version++;
        }
        emit ProseBound(hash_, uri_, version);
    }

    function setSettlement(address s) external onlyOwner {
        if (s == address(0)) revert Bad();
        settlement = s;
        emit SettlementSet(s);
    }

    /// @notice King records that LLC + EIN + FDIC account are live (off-chain facts on-chain).
    function markIncorporated(string calldata ein, string calldata bankLabel) external onlyOwner {
        incorporated = true;
        emit Incorporated(ein, bankLabel);
    }

    function openOffer(bytes32 counterparty, address counterpartyAddr, uint256 usdcAsk, bytes32 termsHash)
        external
        onlyOwner
        returns (bytes32 id)
    {
        if (counterparty == bytes32(0) || usdcAsk == 0 || termsHash == bytes32(0)) revert Bad();
        id = keccak256(abi.encode(ENTITY, counterparty, usdcAsk, termsHash, block.timestamp, offerIds.length));
        offers[id] = Offer({
            counterparty: counterparty,
            counterpartyAddr: counterpartyAddr,
            usdcAsk: usdcAsk,
            termsHash: termsHash,
            status: 1,
            sentAt: uint64(block.timestamp)
        });
        offerIds.push(id);
        emit OfferOpened(id, counterparty, usdcAsk, termsHash);
        emit OfferStatus(id, 1);
    }

    function setOfferStatus(bytes32 id, uint8 status) external onlyOwner {
        if (offers[id].sentAt == 0) revert Bad();
        offers[id].status = status;
        emit OfferStatus(id, status);
    }

    function offerCount() external view returns (uint256) {
        return offerIds.length;
    }

    /// @notice Single document view: entity + prose hash + settlement (Ricardian binding).
    function document()
        external
        view
        returns (string memory entity, bytes32 proseHash, string memory proseURI, address sink, bool corp, uint256 ver)
    {
        return (ENTITY, legalProseHash, legalProseURI, settlement, incorporated, version);
    }
}
