// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./BasicMerch.sol";

/**
 * @title PremiumMerch
 * @dev ERC-721 implementation for premium tradable collectibles with upgrade logic
 * @notice This contract handles the paid tier with monetization and upgrade functionality
 */
contract PremiumMerch is ERC721, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    // State variables
    uint256 private _tokenIdCounter = 1; // Start from 1 for consistency
    string private _baseTokenURI;
    
    // Token URI storage
    mapping(uint256 => string) private _tokenURIs;
    
    // Contract references
    BasicMerch public basicMerchContract;
    
    // Fee configuration
    uint256 public upgradeFee;
    address public treasury;
    uint256 public treasurySplit; // Basis points (e.g., 3750 = 37.5%)
    uint256 public organizerSplit; // Basis points (e.g., 6250 = 62.5%)
    uint256 public constant BASIS_POINTS = 10000;
    
    // Companion tracking
    mapping(uint256 => uint256) public sbtToPremiumMapping; // sbtId => premiumId
    mapping(uint256 => bool) public upgradedSBTs; // Track which SBTs have been used for companion minting
    
    // Events
    event CompanionMinted(address indexed user, uint256 indexed sbtId, uint256 indexed premiumId, uint256 fee);
    event FeeDistributed(address indexed organizer, uint256 treasuryAmount, uint256 organizerAmount);
    event UpgradeFeeSet(uint256 newFee);
    event TreasurySet(address indexed newTreasury);
    event FeeSplitSet(uint256 treasurySplit, uint256 organizerSplit);
    event BaseURISet(string newBaseURI);
    event TokenURISet(uint256 indexed tokenId, string tokenURI);
    event ExcessRefunded(address indexed user, uint256 amount);

    // Errors
    error InsufficientFee();
    error SBTNotOwned();
    error SBTAlreadyUpgraded();
    error InvalidFeeSplit();
    error InvalidAddress();
    error SBTDoesNotExist();
    error TransferFailed();
    error NoFundsToWithdraw();

    constructor(
        string memory name,
        string memory symbol,
        address _basicMerchContract,
        address _treasury,
        uint256 _upgradeFee
    ) ERC721(name, symbol) Ownable(msg.sender) {
        if (_basicMerchContract == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        
        basicMerchContract = BasicMerch(_basicMerchContract);
        treasury = _treasury;
        upgradeFee = _upgradeFee;
        
        // Default fee split: 37.5% treasury, 62.5% organizer
        treasurySplit = 3750;
        organizerSplit = 6250;
    }

    /**
     * @dev Mint a Premium ERC-721 NFT companion for an existing SBT
     * @param _sbtId The ID of the SBT to create a companion for
     * @param _organizer The organizer address to receive the fee split
     * @param _upgrader The address performing the mint (token owner)
     * @notice Core monetization function - requires fee payment, SBT is retained
     */
    function mintCompanion(uint256 _sbtId, address _organizer, address _upgrader) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        // Validate inputs
        if (_organizer == address(0)) revert InvalidAddress();
        if (msg.value < upgradeFee) revert InsufficientFee();
        if (upgradedSBTs[_sbtId]) revert SBTAlreadyUpgraded();
        
        // Check if SBT exists and is owned by upgrader
        if (!basicMerchContract.isApprovedOrOwner(_upgrader, _sbtId)) {
            revert SBTNotOwned();
        }
        
        // Handle excess payment refund
        if (msg.value > upgradeFee) {
            uint256 refund = msg.value - upgradeFee;
            (bool refundSuccess, ) = _upgrader.call{value: refund}("");
            if (!refundSuccess) revert TransferFailed();
            emit ExcessRefunded(_upgrader, refund);
        }
        
        // Execute companion minting logic
        _executeMint(_sbtId, _organizer, _upgrader);
    }

    /**
     * @dev Internal function to execute the companion minting process
     * @param _sbtId The SBT ID being used for companion minting
     * @param _organizer The organizer address
     * @param _upgrader The address performing the mint
     */
    function _executeMint(uint256 _sbtId, address _organizer, address _upgrader) internal {
        // 1. Mark SBT as used for companion minting (protection against reentrancy)
        upgradedSBTs[_sbtId] = true;
        
        // 2. Mint new Premium NFT to the upgrader
        uint256 premiumId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(_upgrader, premiumId);
        
        // 3. Store mapping
        sbtToPremiumMapping[_sbtId] = premiumId;
        
        // 4. Distribute fees (interactions last)
        _distributeFees(_organizer);
        
        // 5. Emit events
        emit CompanionMinted(_upgrader, _sbtId, premiumId, upgradeFee);
    }

    /**
     * @dev Distribute fees between treasury and organizer
     * @param _organizer The organizer address
     */
    function _distributeFees(address _organizer) internal {
        uint256 totalFee = upgradeFee;
        uint256 treasuryAmount = (totalFee * treasurySplit) / BASIS_POINTS;
        uint256 organizerAmount = totalFee - treasuryAmount;
        
        // Send to treasury
        if (treasuryAmount > 0 && treasury != address(0)) {
            (bool treasurySuccess, ) = treasury.call{value: treasuryAmount}("");
            if (!treasurySuccess) revert TransferFailed();
        }
        
        // Send to organizer
        if (organizerAmount > 0) {
            (bool organizerSuccess, ) = _organizer.call{value: organizerAmount}("");
            if (!organizerSuccess) revert TransferFailed();
        }
        
        emit FeeDistributed(_organizer, treasuryAmount, organizerAmount);
    }

    /**
     * @dev Set the base URI for token metadata
     * @param _uri The new base URI
     */
    function setBaseURI(string memory _uri) external onlyOwner {
        _baseTokenURI = _uri;
        emit BaseURISet(_uri);
    }

    /**
     * @dev Get the base URI for token metadata
     * @return string The base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Set token URI for a specific token (owner only)
     * @param _tokenId The token ID
     * @param _tokenURI The token URI
     */
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyOwner {
        if (_ownerOf(_tokenId) == address(0)) revert SBTDoesNotExist();
        _tokenURIs[_tokenId] = _tokenURI;
        emit TokenURISet(_tokenId, _tokenURI);
    }

    /**
     * @dev Override tokenURI to return individual token URIs
     * @param tokenId The token ID
     * @return string The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert SBTDoesNotExist();
        
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
     * @dev Set the upgrade fee
     * @param _newFee The new upgrade fee in wei
     */
    function setUpgradeFee(uint256 _newFee) external onlyOwner {
        upgradeFee = _newFee;
        emit UpgradeFeeSet(_newFee);
    }

    /**
     * @dev Set the treasury address
     * @param _newTreasury The new treasury address
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert InvalidAddress();
        treasury = _newTreasury;
        emit TreasurySet(_newTreasury);
    }

    /**
     * @dev Set the fee split percentages
     * @param _treasurySplit Treasury split in basis points
     * @param _organizerSplit Organizer split in basis points
     */
    function setFeeSplit(uint256 _treasurySplit, uint256 _organizerSplit) external onlyOwner {
        if (_treasurySplit + _organizerSplit != BASIS_POINTS) revert InvalidFeeSplit();
        if (_treasurySplit == 0 || _organizerSplit == 0) revert InvalidFeeSplit();
        
        treasurySplit = _treasurySplit;
        organizerSplit = _organizerSplit;
        
        emit FeeSplitSet(_treasurySplit, _organizerSplit);
    }

    /**
     * @dev Set the basic merch contract address
     * @param _basicMerchContract The new basic merch contract address
     */
    function setBasicMerchContract(address _basicMerchContract) external onlyOwner {
        if (_basicMerchContract == address(0)) revert InvalidAddress();
        basicMerchContract = BasicMerch(_basicMerchContract);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get the current token counter
     * @return uint256 The current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Check if an SBT has been used for companion minting
     * @param _sbtId The SBT ID to check
     * @return bool True if SBT has been used for companion minting
     */
    function isSBTUsedForCompanion(uint256 _sbtId) external view returns (bool) {
        return upgradedSBTs[_sbtId];
    }

    /**
     * @dev Get the premium token ID for an upgraded SBT
     * @param _sbtId The SBT ID
     * @return uint256 The premium token ID
     */
    function getPremiumTokenId(uint256 _sbtId) external view returns (uint256) {
        return sbtToPremiumMapping[_sbtId];
    }

    /**
     * @dev Check if user can mint companion for specific SBT
     * @param _sbtId The SBT ID to check
     * @param _user The user address
     * @return bool True if can mint companion
     * @return string Reason message
     */
    function canMintCompanion(uint256 _sbtId, address _user) 
        external 
        view 
        returns (bool, string memory) 
    {
        if (upgradedSBTs[_sbtId]) {
            return (false, "Already used for companion");
        }
        if (!basicMerchContract.isApprovedOrOwner(_user, _sbtId)) {
            return (false, "Not owner");
        }
        if (paused()) {
            return (false, "Contract paused");
        }
        return (true, "Can mint companion");
    }

    /**
     * @dev Emergency withdraw function for owner
     * @notice Only use in emergency situations
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();
        
        (bool success, ) = owner().call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @dev Get contract balance
     * @return uint256 The contract's ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}