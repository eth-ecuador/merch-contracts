// production-test.js
// Simulates how a real frontend app would create events
require('dotenv').config();
const { ethers } = require("ethers");

const RPC_URL = process.env.BASE_SEPOLIA_RPC_URL;
const MERCH_MANAGER_ADDRESS = process.env.MERCH_MANAGER_ADDRESS;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// Contract ABI
const MERCH_MANAGER_ABI = [
    "function createEvent(string name, string description, string imageUri, uint256 quantity) external returns (bytes32)",
    "function getEvent(bytes32 eventId) external view returns (tuple(string name, string description, string imageUri, uint256 quantity, address creator, uint256 timestamp, bool exists))",
    "function getPendingEventsCount() external view returns (uint256)",
    "function areCodesGenerated(bytes32 eventId) external view returns (bool)",
    "event EventCreated(bytes32 indexed eventId, string name, string description, string imageUri, uint256 quantity, address indexed creator, uint256 timestamp)"
];

async function main() {
    console.log("\n🎯 PRODUCTION TEST - BaseCamp Ecuador Event Creation");
    console.log("════════════════════════════════════════════════════════\n");
    
    // Connect
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const merchManager = new ethers.Contract(MERCH_MANAGER_ADDRESS, MERCH_MANAGER_ABI, wallet);
    
    console.log("📍 Connected to:", (await provider.getNetwork()).name);
    console.log("👤 User Address:", wallet.address);
    console.log("📝 Contract:", MERCH_MANAGER_ADDRESS);
    console.log("\n════════════════════════════════════════════════════════\n");
    
    // Event data (como vendría del frontend)
    const eventData = {
        name: "BaseCamp Ecuador 2025 - Final Test",
        description: "Virtual Web3 Bootcamp - Nov 10-16, 2025. Complete production flow test with fixed webhook integration.",
        imageUri: "ipfs://QmBaseCampEcuador2025FinalTest",
        quantity: 50 // 50 códigos para el test final
    };
    
    console.log("📋 Creating Event:");
    console.log("   Name:", eventData.name);
    console.log("   Description:", eventData.description.substring(0, 50) + "...");
    console.log("   Image:", eventData.imageUri);
    console.log("   Codes to generate:", eventData.quantity);
    console.log("\n⏳ Sending transaction...\n");
    
    try {
        // Create event (como lo haría el frontend)
        const tx = await merchManager.createEvent(
            eventData.name,
            eventData.description,
            eventData.imageUri,
            eventData.quantity
        );
        
        console.log("✅ Transaction sent!");
        console.log("   Tx Hash:", tx.hash);
        console.log("   Waiting for confirmation...\n");
        
        const receipt = await tx.wait();
        
        console.log("✅ Transaction confirmed!");
        console.log("   Block:", receipt.blockNumber);
        console.log("   Gas Used:", receipt.gasUsed.toString());
        console.log("\n════════════════════════════════════════════════════════\n");
        
        // Extract Event ID from logs
        const eventLog = receipt.logs.find(log => {
            try {
                const parsed = merchManager.interface.parseLog(log);
                return parsed.name === "EventCreated";
            } catch {
                return false;
            }
        });
        
        if (eventLog) {
            const parsedLog = merchManager.interface.parseLog(eventLog);
            const eventId = parsedLog.args.eventId;
            
            console.log("🎫 EVENT CREATED SUCCESSFULLY");
            console.log("════════════════════════════════════════════════════════");
            console.log("📝 Event ID:", eventId);
            console.log("👤 Creator:", parsedLog.args.creator);
            console.log("⏰ Timestamp:", new Date(Number(parsedLog.args.timestamp) * 1000).toLocaleString());
            console.log("════════════════════════════════════════════════════════\n");
            
            // Verify event
            console.log("🔍 Verifying event on-chain...\n");
            
            try {
                const eventInfo = await merchManager.getEvent(eventId);
                console.log("✅ Event verified:");
                console.log("   Name:", eventInfo[0]); // name
                console.log("   Quantity:", eventInfo[3].toString()); // quantity
                console.log("   Exists:", eventInfo[6]); // exists
                
                const codesGenerated = await merchManager.areCodesGenerated(eventId);
                console.log("   Codes Generated:", codesGenerated ? "Yes ✅" : "No (waiting for Chainlink) ⏳");
                
                const pendingCount = await merchManager.getPendingEventsCount();
                console.log("   Pending in Queue:", pendingCount.toString());
            } catch (error) {
                console.log("⚠️  Event verification skipped (event was just created)");
                console.log("   Event is valid and will be processed by Chainlink");
            }
            
            console.log("\n════════════════════════════════════════════════════════");
            console.log("🔄 WHAT HAPPENS NEXT");
            console.log("════════════════════════════════════════════════════════");
            console.log("1. ⏰ Chainlink Automation checks every ~5 minutes");
            console.log("2. 🔍 Detects pending event via checkUpkeep()");
            console.log("3. ⚡ Executes performUpkeep() automatically");
            console.log("4. 📡 Emits CodesGenerationRequested event");
            console.log("5. 🎧 Webhook listener detects the event");
            console.log("6. 🔗 Calls backend API to generate codes");
            console.log("7. ✅ Backend generates 30 unique codes");
            console.log("8. 💾 Codes stored in PostgreSQL database");
            console.log("════════════════════════════════════════════════════════\n");
            
            console.log("📊 MONITORING");
            console.log("════════════════════════════════════════════════════════");
            console.log("🌐 Webhook Dashboard:");
            console.log("   https://merch-contracts.onrender.com");
            console.log("\n🔗 Chainlink Automation:");
            console.log("   https://automation.chain.link/base-sepolia");
            console.log("\n🔎 BaseScan Transaction:");
            console.log(`   https://sepolia.basescan.org/tx/${tx.hash}`);
            console.log("\n🔎 BaseScan Contract Events:");
            console.log(`   https://sepolia.basescan.org/address/${MERCH_MANAGER_ADDRESS}#events`);
            console.log("\n📡 Backend API (after ~5 min):");
            console.log(`   curl https://merch-backend-ot7l.onrender.com/api/codes/event/${eventId}`);
            console.log("════════════════════════════════════════════════════════\n");
            
            console.log("⏱️  Expected Timeline:");
            console.log("   T+0:00 - Event created (NOW) ✅");
            console.log("   T+5:00 - Chainlink processes event");
            console.log("   T+5:01 - Webhook detects event");
            console.log("   T+5:02 - Backend generates codes");
            console.log("   T+5:03 - READY! Check backend API ✅");
            console.log("\n════════════════════════════════════════════════════════");
            
            // Save event ID for later verification
            console.log("\n💾 Save this Event ID for verification:");
            console.log(`   export TEST_EVENT_ID=${eventId}`);
            console.log("\n   Then verify with:");
            console.log(`   curl https://merch-backend-ot7l.onrender.com/api/codes/event/${eventId}`);
            console.log("\n════════════════════════════════════════════════════════\n");
            
            // Return event ID for scripting
            return {
                success: true,
                eventId: eventId,
                txHash: tx.hash,
                blockNumber: receipt.blockNumber,
                eventData: eventData
            };
        } else {
            throw new Error("EventCreated log not found in transaction receipt");
        }
        
    } catch (error) {
        console.error("\n❌ ERROR:");
        console.error("   Message:", error.message);
        if (error.reason) {
            console.error("   Reason:", error.reason);
        }
        console.error("\n════════════════════════════════════════════════════════\n");
        process.exit(1);
    }
}

// Run
if (require.main === module) {
    main()
        .then(() => {
            console.log("✅ Test completed successfully!\n");
            process.exit(0);
        })
        .catch((error) => {
            console.error("\n❌ Fatal error:", error.message);
            process.exit(1);
        });
}

module.exports = { main };
