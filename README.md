# Merch MVP - Soul Bound Token & Premium NFT System

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-Passing-success)](https://github.com)

A complete system for event attendance proof using Soul Bound Tokens (SBT) with the ability to upgrade to tradable Premium NFTs. Built and deployed on Base Sepolia testnet with **signature-based public minting** and **dynamic event creation** for maximum scalability.

## 🆕 Latest Update - Dynamic Events System

### Anyone Can Create Events

The system now supports **permissionless event creation** - any user can create events on-chain with automatic code generation.

**Previous Flow (❌):** Only admin can register events  
**New Flow (✅):** Any user creates event → Backend auto-generates codes → Infinitely scalable

**Key Features:**
- 🎉 **Permissionless** - Anyone can create events
- 🤖 **Automatic** - Backend generates 100 claim codes per event
- 🖼️ **IPFS Images** - Upload images to permanent storage
- 📊 **Full Control** - Creators can update/deactivate their events
- 🎫 **Max Attendees** - Set limits or unlimited capacity
- 🔍 **On-chain Registry** - All event data stored on Base Sepolia

---

## 🗂️ Architecture

```
User uploads image → IPFS (via backend)
         ↓
User creates event on-chain (pays gas)
         ↓
EventCreated emitted → Backend listener detects
         ↓
Backend auto-generates 100 claim codes ✅
         ↓
Codes ready for distribution
```

### Contract Addresses (Base Sepolia)

| Contract | Address | Status |
|----------|---------|--------|
| **BasicMerch** | `0xaD3d265112967c52a9BE48F4a61b89B48a5098F1` | ✅ Verified |
| **PremiumMerch** | `0x139894eB07f6cFDd10f36D1Af31EeB236C03443B` | ✅ Verified |
| **EASIntegration** | `0x985eCaBA2B222971fc018983004C226076fBf723` | ✅ Verified |
| **MerchManager** | `0xD71F654c7B9C15A54B2617262369fA219c15fe24` | ✅ Verified |

**Deployment Date:** January 23, 2025  
**Network:** Base Sepolia (Chain ID: 84532)  
**Explorer:** https://sepolia.basescan.org/

---

## 🎯 Key Features

### 1. Dynamic Event Creation
```solidity
// ANY user can create events
function createEvent(
    string memory name,
    string memory description,
    string memory imageURI,      // IPFS hash
    uint256 maxAttendees         // 0 = unlimited
) external returns (bytes32);
```

### 2. Signature-Based Public Minting
```solidity
// Users pay gas, backend signs (free)
function mintSBTWithAttestation(
    address _to,
    string memory _tokenURI,
    bytes32 _eventId,
    bytes memory _signature  // From backend API
) external returns (uint256, bytes32);
```

### 3. Event Management
```solidity
// Only creator can update
function updateEvent(bytes32 eventId, string memory name, string memory description, string memory imageURI) external;

// Only creator can activate/deactivate
function setEventStatus(bytes32 eventId, bool isActive) external;

// View functions
function getEvent(bytes32 eventId) external view returns (...);
function getAllEvents() external view returns (bytes32[] memory);
function getEventsByCreator(address creator) external view returns (bytes32[] memory);
function getRemainingSpots(bytes32 eventId) external view returns (uint256);
```

---

## 🌐 Frontend Integration Examples

### Create Event Flow

```javascript
import { ethers } from 'ethers';

async function createEvent(eventData) {
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  
  // Step 1: Upload image to IPFS
  const formData = new FormData();
  formData.append('image', eventData.imageFile);
  
  const uploadResponse = await fetch('https://api.yourbackend.com/api/events/upload-image', {
    method: 'POST',
    body: formData
  });
  
  const { imageUri } = await uploadResponse.json();
  // imageUri = "ipfs://QmXxx..."
  
  // Step 2: Create event on-chain
  const merchManager = new ethers.Contract(
    '0xD71F654c7B9C15A54B2617262369fA219c15fe24',
    [
      'function createEvent(string,string,string,uint256) external returns (bytes32)'
    ],
    signer
  );
  
  const tx = await merchManager.createEvent(
    eventData.name,
    eventData.description,
    imageUri,              // From step 1
    eventData.maxAttendees // 0 = unlimited
  );
  
  const receipt = await tx.wait();
  
  // Step 3: Backend automatically detects event and generates codes
  console.log('✅ Event created! Backend generating codes...');
  
  return receipt.transactionHash;
}
```

### Claim NFT Flow

```javascript
async function claimMerch(claimCode) {
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  const userAddress = await signer.getAddress();
  
  // 1. Get signature from backend API
  const response = await fetch('https://api.yourbackend.com/api/verify-code', {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'X-API-KEY': 'your_api_key'
    },
    body: JSON.stringify({ 
      code: claimCode, 
      walletAddress: userAddress 
    })
  });
  
  const { eventId, tokenURI, signature } = await response.json();
  
  // 2. User calls contract with signature (pays gas)
  const merchManager = new ethers.Contract(
    '0xD71F654c7B9C15A54B2617262369fA219c15fe24',
    [
      'function mintSBTWithAttestation(address,string,bytes32,bytes) external returns (uint256,bytes32)'
    ],
    signer
  );
  
  const tx = await merchManager.mintSBTWithAttestation(
    userAddress,
    tokenURI,
    eventId,
    signature
  );
  
  const receipt = await tx.wait();
  console.log('✅ NFT minted!');
  
  return receipt.transactionHash;
}
```

### Query Events

```javascript
async function getMyEvents(userAddress) {
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  const merchManager = new ethers.Contract(
    '0xD71F654c7B9C15A54B2617262369fA219c15fe24',
    [
      'function getEventsByCreator(address) external view returns (bytes32[])',
      'function getEvent(bytes32) external view returns (string,string,string,address,bool,uint256,uint256,uint256)'
    ],
    provider
  );
  
  // Get event IDs
  const eventIds = await merchManager.getEventsByCreator(userAddress);
  
  // Get details for each event
  const events = await Promise.all(
    eventIds.map(async (eventId) => {
      const [name, description, imageURI, creator, isActive, createdAt, totalAttendees, maxAttendees] 
        = await merchManager.getEvent(eventId);
      
      return {
        eventId,
        name,
        description,
        imageURI,
        creator,
        isActive,
        createdAt: Number(createdAt),
        totalAttendees: Number(totalAttendees),
        maxAttendees: Number(maxAttendees)
      };
    })
  );
  
  return events;
}
```

---

## 🖥️ Backend Setup

### Image Upload Endpoint

```javascript
const express = require('express');
const multer = require('multer');
const FormData = require('form-data');
const fetch = require('node-fetch');

const app = express();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// Upload image to IPFS (Pinata)
app.post('/api/events/upload-image', upload.single('image'), async (req, res) => {
  try {
    const formData = new FormData();
    formData.append('file', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype
    });
    
    const response = await fetch('https://api.pinata.cloud/pinning/pinFileToIPFS', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.PINATA_JWT}`
      },
      body: formData
    });
    
    const data = await response.json();
    
    res.json({
      success: true,
      storage: 'ipfs',
      imageUri: `ipfs://${data.IpfsHash}`,
      ipfsHash: data.IpfsHash,
      gatewayUrl: `https://gateway.pinata.cloud/ipfs/${data.IpfsHash}`
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

### Event Listener Service

```javascript
const { ethers } = require('ethers');

class EventListenerService {
  constructor() {
    this.provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
    this.contract = new ethers.Contract(
      '0xD71F654c7B9C15A54B2617262369fA219c15fe24',
      [
        'event EventCreated(bytes32 indexed eventId, address indexed creator, string name, string description, string imageURI, uint256 maxAttendees, uint256 timestamp)'
      ],
      this.provider
    );
  }
  
  startListening() {
    console.log('👂 Listening for events...');
    
    this.contract.on('EventCreated', async (eventId, creator, name, description, imageURI, maxAttendees, timestamp) => {
      console.log('🎉 NEW EVENT DETECTED!');
      console.log('  Event ID:', eventId);
      console.log('  Creator:', creator);
      console.log('  Name:', name);
      console.log('  Image:', imageURI);
      
      // Generate 100 claim codes automatically
      await generateCodesForEvent(eventId, name, description, imageURI, 100);
      
      console.log('✅ Event processed!\n');
    });
  }
}

// Start listener
const listener = new EventListenerService();
listener.startListening();
```

### Signature Generation

```javascript
const express = require('express');
const { ethers } = require('ethers');

const app = express();
const backendWallet = new ethers.Wallet(process.env.BACKEND_ISSUER_PRIVATE_KEY);

app.post('/api/verify-code', async (req, res) => {
  const { code, walletAddress } = req.body;
  
  // Verify claim code
  const claim = await db.getClaim(code);
  if (!claim || claim.used) {
    return res.status(400).json({ error: 'Invalid or used code' });
  }
  
  // Mark as used
  await db.markAsUsed(code, walletAddress);
  
  // Generate signature (FREE - no transaction)
  const messageHash = ethers.solidityPackedKeccak256(
    ['address', 'uint256', 'string'],
    [walletAddress, claim.eventId, claim.tokenURI]
  );
  
  const signature = await backendWallet.signMessage(ethers.getBytes(messageHash));
  
  res.json({ 
    eventId: claim.eventId, 
    tokenURI: claim.tokenURI, 
    signature,
    is_valid: true
  });
});

app.listen(3000);
```

---

## 🚀 Quick Start

### 1. Clone and Install

```bash
git clone https://github.com/your-repo/merch-contracts
cd merch-contracts
forge install
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

**Required variables:**
```bash
PRIVATE_KEY=your_deployer_private_key
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=your_basescan_api_key (optional)
BACKEND_ISSUER_ADDRESS=0x648a3e5510f55B4995fA5A22cCD62e2586ACb901
TREASURY_ADDRESS=0x648a3e5510f55B4995fA5A22cCD62e2586ACb901
```

### 3. Deploy

```bash
# Deploy all contracts
forge script script/DeployMerchMVP.s.sol:DeployMerchMVP \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Test dynamic events
forge script script/TestDynamicEvents.s.sol:TestDynamicEvents \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast
```

### 4. Run Tests

```bash
# Run all tests
forge test -vvv

# Run specific test
forge test --match-test testCreateEventByAnyUser -vvvv

# Coverage
forge coverage
```

---

## 📊 System Comparison

### Cost Analysis

| Metric | Admin Model | Dynamic Events |
|--------|-------------|----------------|
| Who creates events | Admin only | **Anyone** |
| Backend setup | Manual | **Automatic** |
| Code generation | Manual | **<1 second** |
| Event creation cost | $0 | **~$0.001** (Base) |
| Scalability | Limited | **Infinite** |
| Backend minting cost | $0 | **$0** (signatures) |

### Feature Comparison

| Feature | Status |
|---------|--------|
| Permissionless event creation | ✅ |
| IPFS image upload | ✅ |
| Automatic code generation | ✅ |
| Event update/deactivate | ✅ |
| Max attendees limit | ✅ |
| Event queries (by creator, all, etc.) | ✅ |
| Signature-based minting | ✅ |
| Soul Bound Tokens (SBT) | ✅ |
| Premium NFT upgrade | ✅ |
| EAS Attestations | ✅ |

---

## 🔐 Security Features

- ✅ **Signature Verification** - ECDSA with ecrecover (EIP-191)
- ✅ **Access Control** - Only creators can update their events
- ✅ **Max Attendees** - Enforce capacity limits on-chain
- ✅ **ReentrancyGuard** - All state-changing functions protected
- ✅ **Duplicate Prevention** - One SBT per user per event
- ✅ **Event Deactivation** - Creators can pause minting
- ✅ **No Backend Funds** - Backend issuer needs $0 ETH
- ✅ **Comprehensive Tests** - Full test coverage

**Backend Security:**
- Store private key in environment variables
- NEVER commit credentials to Git
- Rotate issuer wallet periodically
- Use rate limiting on API endpoints

---

## 📁 Project Structure

```
merch-contracts/
├── src/
│   ├── BasicMerch.sol           # SBT (ERC-4973)
│   ├── PremiumMerch.sol          # Premium NFT (ERC-721)
│   ├── EASIntegration.sol        # Attestation system
│   └── MerchManager.sol          # ⭐ Main coordinator (Dynamic Events)
├── script/
│   ├── DeployMerchMVP.s.sol      # Full deployment
│   ├── TestDynamicEvents.s.sol   # Test event creation
│   └── VerifyContracts.s.sol     # BaseScan verification
├── test/
│   ├── BasicMerch.t.sol
│   ├── PremiumMerch.t.sol
│   └── MerchMVPIntegration.t.sol # ⭐ Full system tests
└── deployments/
    └── base-sepolia.json         # Deployed addresses
```

---

## 🧪 Testing

### Run Tests

```bash
# All tests
forge test -vvv

# Specific contract
forge test --match-contract MerchMVPIntegrationTest -vvv

# Specific test
forge test --match-test testCreateEventByAnyUser -vvvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Test Examples

```solidity
// Test: Anyone can create events
function testCreateEventByAnyUser() public {
    vm.prank(user1);
    bytes32 eventId = merchManager.createEvent(
        "My Event",
        "Description",
        "ipfs://QmTest",
        100
    );
    
    assertTrue(merchManager.isEventRegistered(eventId));
    assertTrue(merchManager.isEventActive(eventId));
}

// Test: Max attendees enforcement
function testMaxAttendeesLimit() public {
    bytes32 eventId = merchManager.createEvent(
        "Small Event",
        "Only 2 spots",
        "ipfs://test",
        2
    );
    
    // Mint for user1 and user2 (OK)
    mintSBT(user1, eventId);
    mintSBT(user2, eventId);
    
    // Try to mint for user3 (should fail)
    vm.expectRevert(MerchManager.EventFull.selector);
    mintSBT(user3, eventId);
}
```

---

## 🛠️ Cast Commands

### Query Events

```bash
# Get all events
cast call $MERCH_MANAGER "getAllEvents()" --rpc-url $BASE_SEPOLIA_RPC_URL

# Get events by creator
cast call $MERCH_MANAGER \
  "getEventsByCreator(address)" \
  $YOUR_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Get event details
cast call $MERCH_MANAGER \
  "getEvent(bytes32)" \
  $EVENT_ID \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Get remaining spots
cast call $MERCH_MANAGER \
  "getRemainingSpots(bytes32)" \
  $EVENT_ID \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Create Event

```bash
cast send $MERCH_MANAGER \
  "createEvent(string,string,string,uint256)" \
  "My Event" \
  "Event Description" \
  "ipfs://QmXxx..." \
  100 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Update Event

```bash
cast send $MERCH_MANAGER \
  "updateEvent(bytes32,string,string,string)" \
  $EVENT_ID \
  "New Name" \
  "New Description" \
  "ipfs://NewImage" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 📚 Documentation

For complete documentation:
- [Deployment Guide](./WHAT_TO_UPDATE.md) - What to update
- [Scripts Guide](./SCRIPTS_GUIDE.md) - Deployment scripts
- [Verification Guide](./VERIFICATION_GUIDE.md) - Contract verification
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md) - Visual flow

---

## 🌟 Use Cases

1. **Conference Attendance** - Proof of attendance with exclusive perks
2. **Workshop Certificates** - Verifiable skill badges
3. **Community Meetups** - Membership tokens with benefits
4. **Hackathon Participation** - Team achievements and prizes
5. **Course Completion** - Educational credentials
6. **VIP Events** - Access control and collectibles

---

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Submit a pull request

---

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details

---

## 🔗 Links

- **BaseScan Explorer:** https://sepolia.basescan.org/
- **Base Docs:** https://docs.base.org/
- **Foundry Book:** https://book.getfoundry.sh/
- **EAS Documentation:** https://docs.attest.sh/

---

## 📞 Support

For questions or issues:
- Open an issue on GitHub
- Check existing documentation
- Review test files for examples

---

**Happy Building! 🚀**

With dynamic events and signature-based minting, your system is ready to scale to millions of users at near-zero cost.

---

## 🎯 Quick Links to Deployed Contracts

- [BasicMerch](https://sepolia.basescan.org/address/0xaD3d265112967c52a9BE48F4a61b89B48a5098F1#code)
- [PremiumMerch](https://sepolia.basescan.org/address/0x139894eB07f6cFDd10f36D1Af31EeB236C03443B#code)
- [EASIntegration](https://sepolia.basescan.org/address/0x985eCaBA2B222971fc018983004C226076fBf723#code)
- [MerchManager](https://sepolia.basescan.org/address/0xD71F654c7B9C15A54B2617262369fA219c15fe24#code)
