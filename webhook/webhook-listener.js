// webhook-listener.js
// Simple webhook that listens to CodesGenerationRequested and calls backend
require('dotenv').config();
const { ethers } = require("ethers");

// Configuration
const RPC_URL = process.env.BASE_SEPOLIA_RPC_URL;
const MERCH_MANAGER_ADDRESS = process.env.MERCH_MANAGER_ADDRESS;
const API_KEY = process.env.API_KEY;
const BACKEND_URL = process.env.BACKEND_URL || "https://merch-backend-ot7l.onrender.com";

// Contract ABI (only the event we need)
const MERCH_MANAGER_ABI = [
    "event CodesGenerationRequested(bytes32 indexed eventId, string name, string description, string imageUri, uint256 quantity)"
];

async function main() {
    console.log("\n🎧 Chainlink Webhook Listener Starting...\n");
    console.log("════════════════════════════════════════");
    console.log("Configuration:");
    console.log("════════════════════════════════════════");
    console.log("RPC URL:", RPC_URL);
    console.log("Contract:", MERCH_MANAGER_ADDRESS);
    console.log("Backend:", BACKEND_URL);
    console.log("API Key:", API_KEY ? API_KEY.substring(0, 10) + "..." : "NOT SET");
    console.log("════════════════════════════════════════\n");
    
    // Validate configuration
    if (!RPC_URL) throw new Error("BASE_SEPOLIA_RPC_URL not set");
    if (!MERCH_MANAGER_ADDRESS) throw new Error("MERCH_MANAGER_ADDRESS not set");
    if (!API_KEY) throw new Error("API_KEY not set");
    
    // Connect to provider
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    
    // Get contract
    const merchManager = new ethers.Contract(
        MERCH_MANAGER_ADDRESS,
        MERCH_MANAGER_ABI,
        provider
    );
    
    // Verify connection
    try {
        const network = await provider.getNetwork();
        console.log("✅ Connected to network:", network.name, `(Chain ID: ${network.chainId})`);
        console.log("✅ Listening for CodesGenerationRequested events...\n");
    } catch (error) {
        console.error("❌ Failed to connect to network:", error.message);
        process.exit(1);
    }
    
    // Listen for CodesGenerationRequested events
    merchManager.on(
        "CodesGenerationRequested",
        async (eventId, name, description, imageUri, quantity, event) => {
            console.log("\n🎫 ═══════════════════════════════════════");
            console.log("   NEW CODES GENERATION REQUEST");
            console.log("   ═══════════════════════════════════════");
            console.log("   Event ID:", eventId);
            console.log("   Name:", name);
            console.log("   Description:", description);
            console.log("   Image URI:", imageUri);
            console.log("   Quantity:", quantity.toString());
            console.log("   Block:", event.log.blockNumber);
            console.log("   Tx Hash:", event.log.transactionHash);
            console.log("   ═══════════════════════════════════════\n");
            
            try {
                // Call backend API
                console.log("📤 Calling backend API...");
                
                const response = await fetch(`${BACKEND_URL}/api/createCodes`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "X-API-KEY": API_KEY
                    },
                    body: JSON.stringify({
                        eventId: eventId,
                        eventName: name,
                        eventDescription: description,
                        imageUri: imageUri,
                        quantity: Number(quantity)
                    })
                });
                
                const result = await response.json();
                
                if (response.ok && result.success) {
                    console.log("✅ Backend response: SUCCESS");
                    console.log("   Codes generated:", result.codesGenerated);
                    console.log("   Message:", result.message);
                } else {
                    console.log("❌ Backend response: FAILED");
                    console.log("   Status:", response.status);
                    console.log("   Error:", result.error || "Unknown error");
                }
                
            } catch (error) {
                console.error("❌ Error calling backend:", error.message);
            }
            
            console.log("   ═══════════════════════════════════════\n");
        }
    );
    
    // Handle errors
    provider.on("error", (error) => {
        console.error("❌ Provider error:", error);
    });
    
    // Keep alive
    console.log("👂 Webhook is listening...");
    console.log("   Press Ctrl+C to stop\n");
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log("\n\n🛑 Shutting down webhook listener...");
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log("\n\n🛑 Shutting down webhook listener...");
    process.exit(0);
});

// Start
main().catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
});
