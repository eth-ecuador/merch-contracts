// webhook-listener.js
// Webhook listener with HTTP server for Render deployment
require('dotenv').config();
const { ethers } = require("ethers");
const http = require('http');
const axios = require('axios');

// Configuration
const RPC_URL = process.env.BASE_SEPOLIA_RPC_URL;
const MERCH_MANAGER_ADDRESS = process.env.MERCH_MANAGER_ADDRESS;
const API_KEY = process.env.API_KEY;
const BACKEND_URL = process.env.BACKEND_URL || "https://merch-backend-ot7l.onrender.com";
const PORT = process.env.PORT || 10000;

// Contract ABI (only the event we need)
const MERCH_MANAGER_ABI = [
    "event CodesGenerationRequested(bytes32 indexed eventId, string name, string description, string imageUri, uint256 quantity)"
];

let networkInfo = { name: 'unknown', chainId: 0 };
let eventCount = 0;
let lastEventTime = null;

async function main() {
    console.log("\n🎧 Chainlink Webhook Listener Starting...\n");
    console.log("════════════════════════════════════════");
    console.log("Configuration:");
    console.log("════════════════════════════════════════");
    console.log("RPC URL:", RPC_URL);
    console.log("Contract:", MERCH_MANAGER_ADDRESS);
    console.log("Backend:", BACKEND_URL);
    console.log("API Key:", API_KEY ? API_KEY.substring(0, 10) + "..." : "NOT SET");
    console.log("Port:", PORT);
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
        networkInfo = {
            name: network.name,
            chainId: Number(network.chainId)
        };
        console.log("✅ Connected to network:", networkInfo.name, `(Chain ID: ${networkInfo.chainId})`);
        console.log("✅ Listening for CodesGenerationRequested events...\n");
    } catch (error) {
        console.error("❌ Failed to connect to network:", error.message);
        process.exit(1);
    }
    
    // Create HTTP server for Render
    const server = http.createServer((req, res) => {
        // CORS headers
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
        
        if (req.method === 'OPTIONS') {
            res.writeHead(200);
            res.end();
            return;
        }
        
        if (req.url === '/health') {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                status: 'healthy',
                service: 'Merch Webhook Listener',
                contract: MERCH_MANAGER_ADDRESS,
                network: networkInfo.name,
                chainId: networkInfo.chainId,
                uptime: Math.floor(process.uptime()),
                eventsProcessed: eventCount,
                lastEventTime: lastEventTime
            }));
        } else if (req.url === '/') {
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(`
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Merch Webhook Listener</title>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; }
                        body { 
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            min-height: 100vh;
                            padding: 20px;
                        }
                        .container {
                            max-width: 800px;
                            margin: 0 auto;
                            background: white;
                            border-radius: 12px;
                            padding: 40px;
                            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                        }
                        h1 {
                            color: #333;
                            margin-bottom: 10px;
                            font-size: 2.5em;
                        }
                        .subtitle { color: #666; margin-bottom: 30px; font-size: 1.1em; }
                        .status {
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                            color: white;
                            border-radius: 8px;
                            padding: 20px;
                            margin: 20px 0;
                            text-align: center;
                        }
                        .status-icon { font-size: 2em; margin-bottom: 10px; }
                        .info-grid {
                            display: grid;
                            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                            gap: 15px;
                            margin: 20px 0;
                        }
                        .info-card {
                            background: #f8f9fa;
                            border-radius: 8px;
                            padding: 15px;
                            border-left: 4px solid #667eea;
                        }
                        .info-card strong { color: #333; display: block; margin-bottom: 5px; }
                        .info-card code {
                            background: white;
                            padding: 5px 8px;
                            border-radius: 4px;
                            font-size: 0.9em;
                            display: block;
                            word-break: break-all;
                            margin-top: 5px;
                        }
                        .stats {
                            display: flex;
                            justify-content: space-around;
                            margin: 30px 0;
                            text-align: center;
                        }
                        .stat-item { flex: 1; }
                        .stat-value {
                            font-size: 2.5em;
                            font-weight: bold;
                            color: #667eea;
                        }
                        .stat-label { color: #666; margin-top: 5px; }
                        .endpoints {
                            background: #f8f9fa;
                            border-radius: 8px;
                            padding: 20px;
                            margin: 20px 0;
                        }
                        .endpoints h2 { color: #333; margin-bottom: 15px; }
                        .endpoint {
                            background: white;
                            border-radius: 6px;
                            padding: 12px;
                            margin: 10px 0;
                            border-left: 3px solid #667eea;
                        }
                        .endpoint code {
                            color: #667eea;
                            font-weight: 600;
                        }
                        footer {
                            text-align: center;
                            color: #999;
                            margin-top: 40px;
                            padding-top: 20px;
                            border-top: 1px solid #eee;
                        }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🎧 Merch Webhook Listener</h1>
                        <p class="subtitle">Chainlink Automation Event Listener</p>
                        
                        <div class="status">
                            <div class="status-icon">✅</div>
                            <strong>Status: Active</strong>
                            <p>Listening for CodesGenerationRequested events</p>
                        </div>
                        
                        <div class="stats">
                            <div class="stat-item">
                                <div class="stat-value">${eventCount}</div>
                                <div class="stat-label">Events Processed</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value">${Math.floor(process.uptime())}s</div>
                                <div class="stat-label">Uptime</div>
                            </div>
                        </div>
                        
                        <div class="info-grid">
                            <div class="info-card">
                                <strong>📝 Contract</strong>
                                <code>${MERCH_MANAGER_ADDRESS}</code>
                            </div>
                            <div class="info-card">
                                <strong>🌐 Network</strong>
                                <code>${networkInfo.name} (${networkInfo.chainId})</code>
                            </div>
                            <div class="info-card">
                                <strong>🔗 Backend</strong>
                                <code>${BACKEND_URL}</code>
                            </div>
                            <div class="info-card">
                                <strong>⏰ Last Event</strong>
                                <code>${lastEventTime || 'No events yet'}</code>
                            </div>
                        </div>
                        
                        <div class="endpoints">
                            <h2>📡 API Endpoints</h2>
                            <div class="endpoint">
                                <code>GET /</code> - This dashboard
                            </div>
                            <div class="endpoint">
                                <code>GET /health</code> - Health check (JSON)
                            </div>
                        </div>
                        
                        <footer>
                            <p>Merch MVP - BaseCamp Ecuador 2025</p>
                        </footer>
                    </div>
                </body>
                </html>
            `);
        } else {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Not Found');
        }
    });
    
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`🌐 HTTP server running on port ${PORT}`);
        console.log(`   Health check: http://localhost:${PORT}/health`);
        console.log(`   Dashboard: http://localhost:${PORT}/`);
        console.log("\n👂 Webhook is listening for events...");
        console.log("   Press Ctrl+C to stop\n");
    });
    
    // Listen for CodesGenerationRequested events
    merchManager.on(
        "CodesGenerationRequested",
        async (eventId, name, description, imageUri, quantity, event) => {
            eventCount++;
            lastEventTime = new Date().toISOString();
            
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
                console.log("📤 Calling backend API...");
                
                const response = await axios.post(
                    `${BACKEND_URL}/api/createCodes`,
                    {
                        eventId: eventId,
                        eventName: name,
                        eventDescription: description,
                        imageUri: imageUri,
                        quantity: Number(quantity)
                    },
                    {
                        headers: {
                            'Content-Type': 'application/json',
                            'x-api-key': API_KEY
                        },
                        timeout: 30000
                    }
                );
                
                console.log("✅ Backend response: SUCCESS");
                console.log("   Codes generated:", response.data.codesGenerated || quantity.toString());
                console.log("   Message:", response.data.message);
                console.log("   ═══════════════════════════════════════\n");
                
            } catch (error) {
                console.error("❌ Error calling backend:");
                console.error("   Message:", error.message);
                if (error.response) {
                    console.error("   Status:", error.response.status);
                    console.error("   Data:", error.response.data);
                }
                console.error("   ═══════════════════════════════════════\n");
            }
        }
    );
}

// Handle shutdown gracefully
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