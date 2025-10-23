// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";
import "../src/EASIntegration.sol";
import "../src/MerchManager.sol";

/**
 * @title MerchMVPIntegration - UPDATED with Dynamic Events Tests
 * @notice Complete end-to-end integration tests for the Merch MVP system
 * @notice ✅ NEW: Tests for public event creation
 */
contract MerchMVPIntegrationTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    EASIntegration public easIntegration;
    MerchManager public merchManager;
    
    address public owner;
    address public backendIssuer;
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
        backendIssuer = vm.addr(0x1);
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
        basicMerch.setBackendIssuer(backendIssuer);
        easIntegration.transferOwnership(address(merchManager));
        
        // Register events (old method for backward compatibility)
        event1Id = keccak256(bytes(EVENT1_METADATA));
        event2Id = keccak256(bytes(EVENT2_METADATA));
        
        merchManager.registerEvent(event1Id, EVENT1_METADATA);
        merchManager.registerEvent(event2Id, EVENT2_METADATA);
        
        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }
    
    function _generateSignature(
        address _to,
        uint256 _eventId,
        string memory _tokenURI
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(_to, _eventId, _tokenURI));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x1, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
    
    function _mintSBT(address _to, uint256 _eventId, string memory _tokenURI) internal returns (uint256) {
        bytes memory signature = _generateSignature(_to, _eventId, _tokenURI);
        return basicMerch.mintSBT(_to, _eventId, _tokenURI, signature);
    }
    
    // ============================================================
    // ✅ NEW: Dynamic Event Creation Tests
    // ============================================================
    
    function testCreateEventByAnyUser() public {
        // User1 creates an event
        vm.prank(user1);
        bytes32 eventId = merchManager.createEvent(
            "User1's Meetup",
            "A community meetup",
            "ipfs://QmTest123",
            50  // maxAttendees
        );
        
        // Verify event was created
        assertTrue(merchManager.isEventRegistered(eventId));
        assertTrue(merchManager.isEventActive(eventId));
        
        // Get event details
        (
            string memory name,
            string memory description,
            string memory imageURI,
            address creator,
            bool isActive,
            uint256 createdAt,
            uint256 totalAttendees,
            uint256 maxAttendees
        ) = merchManager.getEvent(eventId);
        
        assertEq(name, "User1's Meetup");
        assertEq(description, "A community meetup");
        assertEq(imageURI, "ipfs://QmTest123");
        assertEq(creator, user1);
        assertTrue(isActive);
        assertTrue(createdAt > 0);
        assertEq(totalAttendees, 0);
        assertEq(maxAttendees, 50);
    }
    
    function testCreateMultipleEventsByDifferentUsers() public {
        // User1 creates event
        vm.prank(user1);
        bytes32 event1 = merchManager.createEvent(
            "Event 1",
            "Description 1",
            "ipfs://Qm1",
            100
        );
        
        // User2 creates event
        vm.prank(user2);
        bytes32 event2 = merchManager.createEvent(
            "Event 2",
            "Description 2",
            "ipfs://Qm2",
            200
        );
        
        // User3 creates event
        vm.prank(user3);
        bytes32 event3 = merchManager.createEvent(
            "Event 3",
            "Description 3",
            "ipfs://Qm3",
            0  // unlimited
        );
        
        // Verify all events exist
        assertTrue(merchManager.isEventRegistered(event1));
        assertTrue(merchManager.isEventRegistered(event2));
        assertTrue(merchManager.isEventRegistered(event3));
        
        // Get all events
        bytes32[] memory allEvents = merchManager.getAllEvents();
        assertTrue(allEvents.length >= 5); // 2 from setUp + 3 new
    }
    
    function testGetEventsByCreator() public {
        // User1 creates 2 events
        vm.startPrank(user1);
        bytes32 event1 = merchManager.createEvent(
            "Event 1",
            "Desc 1",
            "ipfs://1",
            100
        );
        bytes32 event2 = merchManager.createEvent(
            "Event 2",
            "Desc 2",
            "ipfs://2",
            200
        );
        vm.stopPrank();
        
        // User2 creates 1 event
        vm.prank(user2);
        bytes32 event3 = merchManager.createEvent(
            "Event 3",
            "Desc 3",
            "ipfs://3",
            300
        );
        
        // Check events by creator
        bytes32[] memory user1Events = merchManager.getEventsByCreator(user1);
        bytes32[] memory user2Events = merchManager.getEventsByCreator(user2);
        
        assertEq(user1Events.length, 2);
        assertEq(user2Events.length, 1);
        assertEq(user1Events[0], event1);
        assertEq(user1Events[1], event2);
        assertEq(user2Events[0], event3);
    }
    
    function testUpdateEventByCreator() public {
        // User1 creates event
        vm.prank(user1);
        bytes32 eventId = merchManager.createEvent(
            "Original Name",
            "Original Description",
            "ipfs://original",
            100
        );
        
        // User1 updates event
        vm.prank(user1);
        merchManager.updateEvent(
            eventId,
            "Updated Name",
            "Updated Description",
            "ipfs://updated"
        );
        
        // Verify updates
        (
            string memory name,
            string memory description,
            string memory imageURI,
            ,,,, // skip other fields
        ) = merchManager.getEvent(eventId);
        
        assertEq(name, "Updated Name");
        assertEq(description, "Updated Description");
        assertEq(imageURI, "ipfs://updated");
    }
    
    function testCannotUpdateEventByNonCreator() public {
        // User1 creates event
        vm.prank(user1);
        bytes32 eventId = merchManager.createEvent(
            "Event",
            "Description",
            "ipfs://test",
            100
        );
        
        // User2 tries to update (should fail)
        vm.prank(user2);
        vm.expectRevert(MerchManager.NotEventCreator.selector);
        merchManager.updateEvent(
            eventId,
            "Hacked",
            "Hacked",
            "ipfs://hacked"
        );
    }
    
    function testSetEventStatus() public {
        // User1 creates event
        vm.prank(user1);
        bytes32 eventId = merchManager.createEvent(
            "Event",
            "Description",
            "ipfs://test",
            100
        );
        
        assertTrue(merchManager.isEventActive(eventId));
        
        // User1 deactivates event
        vm.prank(user1);
        merchManager.setEventStatus(eventId, false);
        
        assertFalse(merchManager.isEventActive(eventId));
        
        // User1 reactivates
        vm.prank(user1);
        merchManager.setEventStatus(eventId, true);
        
        assertTrue(merchManager.isEventActive(eventId));
    }
    
    function testCannotSetStatusByNonCreator() public {
        // User1 creates event
        vm.prank(user1);
        bytes32 eventId = merchManager.createEvent(
            "Event",
            "Description",
            "ipfs://test",
            100
        );
        
        // User2 tries to deactivate (should fail)
        vm.prank(user2);
        vm.expectRevert(MerchManager.NotEventCreator.selector);
        merchManager.setEventStatus(eventId, false);
    }
    
    function testMaxAttendeesLimit() public {
        // Create event with maxAttendees = 2
        vm.prank(organizer);
        bytes32 eventId = merchManager.createEvent(
            "Small Event",
            "Only 2 spots",
            "ipfs://small",
            2
        );
        
        // Mint for user1 (1/2)
        bytes memory sig1 = _generateSignature(user1, uint256(eventId), "ipfs://1");
        vm.prank(user1);
        merchManager.mintSBTWithAttestation(user1, "ipfs://1", eventId, sig1);
        
        // Mint for user2 (2/2)
        bytes memory sig2 = _generateSignature(user2, uint256(eventId), "ipfs://2");
        vm.prank(user2);
        merchManager.mintSBTWithAttestation(user2, "ipfs://2", eventId, sig2);
        
        // Try to mint for user3 (should fail - event full)
        bytes memory sig3 = _generateSignature(user3, uint256(eventId), "ipfs://3");
        vm.prank(user3);
        vm.expectRevert(MerchManager.EventFull.selector);
        merchManager.mintSBTWithAttestation(user3, "ipfs://3", eventId, sig3);
        
        // Verify remaining spots = 0
        assertEq(merchManager.getRemainingSpots(eventId), 0);
    }
    
    function testUnlimitedAttendees() public {
        // Create event with maxAttendees = 0 (unlimited)
        vm.prank(organizer);
        bytes32 eventId = merchManager.createEvent(
            "Huge Event",
            "Unlimited spots",
            "ipfs://huge",
            0  // unlimited
        );
        
        // Should allow many attendees
        for (uint i = 1; i <= 10; i++) {
            address user = address(uint160(i + 1000));
            vm.deal(user, 1 ether);
            
            bytes memory sig = _generateSignature(user, uint256(eventId), string(abi.encodePacked("ipfs://", i)));
            vm.prank(user);
            merchManager.mintSBTWithAttestation(user, string(abi.encodePacked("ipfs://", i)), eventId, sig);
        }
        
        // Verify remaining spots = unlimited
        assertEq(merchManager.getRemainingSpots(eventId), type(uint256).max);
    }
    
    function testGetRemainingSpots() public {
        vm.prank(organizer);
        bytes32 eventId = merchManager.createEvent(
            "Event",
            "Test",
            "ipfs://test",
            5  // max 5
        );
        
        // Initially 5 spots
        assertEq(merchManager.getRemainingSpots(eventId), 5);
        
        // Mint 2
        bytes memory sig1 = _generateSignature(user1, uint256(eventId), "ipfs://1");
        vm.prank(user1);
        merchManager.mintSBTWithAttestation(user1, "ipfs://1", eventId, sig1);
        
        bytes memory sig2 = _generateSignature(user2, uint256(eventId), "ipfs://2");
        vm.prank(user2);
        merchManager.mintSBTWithAttestation(user2, "ipfs://2", eventId, sig2);
        
        // Should have 3 remaining
        assertEq(merchManager.getRemainingSpots(eventId), 3);
    }
    
    function testCannotMintForInactiveEvent() public {
        // Create and deactivate event
        vm.prank(organizer);
        bytes32 eventId = merchManager.createEvent(
            "Event",
            "Test",
            "ipfs://test",
            100
        );
        
        vm.prank(organizer);
        merchManager.setEventStatus(eventId, false);
        
        // Try to mint (should fail)
        bytes memory sig = _generateSignature(user1, uint256(eventId), "ipfs://1");
        vm.prank(user1);
        vm.expectRevert(MerchManager.EventNotActive.selector);
        merchManager.mintSBTWithAttestation(user1, "ipfs://1", eventId, sig);
    }
    
    function testRevertIfEmptyEventName() public {
        vm.prank(user1);
        vm.expectRevert(MerchManager.EmptyEventName.selector);
        merchManager.createEvent(
            "",  // empty name
            "Description",
            "ipfs://test",
            100
        );
    }
    
    function testRevertIfEmptyImageURI() public {
        vm.prank(user1);
        vm.expectRevert(MerchManager.EmptyImageURI.selector);
        merchManager.createEvent(
            "Event",
            "Description",
            "",  // empty imageURI
            100
        );
    }
    
    // ============================================================
    // Existing Tests (Unchanged - Backward Compatibility)
    // ============================================================
    
    function testCompleteUserJourney() public {
        uint256 eventId1 = 1;
        string memory tokenURI1 = "ipfs://QmUser1Event1";
        uint256 tokenId1 = _mintSBT(user1, eventId1, tokenURI1);
        
        assertEq(basicMerch.ownerOf(tokenId1), user1);
        assertEq(basicMerch.getSBTByEvent(user1, eventId1), tokenId1);
        
        uint256 user1BalanceBefore = user1.balance;
        
        vm.prank(user1);
        premiumMerch.mintCompanion{value: 0.001 ether}(tokenId1, organizer, user1);
        
        assertEq(basicMerch.ownerOf(tokenId1), user1);
        uint256 premiumId1 = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId1), user1);
        
        assertEq(user1.balance, user1BalanceBefore - 0.001 ether);
        
        vm.prank(user1);
        premiumMerch.transferFrom(user1, user2, premiumId1);
        assertEq(premiumMerch.ownerOf(premiumId1), user2);
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
    }
    
    function testSBTNonTransferability() public {
        uint256 tokenId = _mintSBT(user1, uint256(event1Id), "ipfs://QmTest");
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
    }
    
    function testAccessControl() public {
        // Only owner can register events via old method
        vm.prank(user1);
        vm.expectRevert();
        merchManager.registerEvent(keccak256("New Event"), "New Event");
        
        // But anyone can create events via new method
        vm.prank(user1);
        bytes32 newEventId = merchManager.createEvent(
            "Public Event",
            "Anyone can create",
            "ipfs://test",
            100
        );
        assertTrue(merchManager.isEventRegistered(newEventId));
    }
}
