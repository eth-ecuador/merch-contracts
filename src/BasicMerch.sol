// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BasicMerch
 * @dev ERC-4973 Soul Bound Token (SBT) implementation for free tier attendance proof
 * @notice This contract handles non-transferable proof of attendance tokens
 */
contract BasicMerch is ERC721, Ownable, ReentrancyGuard {
    // State variables
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    
    // Access control
    mapping(address => bool) public whitelistedMinters;
    address public premiumMerchContract;
    
    // Events
    event SBTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event SBTBurned(uint256 indexed tokenId);
    event MinterWhitelisted(address indexed minter, bool status);
    event PremiumContractSet(address indexed premiumContract);

    // Errors
    error NotWhitelistedMinter();
    error NotPremiumContract();
    error TokenDoesNotExist();
    error TransferNotAllowed();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @dev Modifier to check if caller is whitelisted minter
     */
    modifier onlyWhitelistedMinter() {
        if (!whitelistedMinters[msg.sender]) {
            revert NotWhitelistedMinter();
        }
        _;
    }

    /**
     * @dev Modifier to check if caller is premium merch contract
     */
    modifier onlyPremiumContract() {
        if (msg.sender != premiumMerchContract) {
            revert NotPremiumContract();
        }
        _;
    }

    /**
     * @dev Mint a new SBT to the specified address
     * @param _to The address to mint the SBT to
     * @param _tokenURI The metadata URI for the token
     * @notice Only callable by whitelisted minters (e.g., Backend API/Minter Role)
     */
    function mintSBT(address _to, string memory _tokenURI) 
        external 
        onlyWhitelistedMinter 
        nonReentrant 
        returns (uint256) 
    {
        require(_to != address(0), "Cannot mint to zero address");
        require(bytes(_tokenURI).length > 0, "Token URI cannot be empty");

        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        emit SBTMinted(_to, tokenId, _tokenURI);
        return tokenId;
    }

    /**
     * @dev Burn an SBT during the upgrade process
     * @param _tokenId The ID of the token to burn
     * @notice Only callable by the PremiumMerch contract
     */
    function burnSBT(uint256 _tokenId) external onlyPremiumContract {
        if (!_exists(_tokenId)) {
            revert TokenDoesNotExist();
        }

        address owner = ownerOf(_tokenId);
        _burn(_tokenId);
        
        emit SBTBurned(_tokenId);
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
        
        // Allow burning (to == address(0)) - only by premium contract
        if (to == address(0) && msg.sender == premiumMerchContract) {
            return super._update(to, tokenId, auth);
        }
        
        // Revert all other transfers
        revert TransferNotAllowed();
    }

    /**
     * @dev Set the base URI for token metadata
     * @param baseURI The new base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
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
        require(_exists(tokenId), "URI set of nonexistent token");
        // Note: In a full implementation, you might want to store this in a mapping
        // For this MVP, we'll use the base URI + token ID pattern
    }

    /**
     * @dev Add or remove a whitelisted minter
     * @param _minter The address to whitelist/unwhitelist
     * @param _status True to whitelist, false to remove
     */
    function setWhitelistedMinter(address _minter, bool _status) external onlyOwner {
        whitelistedMinters[_minter] = _status;
        emit MinterWhitelisted(_minter, _status);
    }

    /**
     * @dev Set the premium merch contract address
     * @param _premiumContract The address of the premium merch contract
     */
    function setPremiumContract(address _premiumContract) external onlyOwner {
        premiumMerchContract = _premiumContract;
        emit PremiumContractSet(_premiumContract);
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
}
