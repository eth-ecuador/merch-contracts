// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BasicMerch.sol";
import "./PremiumMerch.sol";
import "./EASIntegration.sol";

/**
 * @title MerchManager
 * @dev Main contract that orchestrates the entire Merch MVP system
 * @notice ✅ UPDATED: Now supports DYNAMIC event creation by ANY user
 * @notice Integrates BasicMerch, PremiumMerch, and EAS attestations
 */
contract MerchManager is Ownable, ReentrancyGuard {
    
    // Contract references
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    EASIntegration public easIntegration;
    
    // ============ NEW: Dynamic Event System ============
    
    struct Event {
        string name;
        string description;
        string imageURI;        // IPFS hash or backend URL
        address creator;        // Who created the event
        bool isActive;
        uint256 createdAt;
        uint256 totalAttendees;
        uint256 maxAttendees;   // 0 = unlimited
    }
    
    // eventId => Event
    mapping(bytes32 => Event) public events;
    
    // List of all event IDs
    bytes32[] public allEventIds;
    
    // creator => eventIds[]
    mapping(address => bytes32[]) public eventsByCreator;
    
    // OLD: Keep for backward compatibility
    mapping(bytes32 => bool) public registeredEvents;  // Now auto-set when event created
    mapping(bytes32 => string) public eventMetadata;   // Now derived from Event struct
    
    // ============ Events ============
    
    event EventCreated(
        bytes32 indexed eventId,
        address indexed creator,
        string name,
        string description,
        string imageURI,
        uint256 maxAttendees,
        uint256 timestamp
    );
    
    event EventUpdated(
        bytes32 indexed eventId,
        string name,
        string description,
        string imageURI
    );
    
    event EventStatusChanged(
        bytes32 indexed eventId,
        bool isActive
    );
    
    event EventRegistered(bytes32 indexed eventId, string metadata);  // Keep for compatibility
    
    event SBTMintedWithAttestation(
        address indexed user,
        uint256 indexed tokenId,
        bytes32 indexed eventId,
        bytes32 attestationId
    );
    
    event CompanionMintedWithAttestation(
        address indexed user,
        uint256 indexed sbtId,
        uint256 indexed premiumId,
        bytes32 eventId,
        bytes32 attestationId
    );
    
    event ContractsUpdated(
        address indexed basicMerch,
        address indexed premiumMerch,
        address indexed easIntegration
    );
    
    // ============ Errors ============
    
    error EventNotRegistered();
    error EventAlreadyRegistered();
    error InvalidEventId();
    error InvalidAddress();
    error ArrayLengthMismatch();
    error NotEventCreator();
    error EventNotActive();
    error EventFull();
    error EmptyEventName();
    error EmptyImageURI();
    
    constructor(
        address _basicMerch,
        address _premiumMerch,
        address _easIntegration
    ) Ownable(msg.sender) {
        if (_basicMerch == address(0)) revert InvalidAddress();
        if (_premiumMerch == address(0)) revert InvalidAddress();
        if (_easIntegration == address(0)) revert InvalidAddress();
        
        basicMerch = BasicMerch(_basicMerch);
        premiumMerch = PremiumMerch(_premiumMerch);
        easIntegration = EASIntegration(_easIntegration);
    }
    
    // ============================================================
    // NEW: PUBLIC EVENT CREATION
    // ============================================================
    
    /**
     * @dev ✅ NEW: Create event - ANYONE can call this
     * @param _name Event name
     * @param _description Event description
     * @param _imageURI IPFS hash or backend URL
     * @param _maxAttendees Maximum attendees (0 = unlimited)
     * @return bytes32 The generated event ID
     */
    function createEvent(
        string memory _name,
        string memory _description,
        string memory _imageURI,
        uint256 _maxAttendees
    ) external returns (bytes32) {
        if (bytes(_name).length == 0) revert EmptyEventName();
        if (bytes(_imageURI).length == 0) revert EmptyImageURI();
        
        // Generate unique eventId based on: creator + name + timestamp + nonce
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender,
                _name,
                block.timestamp,
                allEventIds.length
            )
        );
        
        // Verify doesn't exist (virtually impossible with above logic)
        if (events[eventId].createdAt != 0) revert EventAlreadyRegistered();
        
        // Create event
        events[eventId] = Event({
            name: _name,
            description: _description,
            imageURI: _imageURI,
            creator: msg.sender,
            isActive: true,
            createdAt: block.timestamp,
            totalAttendees: 0,
            maxAttendees: _maxAttendees
        });
        
        // Add to lists
        allEventIds.push(eventId);
        eventsByCreator[msg.sender].push(eventId);
        
        // Set compatibility mappings
        registeredEvents[eventId] = true;
        eventMetadata[eventId] = string(abi.encodePacked(
            '{"name":"', _name,
            '","description":"', _description,
            '","imageURI":"', _imageURI, '"}'
        ));
        
        // Emit events (both new and old for compatibility)
        emit EventCreated(
            eventId,
            msg.sender,
            _name,
            _description,
            _imageURI,
            _maxAttendees,
            block.timestamp
        );
        
        emit EventRegistered(eventId, eventMetadata[eventId]);
        
        return eventId;
    }
    
    /**
     * @dev Update event info (only creator)
     */
    function updateEvent(
        bytes32 _eventId,
        string memory _name,
        string memory _description,
        string memory _imageURI
    ) external {
        Event storage evt = events[_eventId];
        
        if (evt.createdAt == 0) revert EventNotRegistered();
        if (evt.creator != msg.sender) revert NotEventCreator();
        
        if (bytes(_name).length > 0) {
            evt.name = _name;
        }
        if (bytes(_description).length > 0) {
            evt.description = _description;
        }
        if (bytes(_imageURI).length > 0) {
            evt.imageURI = _imageURI;
        }
        
        // Update compatibility mapping
        eventMetadata[_eventId] = string(abi.encodePacked(
            '{"name":"', evt.name,
            '","description":"', evt.description,
            '","imageURI":"', evt.imageURI, '"}'
        ));
        
        emit EventUpdated(_eventId, evt.name, evt.description, evt.imageURI);
    }
    
    /**
     * @dev Activate/deactivate event (only creator)
     */
    function setEventStatus(bytes32 _eventId, bool _isActive) external {
        Event storage evt = events[_eventId];
        
        if (evt.createdAt == 0) revert EventNotRegistered();
        if (evt.creator != msg.sender) revert NotEventCreator();
        
        evt.isActive = _isActive;
        registeredEvents[_eventId] = _isActive;  // Update compatibility mapping
        
        emit EventStatusChanged(_eventId, _isActive);
    }
    
    // ============================================================
    // BACKWARD COMPATIBILITY: Old registerEvent (admin only)
    // ============================================================
    
    /**
     * @dev Register event (OLD METHOD - admin only, for backward compatibility)
     */
    function registerEvent(bytes32 _eventId, string memory _metadata) external onlyOwner {
        _registerEvent(_eventId, _metadata);
    }
    
    function _registerEvent(bytes32 _eventId, string memory _metadata) internal {
        if (_eventId == bytes32(0)) revert InvalidEventId();
        if (registeredEvents[_eventId]) revert EventAlreadyRegistered();
        
        registeredEvents[_eventId] = true;
        eventMetadata[_eventId] = _metadata;
        
        // Create minimal Event struct for compatibility
        if (events[_eventId].createdAt == 0) {
            events[_eventId] = Event({
                name: "Legacy Event",
                description: _metadata,
                imageURI: "",
                creator: owner(),
                isActive: true,
                createdAt: block.timestamp,
                totalAttendees: 0,
                maxAttendees: 0
            });
            allEventIds.push(_eventId);
        }
        
        emit EventRegistered(_eventId, _metadata);
    }
    
    // ============================================================
    // MINTING WITH SIGNATURE (Existing functionality)
    // ============================================================
    
    /**
     * @dev ✅ UPDATED: Mint SBT with signature + check maxAttendees
     */
    function mintSBTWithAttestation(
        address _to,
        string memory _tokenURI,
        bytes32 _eventId,
        bytes memory _signature
    ) external nonReentrant returns (uint256, bytes32) {
        Event storage evt = events[_eventId];
        
        // Verify event exists and is active
        if (!registeredEvents[_eventId]) revert EventNotRegistered();
        if (evt.createdAt > 0 && !evt.isActive) revert EventNotActive();
        
        // Check maxAttendees (only if event created with new system)
        if (evt.maxAttendees > 0 && evt.totalAttendees >= evt.maxAttendees) {
            revert EventFull();
        }
        
        // Mint SBT with signature verification
        uint256 tokenId = basicMerch.mintSBT(
            _to, 
            uint256(_eventId), 
            _tokenURI, 
            _signature
        );
        
        // Increment attendee count
        if (evt.createdAt > 0) {
            evt.totalAttendees++;
        }
        
        // Create attestation
        bytes32 attestationId = easIntegration.createAttendanceAttestation(
            _eventId,
            _to,
            tokenId,
            false
        );
        
        emit SBTMintedWithAttestation(_to, tokenId, _eventId, attestationId);
        
        return (tokenId, attestationId);
    }
    
    /**
     * @dev Mint Premium companion (unchanged)
     */
    function mintCompanionWithAttestation(
        uint256 _sbtId,
        address _organizer,
        bytes32 _eventId
    ) external payable nonReentrant returns (uint256, bytes32) {
        if (!registeredEvents[_eventId]) revert EventNotRegistered();
        
        premiumMerch.mintCompanion{value: msg.value}(_sbtId, _organizer, msg.sender);
        uint256 premiumId = premiumMerch.getPremiumTokenId(_sbtId);
        
        bytes32 attestationId = easIntegration.createAttendanceAttestation(
            _eventId,
            msg.sender,
            premiumId,
            true
        );
        
        emit CompanionMintedWithAttestation(msg.sender, _sbtId, premiumId, _eventId, attestationId);
        
        return (premiumId, attestationId);
    }
    
    // ============================================================
    // VIEW FUNCTIONS
    // ============================================================
    
    /**
     * @dev Get event details
     */
    function getEvent(bytes32 _eventId) external view returns (
        string memory name,
        string memory description,
        string memory imageURI,
        address creator,
        bool isActive,
        uint256 createdAt,
        uint256 totalAttendees,
        uint256 maxAttendees
    ) {
        Event storage evt = events[_eventId];
        return (
            evt.name,
            evt.description,
            evt.imageURI,
            evt.creator,
            evt.isActive,
            evt.createdAt,
            evt.totalAttendees,
            evt.maxAttendees
        );
    }
    
    /**
     * @dev Get all events
     */
    function getAllEvents() external view returns (bytes32[] memory) {
        return allEventIds;
    }
    
    /**
     * @dev Get events by creator
     */
    function getEventsByCreator(address _creator) external view returns (bytes32[] memory) {
        return eventsByCreator[_creator];
    }
    
    /**
     * @dev Check if event is active
     */
    function isEventActive(bytes32 _eventId) external view returns (bool) {
        return events[_eventId].isActive && registeredEvents[_eventId];
    }
    
    /**
     * @dev Get remaining spots
     */
    function getRemainingSpots(bytes32 _eventId) external view returns (uint256) {
        Event storage evt = events[_eventId];
        if (evt.maxAttendees == 0) return type(uint256).max;  // Unlimited
        if (evt.totalAttendees >= evt.maxAttendees) return 0;
        return evt.maxAttendees - evt.totalAttendees;
    }
    
    // ============================================================
    // EXISTING VIEW FUNCTIONS (Unchanged)
    // ============================================================
    
    function getUserAttendanceHistory(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getUserAttestations(_user);
    }
    
    function getEventAttendance(bytes32 _eventId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getEventAttestations(_eventId);
    }
    
    function hasUserAttendedEvent(address _user, bytes32 _eventId) 
        external 
        view 
        returns (bool) 
    {
        return easIntegration.hasUserAttendedEvent(_user, _eventId);
    }
    
    function getUserPremiumUpgrades(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getUserPremiumUpgrades(_user);
    }
    
    function getEventMetadata(bytes32 _eventId) external view returns (string memory) {
        return eventMetadata[_eventId];
    }
    
    function isEventRegistered(bytes32 _eventId) external view returns (bool) {
        return registeredEvents[_eventId];
    }
    
    // ============================================================
    // ADMIN FUNCTIONS (Unchanged)
    // ============================================================
    
    function updateContracts(
        address _basicMerch,
        address _premiumMerch,
        address _easIntegration
    ) external onlyOwner {
        if (_basicMerch == address(0)) revert InvalidAddress();
        if (_premiumMerch == address(0)) revert InvalidAddress();
        if (_easIntegration == address(0)) revert InvalidAddress();
        
        basicMerch = BasicMerch(_basicMerch);
        premiumMerch = PremiumMerch(_premiumMerch);
        easIntegration = EASIntegration(_easIntegration);
        
        emit ContractsUpdated(_basicMerch, _premiumMerch, _easIntegration);
    }
    
    function batchRegisterEvents(
        bytes32[] memory _eventIds,
        string[] memory _metadataArray
    ) external onlyOwner {
        uint256 length = _eventIds.length;
        if (length != _metadataArray.length) revert ArrayLengthMismatch();
        
        for (uint256 i = 0; i < length;) {
            _registerEvent(_eventIds[i], _metadataArray[i]);
            unchecked { ++i; }
        }
    }
    
    function getContractAddresses() 
        external 
        view 
        returns (address, address, address) 
    {
        return (address(basicMerch), address(premiumMerch), address(easIntegration));
    }
    
    function getUpgradeFee() external view returns (uint256) {
        return premiumMerch.upgradeFee();
    }
    
    function canUserMintCompanion(uint256 _sbtId, address _user) 
        external 
        view 
        returns (bool, string memory) 
    {
        return premiumMerch.canMintCompanion(_sbtId, _user);
    }
}
