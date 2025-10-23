// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MerchManager.sol";

/**
 * @title TestDynamicEvents
 * @notice Script to test the new dynamic event creation features
 * @dev Run with: forge script script/TestDynamicEvents.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv
 */
contract TestDynamicEvents is Script {
    
    MerchManager public merchManager;
    
    function run() external {
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get MerchManager address from deployment file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/base-sepolia.json");
        
        address merchManagerAddress;
        
        // Try to read from file, otherwise use env variable
        try vm.readFile(path) returns (string memory json) {
            merchManagerAddress = vm.parseJsonAddress(json, ".contracts.merchManager");
        } catch {
            merchManagerAddress = vm.envAddress("MERCH_MANAGER_ADDRESS");
        }
        
        merchManager = MerchManager(merchManagerAddress);
        
        console.log("===========================================");
        console.log("Testing Dynamic Event Creation");
        console.log("===========================================");
        console.log("MerchManager:", address(merchManager));
        console.log("Test User:", deployer);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Test 1: Create a simple event
        console.log("\n[Test 1] Creating event with unlimited attendees...");
        bytes32 event1 = merchManager.createEvent(
            "Web3 Meetup Ecuador 2025",
            "Join us for an amazing Web3 community meetup in Ecuador!",
            "ipfs://QmTest123abc",
            0  // unlimited attendees
        );
        console.log("  Event 1 ID:", vm.toString(event1));
        
        // Test 2: Create an event with max attendees
        console.log("\n[Test 2] Creating event with 50 max attendees...");
        bytes32 event2 = merchManager.createEvent(
            "NFT Workshop",
            "Learn how to create and mint your own NFTs",
            "ipfs://QmTest456def",
            50  // max 50 attendees
        );
        console.log("  Event 2 ID:", vm.toString(event2));
        
        // Test 3: Create another event
        console.log("\n[Test 3] Creating third event...");
        bytes32 event3 = merchManager.createEvent(
            "DeFi Summit",
            "Explore the future of decentralized finance",
            "ipfs://QmTest789ghi",
            100
        );
        console.log("  Event 3 ID:", vm.toString(event3));
        
        vm.stopBroadcast();
        
        // Verify events were created
        console.log("\n===========================================");
        console.log("Verifying Events");
        console.log("===========================================");
        
        verifyEvent(event1, "Event 1");
        verifyEvent(event2, "Event 2");
        verifyEvent(event3, "Event 3");
        
        // Test queries
        console.log("\n===========================================");
        console.log("Testing Query Functions");
        console.log("===========================================");
        
        // Get all events
        bytes32[] memory allEvents = merchManager.getAllEvents();
        console.log("\nTotal events in system:", allEvents.length);
        
        // Get events by creator
        bytes32[] memory myEvents = merchManager.getEventsByCreator(deployer);
        console.log("Events created by", deployer, ":", myEvents.length);
        
        // Print summary
        printSummary(deployer);
    }
    
    function verifyEvent(bytes32 eventId, string memory name) internal view {
        console.log(string.concat("\n", name, ":"));
        console.log("  ID:", vm.toString(eventId));
        
        // Check if registered
        bool isRegistered = merchManager.isEventRegistered(eventId);
        bool isActive = merchManager.isEventActive(eventId);
        console.log("  Registered:", isRegistered ? "Yes" : "No");
        console.log("  Active:", isActive ? "Yes" : "No");
        
        // Get event details
        (
            string memory eventName,
            string memory description,
            string memory imageURI,
            address creator,
            bool active,
            uint256 createdAt,
            uint256 totalAttendees,
            uint256 maxAttendees
        ) = merchManager.getEvent(eventId);
        
        console.log("  Name:", eventName);
        console.log("  Description:", description);
        console.log("  Image URI:", imageURI);
        console.log("  Creator:", creator);
        console.log("  Created At:", createdAt);
        console.log("  Total Attendees:", totalAttendees);
        console.log("  Max Attendees:", maxAttendees == 0 ? "Unlimited" : vm.toString(maxAttendees));
        
        // Get remaining spots
        uint256 remaining = merchManager.getRemainingSpots(eventId);
        if (maxAttendees == 0) {
            console.log("  Remaining Spots: Unlimited");
        } else {
            console.log("  Remaining Spots:", remaining);
        }
    }
    
    function printSummary(address deployer) internal view {
        console.log("\n===========================================");
        console.log("TEST SUMMARY");
        console.log("===========================================");
        
        bytes32[] memory allEvents = merchManager.getAllEvents();
        bytes32[] memory myEvents = merchManager.getEventsByCreator(deployer);
        
        console.log("Total Events:", allEvents.length);
        console.log("Your Events:", myEvents.length);
        
        console.log("\n===========================================");
        console.log("NEXT STEPS");
        console.log("===========================================");
        console.log("1. Backend will auto-detect these events");
        console.log("2. Backend will generate 100 codes per event");
        console.log("3. Check backend logs for code generation");
        console.log("4. Query codes: GET /api/admin/list-claims");
        console.log("===========================================");
        
        console.log("\nView events on BaseScan:");
        console.log(string.concat(
            "https://sepolia.basescan.org/address/",
            vm.toString(address(merchManager)),
            "#events"
        ));
        
        console.log("\nTo update an event (only creator):");
        console.log("cast send", vm.toString(address(merchManager)), "\\");
        console.log("  'updateEvent(bytes32,string,string,string)' \\");
        console.log("  <EVENT_ID> \\");
        console.log("  'New Name' \\");
        console.log("  'New Description' \\");
        console.log("  'ipfs://NewImage' \\");
        console.log("  --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console.log("  --private-key $PRIVATE_KEY");
        
        console.log("\nTo deactivate an event (only creator):");
        console.log("cast send", vm.toString(address(merchManager)), "\\");
        console.log("  'setEventStatus(bytes32,bool)' \\");
        console.log("  <EVENT_ID> \\");
        console.log("  false \\");
        console.log("  --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console.log("  --private-key $PRIVATE_KEY");
    }
}
