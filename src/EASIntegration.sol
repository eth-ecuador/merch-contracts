// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EASIntegration
 * @dev Ethereum Attestation Service integration for attendance tracking
 * @notice Handles attestation schema and issuance points for the Merch MVP
 */
contract EASIntegration is Ownable, ReentrancyGuard {
    
    // EAS Schema Definition
    struct AttendanceAttestation {
        bytes32 eventId;        // What event was attended
        uint64 timestamp;       // When the attendance occurred
        bool isPremiumUpgrade;  // Whether this is a premium upgrade attestation
        address attendee;       // Who attended
        uint256 tokenId;       // Associated token ID (SBT or Premium)
    }
    
    // State variables
    mapping(bytes32 => AttendanceAttestation) public attestations;
    mapping(address => bytes32[]) public userAttestations;
    mapping(bytes32 => bytes32[]) public eventAttestations;
    
    // EAS Registry contract (mock for MVP)
    address public easRegistry;
    
    // Events
    event AttestationCreated(
        bytes32 indexed attestationId,
        bytes32 indexed eventId,
        address indexed attendee,
        uint256 tokenId,
        bool isPremiumUpgrade
    );
    event EASRegistrySet(address indexed registry);
    
    // Errors
    error InvalidEventId();
    error InvalidAttendee();
    error AttestationNotFound();
    error InvalidEASRegistry();
    error ArrayLengthMismatch();
    
    constructor(address _easRegistry) Ownable(msg.sender) {
        if (_easRegistry == address(0)) revert InvalidEASRegistry();
        easRegistry = _easRegistry;
    }
    
    /**
     * @dev Create an attendance attestation
     * @param _eventId The event identifier
     * @param _attendee The attendee address
     * @param _tokenId The associated token ID
     * @param _isPremiumUpgrade Whether this is a premium upgrade
     * @return bytes32 The attestation ID
     */
    function createAttendanceAttestation(
        bytes32 _eventId,
        address _attendee,
        uint256 _tokenId,
        bool _isPremiumUpgrade
    ) external onlyOwner nonReentrant returns (bytes32) {
        return _createAttendanceAttestation(_eventId, _attendee, _tokenId, _isPremiumUpgrade);
    }
    
    function _createAttendanceAttestation(
        bytes32 _eventId,
        address _attendee,
        uint256 _tokenId,
        bool _isPremiumUpgrade
    ) internal returns (bytes32) {
        if (_eventId == bytes32(0)) revert InvalidEventId();
        if (_attendee == address(0)) revert InvalidAttendee();
        
        // Generate unique attestation ID
        bytes32 attestationId = keccak256(
            abi.encodePacked(
                _eventId,
                _attendee,
                _tokenId,
                block.timestamp,
                block.number
            )
        );
        
        // Create attestation
        AttendanceAttestation memory attestation = AttendanceAttestation({
            eventId: _eventId,
            timestamp: uint64(block.timestamp),
            isPremiumUpgrade: _isPremiumUpgrade,
            attendee: _attendee,
            tokenId: _tokenId
        });
        
        attestations[attestationId] = attestation;
        userAttestations[_attendee].push(attestationId);
        eventAttestations[_eventId].push(attestationId);
        
        emit AttestationCreated(
            attestationId,
            _eventId,
            _attendee,
            _tokenId,
            _isPremiumUpgrade
        );
        
        return attestationId;
    }
    
    /**
     * @dev Get attestation data by ID
     * @param _attestationId The attestation ID
     * @return AttendanceAttestation The attestation data
     */
    function getAttestation(bytes32 _attestationId) 
        external 
        view 
        returns (AttendanceAttestation memory) 
    {
        if (attestations[_attestationId].attendee == address(0)) {
            revert AttestationNotFound();
        }
        return attestations[_attestationId];
    }
    
    /**
     * @dev Get all attestations for a user
     * @param _user The user address
     * @return bytes32[] Array of attestation IDs
     */
    function getUserAttestations(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return userAttestations[_user];
    }
    
    /**
     * @dev Get all attestations for an event
     * @param _eventId The event ID
     * @return bytes32[] Array of attestation IDs
     */
    function getEventAttestations(bytes32 _eventId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return eventAttestations[_eventId];
    }
    
    /**
     * @dev Get attestation count for a user
     * @param _user The user address
     * @return uint256 The number of attestations
     */
    function getUserAttestationCount(address _user) 
        external 
        view 
        returns (uint256) 
    {
        return userAttestations[_user].length;
    }
    
    /**
     * @dev Get attestation count for an event
     * @param _eventId The event ID
     * @return uint256 The number of attestations
     */
    function getEventAttestationCount(bytes32 _eventId) 
        external 
        view 
        returns (uint256) 
    {
        return eventAttestations[_eventId].length;
    }
    
    /**
     * @dev Check if a user has attended a specific event (gas optimized)
     * @param _user The user address
     * @param _eventId The event ID
     * @return bool True if user has attended the event
     */
    function hasUserAttendedEvent(address _user, bytes32 _eventId) 
        external 
        view 
        returns (bool) 
    {
        bytes32[] memory userAtts = userAttestations[_user];
        uint256 length = userAtts.length;
        
        for (uint256 i = 0; i < length;) {
            if (attestations[userAtts[i]].eventId == _eventId) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }
    
    /**
     * @dev Get premium upgrade attestations for a user (gas optimized)
     * @param _user The user address
     * @return bytes32[] Array of premium upgrade attestation IDs
     */
    function getUserPremiumUpgrades(address _user) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        bytes32[] memory userAtts = userAttestations[_user];
        uint256 length = userAtts.length;
        bytes32[] memory premiumUpgrades = new bytes32[](length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < length;) {
            if (attestations[userAtts[i]].isPremiumUpgrade) {
                premiumUpgrades[count] = userAtts[i];
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }
        
        // Resize array to actual count
        bytes32[] memory result = new bytes32[](count);
        for (uint256 i = 0; i < count;) {
            result[i] = premiumUpgrades[i];
            unchecked { ++i; }
        }
        
        return result;
    }
    
    /**
     * @dev Set the EAS registry address
     * @param _registry The new EAS registry address
     */
    function setEASRegistry(address _registry) external onlyOwner {
        if (_registry == address(0)) revert InvalidEASRegistry();
        easRegistry = _registry;
        emit EASRegistrySet(_registry);
    }
    
    /**
     * @dev Batch create attestations (for efficiency)
     * @param _eventIds Array of event IDs
     * @param _attendees Array of attendee addresses
     * @param _tokenIds Array of token IDs
     * @param _isPremiumUpgrades Array of premium upgrade flags
     * @return bytes32[] Array of created attestation IDs
     */
    function batchCreateAttestations(
        bytes32[] memory _eventIds,
        address[] memory _attendees,
        uint256[] memory _tokenIds,
        bool[] memory _isPremiumUpgrades
    ) external onlyOwner nonReentrant returns (bytes32[] memory) {
        uint256 length = _eventIds.length;
        
        if (length != _attendees.length ||
            length != _tokenIds.length ||
            length != _isPremiumUpgrades.length) {
            revert ArrayLengthMismatch();
        }
        
        bytes32[] memory attestationIds = new bytes32[](length);
        
        for (uint256 i = 0; i < length;) {
            attestationIds[i] = _createAttendanceAttestation(
                _eventIds[i],
                _attendees[i],
                _tokenIds[i],
                _isPremiumUpgrades[i]
            );
            unchecked { ++i; }
        }
        
        return attestationIds;
    }
}