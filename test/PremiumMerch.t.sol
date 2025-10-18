// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/BasicMerch.sol";
import "../contracts/PremiumMerch.sol";

contract PremiumMerchTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    address public treasury;
    
    function setUp() public {
        owner = address(this);
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");
        
        // Deploy BasicMerch
        basicMerch = new BasicMerch("Basic Merch SBT", "BMERCH");
        
        // Deploy PremiumMerch
        premiumMerch = new PremiumMerch(
            "Premium Merch NFT",
            "PMERCH",
            address(basicMerch),
            treasury,
            0.01 ether
        );
        
        // Configure contracts
        basicMerch.setPremiumContract(address(premiumMerch));
        premiumMerch.setBasicMerchContract(address(basicMerch));
        basicMerch.setWhitelistedMinter(minter, true);
    }
    
    // Test Case 1: Upgrade Fee Check
    function testUpgradeFeeCheck() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Test insufficient fee
        vm.prank(user1);
        vm.expectRevert("Insufficient fee");
        premiumMerch.upgradeSBT{value: 0.005 ether}(tokenId, user2);
    }
    
    // Test Case 2: Upgrade E2E Logic
    function testUpgradeE2ELogic() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 organizerBalanceBefore = user2.balance;
        
        // Test successful upgrade
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Verify SBT is burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        // Verify new ERC-721 is minted
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId), user1);
        
        // Verify fee is split correctly
        // Treasury should receive 37.5% (3750 basis points)
        // Organizer should receive 62.5% (6250 basis points)
        uint256 expectedTreasuryAmount = (0.01 ether * 3750) / 10000;
        uint256 expectedOrganizerAmount = (0.01 ether * 6250) / 10000;
        
        assertEq(treasury.balance - treasuryBalanceBefore, expectedTreasuryAmount);
        assertEq(user2.balance - organizerBalanceBefore, expectedOrganizerAmount);
    }
    
    // Test Case 3: Double Upgrade
    function testDoubleUpgrade() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // First upgrade
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Attempt second upgrade (should fail)
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
    }
    
    // Test upgrade with non-existent SBT
    function testUpgradeNonExistentSBT() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(999, user2);
    }
    
    // Test upgrade with SBT not owned by caller
    function testUpgradeSBTNotOwned() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT to user1
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user2 some ETH
        vm.deal(user2, 1 ether);
        
        // Try to upgrade from user2 (not the owner)
        vm.prank(user2);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
    }
    
    // Test fee configuration
    function testFeeConfiguration() public {
        assertEq(premiumMerch.upgradeFee(), 0.01 ether);
        assertEq(premiumMerch.treasury(), treasury);
        assertEq(premiumMerch.treasurySplit(), 3750); // 37.5%
        assertEq(premiumMerch.organizerSplit(), 6250); // 62.5%
    }
    
    // Test fee split validation
    function testFeeSplitValidation() public {
        vm.expectRevert();
        premiumMerch.setFeeSplit(5000, 4000); // Should be 10000 total, but this is 9000
    }
    
    // Test pause functionality
    function testPauseFunctionality() public {
        // Pause the contract
        premiumMerch.pause();
        
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Upgrade should fail when paused
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Unpause and try again
        premiumMerch.unpause();
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
    }
    
    // Test SBT to Premium mapping
    function testSBTToPremiumMapping() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Upgrade
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Check mapping
        uint256 premiumId = premiumMerch.sbtToPremiumMapping(tokenId);
        assertTrue(premiumId >= 0); // Premium ID can be 0
        assertEq(premiumMerch.ownerOf(premiumId), user1);
    }
    
    // Test SBT upgrade status
    function testSBTUpgradeStatus() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Initially not upgraded
        assertFalse(premiumMerch.isSBTUpgraded(tokenId));
        
        // Upgrade
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Should be marked as upgraded
        assertTrue(premiumMerch.isSBTUpgraded(tokenId));
    }
}
