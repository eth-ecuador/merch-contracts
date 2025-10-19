// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./BasicMerch.sol";

/**
 * @title PremiumMerch
 * @dev ERC-721 implementation for premium tradable collectibles with upgrade logic
 * @notice This contract handles the paid tier with monetization and upgrade functionality
 */
contract PremiumMerch is ERC721, Ownable, ReentrancyGuard, Pausable {
    // State variables
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    
    // Contract references
    BasicMerch public basicMerchContract;
    
    // Fee configuration
    uint256 public upgradeFee;
    address public treasury;
    uint256 public treasurySplit; // Basis points (e.g., 3750 = 37.5%)
    uint256 public organizerSplit; // Basis points (e.g., 6250 = 62.5%)
    uint256 public constant BASIS_POINTS = 10000;
    
    // Upgrade tracking
    mapping(uint256 => uint256) public sbtToPremiumMapping; // sbtId => premiumId
    mapping(uint256 => bool) public upgradedSBTs; // Track which SBTs have been upgraded
    
    // Events
    event SBTUpgraded(address indexed user, uint256 indexed sbtId, uint256 indexed premiumId, uint256 fee);
    event FeeDistributed(address indexed organizer, uint256 treasuryAmount, uint256 organizerAmount);
    event UpgradeFeeSet(uint256 newFee);
    event TreasurySet(address indexed newTreasury);
    event FeeSplitSet(uint256 treasurySplit, uint256 organizerSplit);
    event BaseURISet(string newBaseURI);

    // Errors
    error InsufficientFee();
    error SBTNotOwned();
    error SBTAlreadyUpgraded();
    error InvalidFeeSplit();
    error InvalidAddress();
    error SBTDoesNotExist();

    constructor(
        string memory name,
        string memory symbol,
        address _basicMerchContract,
        address _treasury,
        uint256 _upgradeFee
    ) ERC721(name, symbol) Ownable(msg.sender) {
        basicMerchContract = BasicMerch(_basicMerchContract);
        treasury = _treasury;
        upgradeFee = _upgradeFee;
        
        // Default fee split: 37.5% treasury, 62.5% organizer
        treasurySplit = 3750;
        organizerSplit = 6250;
    }

    /**
     * @dev Upgrade an SBT to a Premium ERC-721 NFT
     * @param _sbtId The ID of the SBT to upgrade
     * @param _organizer The organizer address to receive the fee split
     * @notice Core monetization function - requires fee payment
     */
    function upgradeSBT(uint256 _sbtId, address _organizer) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        // Validate inputs
        require(_organizer != address(0), "Invalid organizer address");
        require(msg.value >= upgradeFee, "Insufficient fee");
        
        // Check if SBT exists and is owned by caller
        if (!basicMerchContract.isApprovedOrOwner(msg.sender, _sbtId)) {
            revert SBTNotOwned();
        }
        
        // Check if SBT has already been upgraded
        if (upgradedSBTs[_sbtId]) {
            revert SBTAlreadyUpgraded();
        }
        
        // Check if SBT exists
        try basicMerchContract.ownerOf(_sbtId) returns (address owner) {
            if (owner == address(0)) {
                revert SBTDoesNotExist();
            }
        } catch {
            revert SBTDoesNotExist();
        }
        
        // Execute upgrade logic
        _executeUpgrade(_sbtId, _organizer);
    }

    /**
     * @dev Internal function to execute the upgrade process
     * @param _sbtId The SBT ID being upgraded
     * @param _organizer The organizer address
     */
    function _executeUpgrade(uint256 _sbtId, address _organizer) internal {
        // 1. Burn the SBT
        basicMerchContract.burnSBT(_sbtId);
        
        // 2. Mark SBT as upgraded
        upgradedSBTs[_sbtId] = true;
        
        // 3. Mint new Premium NFT
        uint256 premiumId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(msg.sender, premiumId);
        
        // 4. Store mapping
        sbtToPremiumMapping[_sbtId] = premiumId;
        
        // 5. Distribute fees
        _distributeFees(_organizer);
        
        // 6. Emit events
        emit SBTUpgraded(msg.sender, _sbtId, premiumId, msg.value);
    }

    /**
     * @dev Distribute fees between treasury and organizer
     * @param _organizer The organizer address
     */
    function _distributeFees(address _organizer) internal {
        uint256 totalFee = msg.value;
        uint256 treasuryAmount = (totalFee * treasurySplit) / BASIS_POINTS;
        uint256 organizerAmount = totalFee - treasuryAmount;
        
        // Send to treasury
        if (treasuryAmount > 0 && treasury != address(0)) {
            (bool treasurySuccess, ) = treasury.call{value: treasuryAmount}("");
            require(treasurySuccess, "Treasury transfer failed");
        }
        
        // Send to organizer
        if (organizerAmount > 0) {
            (bool organizerSuccess, ) = _organizer.call{value: organizerAmount}("");
            require(organizerSuccess, "Organizer transfer failed");
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
        require(_newTreasury != address(0), "Invalid treasury address");
        treasury = _newTreasury;
        emit TreasurySet(_newTreasury);
    }

    /**
     * @dev Set the fee split percentages
     * @param _treasurySplit Treasury split in basis points
     * @param _organizerSplit Organizer split in basis points
     */
    function setFeeSplit(uint256 _treasurySplit, uint256 _organizerSplit) external onlyOwner {
        require(_treasurySplit + _organizerSplit == BASIS_POINTS, "Invalid fee split");
        require(_treasurySplit > 0 && _organizerSplit > 0, "Splits must be positive");
        
        treasurySplit = _treasurySplit;
        organizerSplit = _organizerSplit;
        
        emit FeeSplitSet(_treasurySplit, _organizerSplit);
    }

    /**
     * @dev Set the basic merch contract address
     * @param _basicMerchContract The new basic merch contract address
     */
    function setBasicMerchContract(address _basicMerchContract) external onlyOwner {
        require(_basicMerchContract != address(0), "Invalid contract address");
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
     * @dev Check if an SBT has been upgraded
     * @param _sbtId The SBT ID to check
     * @return bool True if SBT has been upgraded
     */
    function isSBTUpgraded(uint256 _sbtId) external view returns (bool) {
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
     * @dev Emergency withdraw function for owner
     * @notice Only use in emergency situations
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Get contract balance
     * @return uint256 The contract's ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
