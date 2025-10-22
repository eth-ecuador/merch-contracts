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
 * @notice ✅ PUBLIC MINTING with signature verification from backend issuer
 */
contract BasicMerch is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // State variables
    uint256 private _tokenIdCounter = 1;
    string private _baseTokenURI;
    
    // Token URI storage
    mapping(uint256 => string) private _tokenURIs;
    
    // Signature-based access control
    address public backendIssuer;
    
    // Event tracking
    mapping(address => mapping(uint256 => uint256)) public userEventToTokenId;
    mapping(uint256 => uint256) public tokenIdToEventId;
    
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
    error BackendIssuerNotSet();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @dev Verify signature from backend issuer using EIP-191 standard
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
        return signer == backendIssuer && signer != address(0);
    }

    /**
     * @dev ✅ PUBLIC MINT - Anyone can call with valid signature from backend
     * @notice Users pay their own gas, backend only provides signature (off-chain, free)
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
        if (backendIssuer == address(0)) revert BackendIssuerNotSet();
        
        if (userEventToTokenId[_to][_eventId] != 0) {
            revert DuplicateEventMint();
        }
        
        // ✅ CRITICAL: Verify signature
        if (!_verifySignature(_to, _eventId, _tokenURI, _signature)) {
            revert InvalidSignature();
        }

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        
        userEventToTokenId[_to][_eventId] = tokenId;
        tokenIdToEventId[tokenId] = _eventId;

        emit SBTMinted(_to, tokenId, _eventId, _tokenURI);
        return tokenId;
    }

    function getSBTByEvent(address _owner, uint256 _eventId) external view returns (uint256) {
        return userEventToTokenId[_owner][_eventId];
    }

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

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        
        if (from == address(0)) {
            return super._update(to, tokenId, auth);
        }
        
        revert TransferNotAllowed();
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURISet(baseURI);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        _tokenURIs[tokenId] = _tokenURI;
        emit TokenURISet(tokenId, _tokenURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    /**
     * @dev ✅ Set backend issuer address - MUST match backend wallet
     */
    function setBackendIssuer(address _issuer) external onlyOwner {
        if (_issuer == address(0)) revert InvalidAddress();
        backendIssuer = _issuer;
        emit BackendIssuerSet(_issuer);
    }

    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function getEventIdByToken(uint256 _tokenId) external view returns (uint256) {
        return tokenIdToEventId[_tokenId];
    }
}
