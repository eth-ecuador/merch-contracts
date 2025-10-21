// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BasicMerch
 * @dev ERC-4973 Soul Bound Token (SBT) implementation for free tier attendance proof
 * @notice This contract handles non-transferable proof of attendance tokens
 * @notice Implements ERC-4973-like behavior by preventing transfers after minting
 */
contract BasicMerch is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // State variables
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    
    // Token URI storage
    mapping(uint256 => string) private _tokenURIs;
    
    // Signature-based access control
    address public backendIssuer;
    
    // Event tracking
    mapping(address => mapping(uint256 => uint256)) public userEventToTokenId; // user => eventId => tokenId
    mapping(uint256 => uint256) public tokenIdToEventId; // tokenId => eventId
    
    // Events
    event SBTMinted(address indexed to, uint256 indexed tokenId, uint256 indexed eventId, string tokenURI);
    event BackendIssuerSet(address indexed issuer);
    event BaseURISet(string newBaseURI);
    event TokenURISet(uint256 indexed tokenId, string tokenURI);

    // Errors
    error InvalidSignature();
    error InvalidAddress();
    error EmptyTokenURI();
    error TokenDoesNotExist();
    error TransferNotAllowed();
    error DuplicateEventMint();
    error InvalidEventId();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @dev Verify signature from backend issuer
     */
    function _verifySignature(
        address _to,
        uint256 _eventId,
        string memory _tokenURI,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(_to, _eventId, _tokenURI));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        if (_signature.length != 65) return false;
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        
        if (v < 27) {
            v += 27;
        }
        
        address signer = ecrecover(ethSignedMessageHash, v, r, s);
        return signer == backendIssuer;
    }

    /**
     * @dev Mint a new SBT to the specified address with signature verification
     * @param _to The address to mint the SBT to
     * @param _eventId The event ID for this attendance
     * @param _tokenURI The metadata URI for the token
     * @param _signature The signature from the backend issuer
     * @notice Public function that requires valid signature from backend issuer
     */
    function mintSBT(
        address _to, 
        uint256 _eventId, 
        string memory _tokenURI, 
        bytes memory _signature
    ) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        if (_to == address(0)) revert InvalidAddress();
        if (_eventId == 0) revert InvalidEventId();
        if (bytes(_tokenURI).length == 0) revert EmptyTokenURI();
        if (backendIssuer == address(0)) revert InvalidAddress();
        
        // Check for duplicate event minting
        if (userEventToTokenId[_to][_eventId] != 0) {
            revert DuplicateEventMint();
        }
        
        // Verify signature
        if (!_verifySignature(_to, _eventId, _tokenURI, _signature)) {
            revert InvalidSignature();
        }

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        // Store event tracking
        userEventToTokenId[_to][_eventId] = tokenId;
        tokenIdToEventId[tokenId] = _eventId;

        emit SBTMinted(_to, tokenId, _eventId, _tokenURI);
        return tokenId;
    }

    /**
     * @dev Get SBT token ID for a specific user and event
     * @param _owner The owner address
     * @param _eventId The event ID
     * @return uint256 The token ID (0 if not found)
     */
    function getSBTByEvent(address _owner, uint256 _eventId) external view returns (uint256) {
        return userEventToTokenId[_owner][_eventId];
    }

    /**
     * @dev Check if the spender is approved or owner of the token
     * @param _spender The address to check
     * @param _tokenId The token ID to check
     * @return bool True if spender is approved or owner
     * @notice Required for ERC-721 contract to perform burn on user's behalf
     */
    function isApprovedOrOwner(address _spender, uint256 _tokenId) 
        public 
        view 
        returns (bool) 
    {
        if (!_exists(_tokenId)) {
            return false;
        }
        
        address owner = ownerOf(_tokenId);
        return (_spender == owner || 
                isApprovedForAll(owner, _spender) || 
                getApproved(_tokenId) == _spender);
    }

    /**
     * @dev Override transfer functions to prevent transfers (SBT behavior)
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Allow minting (from == address(0))
        if (from == address(0)) {
            return super._update(to, tokenId, auth);
        }
        
        // Revert all transfers (SBTs are permanent)
        revert TransferNotAllowed();
    }

    /**
     * @dev Set the base URI for token metadata
     * @param baseURI The new base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURISet(baseURI);
    }

    /**
     * @dev Get the base URI for token metadata
     * @return string The base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Set token URI for a specific token
     * @param tokenId The token ID
     * @param _tokenURI The token URI
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        _tokenURIs[tokenId] = _tokenURI;
        emit TokenURISet(tokenId, _tokenURI);
    }

    /**
     * @dev Override tokenURI to return individual token URIs
     * @param tokenId The token ID
     * @return string The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        
        // If there is no base URI, return the token URI
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        
        // If both are set, return the specific token URI
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        
        // If only base URI is set, concatenate with token ID
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
     * @dev Set the backend issuer address for signature verification
     * @param _issuer The address of the backend issuer
     */
    function setBackendIssuer(address _issuer) external onlyOwner {
        if (_issuer == address(0)) revert InvalidAddress();
        backendIssuer = _issuer;
        emit BackendIssuerSet(_issuer);
    }

    /**
     * @dev Get the current token counter
     * @return uint256 The current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Check if a token exists
     * @param tokenId The token ID to check
     * @return bool True if token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Get the event ID for a specific token
     * @param _tokenId The token ID
     * @return uint256 The event ID
     */
    function getEventIdByToken(uint256 _tokenId) external view returns (uint256) {
        return tokenIdToEventId[_tokenId];
    }
}