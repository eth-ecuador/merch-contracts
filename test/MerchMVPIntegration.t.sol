// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";
import "../src/EASIntegration.sol";
import "../src/MerchManager.sol";

/**
 * @title MerchMVPIntegration
 * @notice Complete end-to-end integration tests for the Merch MVP system
 */
contract MerchMVPIntegrationTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    EASIntegration public easIntegration;
    MerchManager public merchManager;
    
    address public owner;
    address public treasury;
    address public organizer;
    address public user1;
    address public user2;
    address public user3;
    
    bytes32 public event1Id;
    bytes32 public event2Id;
    
    string constant EVENT1_METADATA = "Web3 Conference 2025";
    string constant EVENT2_METADATA = "NFT NYC 2025";
    
    function setUp() public {
        owner = address(this);
        treasury = makeAddr("treasury");
        organizer = makeAddr("organizer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Deploy all contracts
        basicMerch = new BasicMerch("Basic Merch SBT", "BMSBT");
        premiumMerch = new PremiumMerch(
            "Premium Merch NFT",
            "PMNFT",
            address(basicMerch),
            treasury,
            0.001 ether
        );
        easIntegration = new EASIntegration(owner);
        merchManager = new MerchManager(
            address(basicMerch),
            address(premiumMerch),
            address(easIntegration)
        );
        
        // Configure contracts
        basicMerch.setPremiumContract(address(premiumMerch));
        basicMerch.setWhitelistedMinter(address(merchManager), true);
        
        // Transfer ownership of EASIntegration to MerchManager BEFORE other operations
        easIntegration.transferOwnership(address(merchManager));
        
        // Register events
        event1Id = keccak256(bytes(EVENT1_METADATA));
        event2Id = keccak256(bytes(EVENT2_METADATA));
        
        merchManager.registerEvent(event1Id, EVENT1_METADATA);
        merchManager.registerEvent(event2Id, EVENT2_METADATA);
        
        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }
    
    function testCompleteUserJourney() public {
        // Step 1: User attends event and receives free SBT
        (uint256 tokenId1, bytes32 attestationId1) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmUser1Event1",
            event1Id
        );
        
        assertEq(basicMerch.ownerOf(tokenId1), user1);
        assertTrue(merchManager.hasUserAttendedEvent(user1, event1Id));
        
        bytes32[] memory userHistory = merchManager.getUserAttendanceHistory(user1);
        assertEq(userHistory.length, 1);
        assertEq(userHistory[0], attestationId1);
        
        // Step 2: User upgrades to Premium NFT
        uint256 user1BalanceBefore = user1.balance;
        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 organizerBalanceBefore = organizer.balance;
        
        vm.prank(user1);
        (uint256 premiumId1, bytes32 attestationId2) = merchManager.upgradeSBTWithAttestation{
            value: 0.001 ether
        }(tokenId1, organizer, event1Id);
        
        // Verify SBT burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId1);
        
        // Verify Premium minted
        assertEq(premiumMerch.ownerOf(premiumId1), user1);
        
        // Verify fees distributed correctly
        assertEq(user1.balance, user1BalanceBefore - 0.001 ether);
        assertTrue(treasury.balance > treasuryBalanceBefore);
        assertTrue(organizer.balance > organizerBalanceBefore);
        
        // Verify attestations
        userHistory = merchManager.getUserAttendanceHistory(user1);
        assertEq(userHistory.length, 2); // Basic + Upgrade
        
        bytes32[] memory premiumUpgrades = merchManager.getUserPremiumUpgrades(user1);
        assertEq(premiumUpgrades.length, 1);
        assertEq(premiumUpgrades[0], attestationId2);
        
        // Step 3: Verify Premium NFT is tradable
        vm.prank(user1);
        premiumMerch.transferFrom(user1, user2, premiumId1);
        assertEq(premiumMerch.ownerOf(premiumId1), user2);
    }
    
    function testMultipleUsersMultipleEvents() public {
        // User1 attends both events
        merchManager.mintSBTWithAttestation(user1, "ipfs://QmUser1Event1", event1Id);
        merchManager.mintSBTWithAttestation(user1, "ipfs://QmUser1Event2", event2Id);
        
        // User2 attends event1
        merchManager.mintSBTWithAttestation(user2, "ipfs://QmUser2Event1", event1Id);
        
        // User3 attends event2
        merchManager.mintSBTWithAttestation(user3, "ipfs://QmUser3Event2", event2Id);
        
        // Verify attendance
        assertTrue(merchManager.hasUserAttendedEvent(user1, event1Id));
        assertTrue(merchManager.hasUserAttendedEvent(user1, event2Id));
        assertTrue(merchManager.hasUserAttendedEvent(user2, event1Id));
        assertFalse(merchManager.hasUserAttendedEvent(user2, event2Id));
        assertTrue(merchManager.hasUserAttendedEvent(user3, event2Id));
        assertFalse(merchManager.hasUserAttendedEvent(user3, event1Id));
        
        // Verify event attendance counts
        bytes32[] memory event1Attendees = merchManager.getEventAttendance(event1Id);
        bytes32[] memory event2Attendees = merchManager.getEventAttendance(event2Id);
        
        assertEq(event1Attendees.length, 2); // user1, user2
        assertEq(event2Attendees.length, 2); // user1, user3
    }
    
    function testBatchEventRegistration() public {
        bytes32[] memory eventIds = new bytes32[](3);
        string[] memory metadatas = new string[](3);
        
        eventIds[0] = keccak256("Event A");
        eventIds[1] = keccak256("Event B");
        eventIds[2] = keccak256("Event C");
        
        metadatas[0] = "Event A Metadata";
        metadatas[1] = "Event B Metadata";
        metadatas[2] = "Event C Metadata";
        
        merchManager.batchRegisterEvents(eventIds, metadatas);
        
        assertTrue(merchManager.isEventRegistered(eventIds[0]));
        assertTrue(merchManager.isEventRegistered(eventIds[1]));
        assertTrue(merchManager.isEventRegistered(eventIds[2]));
        
        assertEq(merchManager.getEventMetadata(eventIds[0]), metadatas[0]);
        assertEq(merchManager.getEventMetadata(eventIds[1]), metadatas[1]);
        assertEq(merchManager.getEventMetadata(eventIds[2]), metadatas[2]);
    }
    
    function testUpgradeWithExcessPayment() public {
        // Mint SBT
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        uint256 user1BalanceBefore = user1.balance;
        uint256 excessAmount = 0.005 ether;
        uint256 totalSent = 0.001 ether + excessAmount;
        
        // Upgrade with excess payment
        vm.prank(user1);
        merchManager.upgradeSBTWithAttestation{value: totalSent}(
            tokenId,
            organizer,
            event1Id
        );
        
        // Verify user received refund
        assertEq(user1.balance, user1BalanceBefore - 0.001 ether);
    }
    
    function testCannotMintForUnregisteredEvent() public {
        bytes32 unregisteredEventId = keccak256("Unregistered Event");
        
        vm.expectRevert();
        merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            unregisteredEventId
        );
    }
    
    function testCannotUpgradeForUnregisteredEvent() public {
        // Mint SBT for registered event
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        bytes32 unregisteredEventId = keccak256("Unregistered Event");
        
        vm.prank(user1);
        vm.expectRevert();
        merchManager.upgradeSBTWithAttestation{value: 0.001 ether}(
            tokenId,
            organizer,
            unregisteredEventId
        );
    }
    
    function testAccessControl() public {
        // Only owner can register events
        vm.prank(user1);
        vm.expectRevert();
        merchManager.registerEvent(keccak256("New Event"), "New Event");
        
        // Only owner can mint SBTs
        vm.prank(user1);
        vm.expectRevert();
        merchManager.mintSBTWithAttestation(user2, "ipfs://test", event1Id);
        
        // Only whitelisted can mint directly in BasicMerch
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotWhitelistedMinter.selector);
        basicMerch.mintSBT(user2, "ipfs://test");
    }
    
    function testPremiumNFTTradeability() public {
        // Mint and upgrade
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        vm.prank(user1);
        (uint256 premiumId,) = merchManager.upgradeSBTWithAttestation{
            value: 0.001 ether
        }(tokenId, organizer, event1Id);
        
        // Premium NFT should be tradable
        vm.prank(user1);
        premiumMerch.transferFrom(user1, user2, premiumId);
        assertEq(premiumMerch.ownerOf(premiumId), user2);
        
        vm.prank(user2);
        premiumMerch.transferFrom(user2, user3, premiumId);
        assertEq(premiumMerch.ownerOf(premiumId), user3);
    }
    
    function testSBTNonTransferability() public {
        // Mint SBT
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        // SBT should NOT be transferable
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.safeTransferFrom(user1, user2, tokenId);
    }
    
    function testFeeSplitCalculation() public {
        // Mint SBT
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        uint256 treasuryBefore = treasury.balance;
        uint256 organizerBefore = organizer.balance;
        uint256 upgradeFee = 0.001 ether;
        
        // Upgrade
        vm.prank(user1);
        merchManager.upgradeSBTWithAttestation{value: upgradeFee}(
            tokenId,
            organizer,
            event1Id
        );
        
        // Verify 37.5% / 62.5% split
        uint256 expectedTreasury = (upgradeFee * 3750) / 10000;
        uint256 expectedOrganizer = (upgradeFee * 6250) / 10000;
        
        assertEq(treasury.balance - treasuryBefore, expectedTreasury);
        assertEq(organizer.balance - organizerBefore, expectedOrganizer);
    }
    
    function testContractAddressesQuery() public view {
        (address basic, address premium, address eas) = merchManager.getContractAddresses();
        
        assertEq(basic, address(basicMerch));
        assertEq(premium, address(premiumMerch));
        assertEq(eas, address(easIntegration));
    }
    
    function testGetUpgradeFee() public {
        uint256 fee = merchManager.getUpgradeFee();
        assertEq(fee, 0.001 ether);
        
        // Change fee in premium contract
        premiumMerch.setUpgradeFee(0.002 ether);
        
        fee = merchManager.getUpgradeFee();
        assertEq(fee, 0.002 ether);
    }
    
    function testCanUserUpgradeSBT() public {
        // Mint SBT
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        // Check if user can upgrade
        (bool canUpgrade, string memory reason) = merchManager.canUserUpgradeSBT(tokenId, user1);
        assertTrue(canUpgrade);
        assertEq(reason, "Can upgrade");
        
        // Check if non-owner can upgrade
        (canUpgrade, reason) = merchManager.canUserUpgradeSBT(tokenId, user2);
        assertFalse(canUpgrade);
        assertEq(reason, "Not owner");
        
        // Upgrade
        vm.prank(user1);
        merchManager.upgradeSBTWithAttestation{value: 0.001 ether}(
            tokenId,
            organizer,
            event1Id
        );
        
        // Check if already upgraded
        (canUpgrade, reason) = merchManager.canUserUpgradeSBT(tokenId, user1);
        assertFalse(canUpgrade);
        assertEq(reason, "Already upgraded");
    }
    
    function testPausePreventUpgrade() public {
        // Mint SBT
        (uint256 tokenId,) = merchManager.mintSBTWithAttestation(
            user1,
            "ipfs://QmTest",
            event1Id
        );
        
        // Pause premium contract
        premiumMerch.pause();
        
        // Try to upgrade (should fail)
        vm.prank(user1);
        vm.expectRevert();
        merchManager.upgradeSBTWithAttestation{value: 0.001 ether}(
            tokenId,
            organizer,
            event1Id
        );
        
        // Unpause and try again (should succeed)
        premiumMerch.unpause();
        
        vm.prank(user1);
        merchManager.upgradeSBTWithAttestation{value: 0.001 ether}(
            tokenId,
            organizer,
            event1Id
        );
    }
}