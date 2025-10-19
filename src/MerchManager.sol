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
 * @notice Integrates BasicMerch, PremiumMerch, and EAS attestations
 */
contract MerchManager is Ownable, ReentrancyGuard {
    
    // Contract references
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    EASIntegration public easIntegration;
    
    // Event tracking
    mapping(bytes32 => bool) public registeredEvents;
    mapping(bytes32 => string) public eventMetadata;
    
    // Events
    event EventRegistered(bytes32 indexed eventId, string metadata);
    event SBTMintedWithAttestation(
        address indexed user,
        uint256 indexed tokenId,
        bytes32 indexed eventId,
        bytes32 attestationId
    );
    event SBTUpgradedWithAttestation(
        address indexed user,
        uint256 indexed sbtId,
        uint256 indexed premiumId,
        bytes32 attestationId
    );
    
    // Errors
    error EventNotRegistered();
    error ContractNotSet();
    error InvalidEventId();
    
    constructor(
        address _basicMerch,
        address _premiumMerch,
        address _easIntegration
    ) Ownable(msg.sender) {
        basicMerch = BasicMerch(_basicMerch);
        premiumMerch = PremiumMerch(_premiumMerch);
        easIntegration = EASIntegration(_easIntegration);
    }
    
    /**
     * @dev Register a new event
     * @param _eventId The unique event identifier
     * @param _metadata Event metadata (name, description, etc.)
     */
    function registerEvent(bytes32 _eventId, string memory _metadata) external onlyOwner {
        _registerEvent(_eventId, _metadata);
    }
    
    function _registerEvent(bytes32 _eventId, string memory _metadata) internal {
        require(_eventId != bytes32(0), "Invalid event ID");
        require(!registeredEvents[_eventId], "Event already registered");
        
        registeredEvents[_eventId] = true;
        eventMetadata[_eventId] = _metadata;
        
        emit EventRegistered(_eventId, _metadata);
    }
    
    /**
     * @dev Mint SBT with automatic attestation creation
     * @param _to The recipient address
     * @param _tokenURI The token metadata URI
     * @param _eventId The event ID for attestation
     * @return uint256 The minted token ID
     * @return bytes32 The created attestation ID
     */
    function mintSBTWithAttestation(
        address _to,
        string memory _tokenURI,
        bytes32 _eventId
    ) external nonReentrant returns (uint256, bytes32) {
        // Verify event is registered
        if (!registeredEvents[_eventId]) {
            revert EventNotRegistered();
        }
        
        // Mint the SBT
        uint256 tokenId = basicMerch.mintSBT(_to, _tokenURI);
        
        // Create attestation (isPremiumUpgrade = false for basic SBT)
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
     * @dev Upgrade SBT to Premium with automatic attestation creation
     * @param _sbtId The SBT ID to upgrade
     * @param _organizer The organizer address for fee distribution
     * @param _eventId The event ID for attestation
     * @return uint256 The premium token ID
     * @return bytes32 The created attestation ID
     */
    function upgradeSBTWithAttestation(
        uint256 _sbtId,
        address _organizer,
        bytes32 _eventId
    ) external payable nonReentrant returns (uint256, bytes32) {
        // Verify event is registered
        if (!registeredEvents[_eventId]) {
            revert EventNotRegistered();
        }
        
        // Upgrade the SBT (this will burn the SBT and mint premium NFT)
        premiumMerch.upgradeSBT{value: msg.value}(_sbtId, _organizer);
        
        // Get the premium token ID from the mapping
        uint256 premiumId = premiumMerch.getPremiumTokenId(_sbtId);
        
        // Create attestation (isPremiumUpgrade = true for premium upgrade)
        bytes32 attestationId = easIntegration.createAttendanceAttestation(
            _eventId,
            msg.sender,
            premiumId,
            true
        );
        
        emit SBTUpgradedWithAttestation(msg.sender, _sbtId, premiumId, attestationId);
        
        return (premiumId, attestationId);
    }
    
    /**
     * @dev Get user's attendance history
     * @param _user The user address
     * @return bytes32[] Array of attestation IDs
     */
    function getUserAttendanceHistory(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getUserAttestations(_user);
    }
    
    /**
     * @dev Get event attendance list
     * @param _eventId The event ID
     * @return bytes32[] Array of attestation IDs
     */
    function getEventAttendance(bytes32 _eventId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getEventAttestations(_eventId);
    }
    
    /**
     * @dev Check if user attended a specific event
     * @param _user The user address
     * @param _eventId The event ID
     * @return bool True if user attended the event
     */
    function hasUserAttendedEvent(address _user, bytes32 _eventId) 
        external 
        view 
        returns (bool) 
    {
        return easIntegration.hasUserAttendedEvent(_user, _eventId);
    }
    
    /**
     * @dev Get user's premium upgrades
     * @param _user The user address
     * @return bytes32[] Array of premium upgrade attestation IDs
     */
    function getUserPremiumUpgrades(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return easIntegration.getUserPremiumUpgrades(_user);
    }
    
    /**
     * @dev Get event metadata
     * @param _eventId The event ID
     * @return string The event metadata
     */
    function getEventMetadata(bytes32 _eventId) external view returns (string memory) {
        return eventMetadata[_eventId];
    }
    
    /**
     * @dev Update contract references
     * @param _basicMerch New basic merch contract address
     * @param _premiumMerch New premium merch contract address
     * @param _easIntegration New EAS integration contract address
     */
    function updateContracts(
        address _basicMerch,
        address _premiumMerch,
        address _easIntegration
    ) external onlyOwner {
        require(_basicMerch != address(0), "Invalid basic merch address");
        require(_premiumMerch != address(0), "Invalid premium merch address");
        require(_easIntegration != address(0), "Invalid EAS integration address");
        
        basicMerch = BasicMerch(_basicMerch);
        premiumMerch = PremiumMerch(_premiumMerch);
        easIntegration = EASIntegration(_easIntegration);
    }
    
    /**
     * @dev Batch register events
     * @param _eventIds Array of event IDs
     * @param _metadataArray Array of metadata strings
     */
    function batchRegisterEvents(
        bytes32[] memory _eventIds,
        string[] memory _metadataArray
    ) external onlyOwner {
        require(_eventIds.length == _metadataArray.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _eventIds.length; i++) {
            _registerEvent(_eventIds[i], _metadataArray[i]);
        }
    }
    
    /**
     * @dev Get contract addresses
     * @return address Basic merch contract address
     * @return address Premium merch contract address
     * @return address EAS integration contract address
     */
    function getContractAddresses() 
        external 
        view 
        returns (address, address, address) 
    {
        return (address(basicMerch), address(premiumMerch), address(easIntegration));
    }
}
