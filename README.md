# Merch MVP - Soul Bound Token & Premium NFT System

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A complete system for event attendance proof using Soul Bound Tokens (SBT) with the ability to upgrade to tradable Premium NFTs. Built for Base Sepolia testnet.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Installation](#installation)
- [Development](#development)
- [Deployment](#deployment)
- [Testing the Flow](#testing-the-flow)
- [Frontend Integration](#frontend-integration)
- [Contract Addresses](#contract-addresses)
- [Security](#security)

---

## 🎯 Overview

The Merch MVP system provides a two-tier token system for event attendance:

1. **Free Tier (SBT)**: Non-transferable proof of attendance token (ERC-4973)
2. **Paid Tier (Premium NFT)**: Tradable collectible NFT (ERC-721) with monetization

### Key Features

- ✅ Soul Bound Tokens for free attendance proof
- ✅ Upgrade mechanism to Premium NFTs
- ✅ Automatic fee distribution (37.5% platform / 62.5% organizer)
- ✅ Ethereum Attestation Service (EAS) integration
- ✅ Pausable and upgradeable architecture
- ✅ Gas optimized

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       MerchManager                          │
│                  (Main Orchestrator)                        │
│  • Register Events                                          │
│  • Mint SBT with Attestation                               │
│  • Upgrade SBT to Premium with Attestation                 │
└─────────────┬───────────────┬──────────────┬───────────────┘
              │               │              │
              ▼               ▼              ▼
    ┌─────────────┐  ┌──────────────┐  ┌──────────────┐
    │ BasicMerch  │  │ PremiumMerch │  │     EAS      │
    │  (ERC-4973) │  │  (ERC-721)   │  │ Integration  │
    └─────────────┘  └──────────────┘  └──────────────┘
         │                   │                 │
         │                   │                 │
    Non-Transfer     Tradable NFT      Attestation
    SBT Token        + Fee Split        Records
```

### Contract Flow

1. **Event Registration**: Organizer registers an event via `MerchManager`
2. **Free SBT Minting**: Attendees receive a free SBT token (proof of attendance)
3. **EAS Attestation**: System creates an on-chain attestation record
4. **Upgrade (Optional)**: User pays to upgrade SBT to Premium NFT
5. **Fee Distribution**: Payment is split between treasury and event organizer
6. **SBT Burn**: Original SBT is burned during upgrade
7. **Premium Mint**: Tradable ERC-721 NFT is minted

---

## 📄 Smart Contracts

### 1. BasicMerch.sol (ERC-4973 SBT)

**Purpose**: Non-transferable proof of attendance token

**Key Functions**:
```solidity
// Mint a new SBT (only whitelisted minters)
function mintSBT(address _to, string memory _tokenURI) external returns (uint256)

// Burn SBT during upgrade (only PremiumMerch contract)
function burnSBT(uint256 _tokenId) external

// Check ownership
function isApprovedOrOwner(address _spender, uint256 _tokenId) public view returns (bool)
```

**Features**:
- Non-transferable tokens
- Whitelisted minter access control
- Can only be burned by PremiumMerch contract

---

### 2. PremiumMerch.sol (ERC-721 Premium NFT)

**Purpose**: Tradable collectible with upgrade logic and monetization

**Key Functions**:
```solidity
// Upgrade SBT to Premium NFT (requires payment)
function upgradeSBT(uint256 _sbtId, address _organizer) external payable

// Set upgrade fee
function setUpgradeFee(uint256 _newFee) external onlyOwner

// Set fee split
function setFeeSplit(uint256 _treasurySplit, uint256 _organizerSplit) external onlyOwner

// Pause/unpause
function pause() external onlyOwner
function unpause() external onlyOwner
```

**Features**:
- ERC-721 standard implementation
- Automatic fee distribution (37.5% / 62.5%)
- Pausable for emergencies
- Upgrade tracking (prevents double upgrades)

---

### 3. EASIntegration.sol

**Purpose**: Ethereum Attestation Service integration for verifiable records

**Key Functions**:
```solidity
// Create attestation
function createAttendanceAttestation(
    bytes32 _eventId,
    address _attendee,
    uint256 _tokenId,
    bool _isPremiumUpgrade
) external returns (bytes32)

// Get user attestations
function getUserAttestations(address _user) external view returns (bytes32[] memory)

// Check event attendance
function hasUserAttendedEvent(address _user, bytes32 _eventId) external view returns (bool)
```

**Attestation Schema**:
```solidity
struct AttendanceAttestation {
    bytes32 eventId;        // Event identifier
    uint64 timestamp;       // When attendance occurred
    bool isPremiumUpgrade;  // Basic or premium
    address attendee;       // Who attended
    uint256 tokenId;        // Associated token
}
```

---

### 4. MerchManager.sol

**Purpose**: Main orchestrator integrating all contracts

**Key Functions**:
```solidity
// Register event
function registerEvent(bytes32 _eventId, string memory _metadata) external onlyOwner

// Mint SBT with automatic attestation
function mintSBTWithAttestation(
    address _to,
    string memory _tokenURI,
    bytes32 _eventId
) external returns (uint256, bytes32)

// Upgrade with automatic attestation
function upgradeSBTWithAttestation(
    uint256 _sbtId,
    address _organizer,
    bytes32 _eventId
) external payable returns (uint256, bytes32)

// Query functions
function getUserAttendanceHistory(address _user) external view returns (bytes32[] memory)
function hasUserAttendedEvent(address _user, bytes32 _eventId) external view returns (bool)
```

---

## 🚀 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)
- [Node.js](https://nodejs.org/) (for frontend integration)

### Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd merch-contracts

# Install dependencies
forge install

# Copy environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

### Environment Variables

Create a `.env` file with:

```bash
# Deployment wallet private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# BaseScan API key for contract verification
BASESCAN_API_KEY=your_basescan_api_key_here

# RPC URL
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Optional: Custom treasury address
TREASURY_ADDRESS=0x...

# Optional: EAS Registry address
EAS_REGISTRY_ADDRESS=0x...
```

---

## 🛠️ Development

### Compile Contracts

```bash
# Clean previous builds
forge clean

# Compile all contracts
forge build

# Compile with specific solc version
forge build --use 0.8.20
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run with detailed traces
forge test -vvvv

# Run specific test file
forge test --match-path test/BasicMerch.t.sol

# Run specific test function
forge test --match-test testMintSuccess

# Gas report
forge test --gas-report
```

### Test Coverage

```bash
# Generate coverage report
forge coverage

# Generate detailed coverage report
forge coverage --report debug
```

### Local Development

```bash
# Start local node
anvil

# Deploy to local node (in another terminal)
forge script script/DeployMerchMVP.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

---

## 🚢 Deployment

### Deploy to Base Sepolia

```bash
# Load environment variables
source .env

# Dry run (simulation)
forge script script/DeployMerchMVP.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  -vvvv

# Deploy and verify
forge script script/DeployMerchMVP.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Verify Contracts Manually

```bash
# Get verification commands with correct addresses
forge script script/VerifyContracts.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  -vvvv

# Or use the bash script
chmod +x verify-contracts.sh
./verify-contracts.sh
```

### Deployment Artifacts

After deployment, addresses are saved to:
- `deployments/base-sepolia.json` - Contract addresses
- `broadcast/DeployMerchMVP.s.sol/84532/run-latest.json` - Full deployment data

---

## 🧪 Testing the Flow

### 1. Register an Event

```bash
cast send <MERCH_MANAGER_ADDRESS> \
  "registerEvent(bytes32,string)" \
  $(cast keccak "MyEvent2025") \
  "My Event 2025 - Description" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Mint a Free SBT

```bash
cast send <MERCH_MANAGER_ADDRESS> \
  "mintSBTWithAttestation(address,string,bytes32)" \
  <USER_ADDRESS> \
  "ipfs://QmYourMetadataHash" \
  $(cast keccak "MyEvent2025") \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Check Token Ownership

```bash
# Get owner of token 0
cast call <BASIC_MERCH_ADDRESS> \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Get total token count
cast call <BASIC_MERCH_ADDRESS> \
  "getCurrentTokenId()(uint256)" \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 4. Upgrade to Premium NFT

```bash
cast send <MERCH_MANAGER_ADDRESS> \
  "upgradeSBTWithAttestation(uint256,address,bytes32)" \
  0 \
  <ORGANIZER_ADDRESS> \
  $(cast keccak "MyEvent2025") \
  --value 0.001ether \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 5. Verify Upgrade

```bash
# Check if SBT was burned (should revert)
cast call <BASIC_MERCH_ADDRESS> \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Check Premium NFT ownership
cast call <PREMIUM_MERCH_ADDRESS> \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 6. Query Attestations

```bash
# Get user's attendance history
cast call <MERCH_MANAGER_ADDRESS> \
  "getUserAttendanceHistory(address)(bytes32[])" \
  <USER_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Check if user attended specific event
cast call <MERCH_MANAGER_ADDRESS> \
  "hasUserAttendedEvent(address,bytes32)(bool)" \
  <USER_ADDRESS> \
  $(cast keccak "MyEvent2025") \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

---

## 🌐 Frontend Integration

### Using ethers.js v6

#### Setup

```bash
npm install ethers
```

#### Contract ABIs

```javascript
import { ethers } from 'ethers';

// Contract addresses (from deployments/base-sepolia.json)
const ADDRESSES = {
  basicMerch: '0xaF7B67b88128820Fae205A07aDC055ed509Bdb12',
  premiumMerch: '0x71E3a04c9Ecc624656334756f70dAAA1fc4F985D',
  easIntegration: '0xfD0b399898efC0186E32eb81B630d7Cf7Bb6f217',
  merchManager: '0x648B7FfD8a5Dd9C901B6569E7a0DC9A2eAF4c9F1'
};

// ABI snippets (import full ABIs from your artifacts)
const MERCH_MANAGER_ABI = [
  "function registerEvent(bytes32 eventId, string memory metadata) external",
  "function mintSBTWithAttestation(address to, string memory tokenURI, bytes32 eventId) external returns (uint256, bytes32)",
  "function upgradeSBTWithAttestation(uint256 sbtId, address organizer, bytes32 eventId) external payable returns (uint256, bytes32)",
  "function getUserAttendanceHistory(address user) external view returns (bytes32[] memory)",
  "function hasUserAttendedEvent(address user, bytes32 eventId) external view returns (bool)"
];

const BASIC_MERCH_ABI = [
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function tokenURI(uint256 tokenId) external view returns (string memory)"
];

const PREMIUM_MERCH_ABI = [
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function tokenURI(uint256 tokenId) external view returns (string memory)",
  "function upgradeFee() external view returns (uint256)"
];
```

#### Connect to Contracts

```javascript
// Initialize provider
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// Connect to contracts
const merchManager = new ethers.Contract(
  ADDRESSES.merchManager,
  MERCH_MANAGER_ABI,
  signer
);

const basicMerch = new ethers.Contract(
  ADDRESSES.basicMerch,
  BASIC_MERCH_ABI,
  provider
);

const premiumMerch = new ethers.Contract(
  ADDRESSES.premiumMerch,
  PREMIUM_MERCH_ABI,
  provider
);
```

#### Register Event (Owner Only)

```javascript
async function registerEvent(eventName, eventDescription) {
  try {
    // Generate event ID from name
    const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
    
    const tx = await merchManager.registerEvent(
      eventId,
      eventDescription
    );
    
    await tx.wait();
    console.log('Event registered:', tx.hash);
    return { success: true, txHash: tx.hash };
  } catch (error) {
    console.error('Error registering event:', error);
    return { success: false, error: error.message };
  }
}

// Usage
await registerEvent('MyEvent2025', 'My Event 2025 - Building on Base');
```

#### Mint Free SBT

```javascript
async function mintFreeSBT(userAddress, eventName, metadataURI) {
  try {
    const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
    
    const tx = await merchManager.mintSBTWithAttestation(
      userAddress,
      metadataURI,
      eventId
    );
    
    const receipt = await tx.wait();
    
    // Parse events to get token ID
    const event = receipt.logs.find(
      log => log.fragment && log.fragment.name === 'SBTMintedWithAttestation'
    );
    
    console.log('SBT minted:', receipt.hash);
    return {
      success: true,
      txHash: receipt.hash,
      tokenId: event?.args?.tokenId
    };
  } catch (error) {
    console.error('Error minting SBT:', error);
    return { success: false, error: error.message };
  }
}

// Usage
await mintFreeSBT(
  '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  'MyEvent2025',
  'ipfs://QmYourMetadata...'
);
```

#### Upgrade to Premium NFT

```javascript
async function upgradeToPremium(sbtTokenId, eventName, organizerAddress) {
  try {
    // Get upgrade fee
    const upgradeFee = await premiumMerch.upgradeFee();
    const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
    
    const tx = await merchManager.upgradeSBTWithAttestation(
      sbtTokenId,
      organizerAddress,
      eventId,
      { value: upgradeFee }
    );
    
    const receipt = await tx.wait();
    
    console.log('Upgraded to Premium:', receipt.hash);
    return {
      success: true,
      txHash: receipt.hash,
      fee: ethers.formatEther(upgradeFee)
    };
  } catch (error) {
    console.error('Error upgrading:', error);
    return { success: false, error: error.message };
  }
}

// Usage
await upgradeToPremium(
  0, // SBT token ID
  'MyEvent2025',
  '0x...' // Organizer address
);
```

#### Check User Attendance

```javascript
async function checkUserAttendance(userAddress, eventName) {
  try {
    const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
    
    const hasAttended = await merchManager.hasUserAttendedEvent(
      userAddress,
      eventId
    );
    
    return hasAttended;
  } catch (error) {
    console.error('Error checking attendance:', error);
    return false;
  }
}

// Usage
const attended = await checkUserAttendance(
  '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  'MyEvent2025'
);
console.log('User attended:', attended);
```

#### Get User's Tokens

```javascript
async function getUserTokens(userAddress) {
  try {
    const [basicBalance, premiumBalance] = await Promise.all([
      basicMerch.balanceOf(userAddress),
      premiumMerch.balanceOf(userAddress)
    ]);
    
    return {
      basicSBTs: Number(basicBalance),
      premiumNFTs: Number(premiumBalance)
    };
  } catch (error) {
    console.error('Error getting tokens:', error);
    return null;
  }
}

// Usage
const tokens = await getUserTokens('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
console.log('User has:', tokens.basicSBTs, 'SBTs and', tokens.premiumNFTs, 'Premium NFTs');
```

---

### Using viem

#### Setup

```bash
npm install viem
```

#### Contract Setup

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { baseSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

// Contract addresses
const ADDRESSES = {
  basicMerch: '0xaF7B67b88128820Fae205A07aDC055ed509Bdb12',
  premiumMerch: '0x71E3a04c9Ecc624656334756f70dAAA1fc4F985D',
  merchManager: '0x648B7FfD8a5Dd9C901B6569E7a0DC9A2eAF4c9F1'
} as const;

// ABIs (same as ethers examples)
const merchManagerABI = [
  {
    name: 'mintSBTWithAttestation',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'tokenURI', type: 'string' },
      { name: 'eventId', type: 'bytes32' }
    ],
    outputs: [
      { name: '', type: 'uint256' },
      { name: '', type: 'bytes32' }
    ]
  },
  // ... other functions
] as const;

// Create clients
const publicClient = createPublicClient({
  chain: baseSepolia,
  transport: http()
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  account,
  chain: baseSepolia,
  transport: http()
});
```

#### Mint Free SBT with viem

```typescript
async function mintFreeSBT(
  userAddress: `0x${string}`,
  eventName: string,
  metadataURI: string
) {
  try {
    // Generate event ID
    const eventId = keccak256(toBytes(eventName));
    
    const hash = await walletClient.writeContract({
      address: ADDRESSES.merchManager,
      abi: merchManagerABI,
      functionName: 'mintSBTWithAttestation',
      args: [userAddress, metadataURI, eventId]
    });
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    return {
      success: true,
      txHash: hash,
      receipt
    };
  } catch (error) {
    console.error('Error minting SBT:', error);
    return { success: false, error };
  }
}
```

#### Upgrade to Premium with viem

```typescript
async function upgradeToPremium(
  sbtTokenId: bigint,
  eventName: string,
  organizerAddress: `0x${string}`
) {
  try {
    // Get upgrade fee
    const upgradeFee = await publicClient.readContract({
      address: ADDRESSES.premiumMerch,
      abi: premiumMerchABI,
      functionName: 'upgradeFee'
    });
    
    const eventId = keccak256(toBytes(eventName));
    
    const hash = await walletClient.writeContract({
      address: ADDRESSES.merchManager,
      abi: merchManagerABI,
      functionName: 'upgradeSBTWithAttestation',
      args: [sbtTokenId, organizerAddress, eventId],
      value: upgradeFee
    });
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    
    return {
      success: true,
      txHash: hash,
      fee: formatEther(upgradeFee)
    };
  } catch (error) {
    console.error('Error upgrading:', error);
    return { success: false, error };
  }
}
```

#### Listen to Events with viem

```typescript
// Watch for SBT mints
publicClient.watchContractEvent({
  address: ADDRESSES.merchManager,
  abi: merchManagerABI,
  eventName: 'SBTMintedWithAttestation',
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('SBT Minted:', {
        user: log.args.user,
        tokenId: log.args.tokenId,
        eventId: log.args.eventId
      });
    });
  }
});

// Watch for upgrades
publicClient.watchContractEvent({
  address: ADDRESSES.merchManager,
  abi: merchManagerABI,
  eventName: 'SBTUpgradedWithAttestation',
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log('SBT Upgraded:', {
        user: log.args.user,
        sbtId: log.args.sbtId,
        premiumId: log.args.premiumId
      });
    });
  }
});
```

---

## 📍 Contract Addresses

### Base Sepolia Testnet

| Contract | Address |
|----------|---------|
| **BasicMerch** | [`0xaF7B67b88128820Fae205A07aDC055ed509Bdb12`](https://sepolia.basescan.org/address/0xaF7B67b88128820Fae205A07aDC055ed509Bdb12) |
| **PremiumMerch** | [`0x71E3a04c9Ecc624656334756f70dAAA1fc4F985D`](https://sepolia.basescan.org/address/0x71E3a04c9Ecc624656334756f70dAAA1fc4F985D) |
| **EASIntegration** | [`0xfD0b399898efC0186E32eb81B630d7Cf7Bb6f217`](https://sepolia.basescan.org/address/0xfD0b399898efC0186E32eb81B630d7Cf7Bb6f217) |
| **MerchManager** | [`0x648B7FfD8a5Dd9C901B6569E7a0DC9A2eAF4c9F1`](https://sepolia.basescan.org/address/0x648B7FfD8a5Dd9C901B6569E7a0DC9A2eAF4c9F1) |

**Network**: Base Sepolia  
**Chain ID**: 84532  
**RPC URL**: https://sepolia.base.org  
**Explorer**: https://sepolia.basescan.org  

---

## 🔒 Security

### Access Control

- **BasicMerch**: Only whitelisted addresses can mint SBTs
- **PremiumMerch**: Only BasicMerch contract can burn SBTs
- **MerchManager**: Owner-only functions for event registration
- **EASIntegration**: Owner-controlled attestation creation

### Best Practices

- All external calls are protected with `nonReentrant` modifier
- Pausable mechanism for emergency stops
- Fee validation before processing upgrades
- Double-upgrade prevention
- Input validation on all functions

### Audit Status

⚠️ **This code has not been audited.** Use at your own risk on testnet only.

For production deployment:
1. Get a professional security audit
2. Implement timelocks for admin functions
3. Use multi-sig for ownership
4. Set up monitoring and alerting
5. Consider bug bounty program

---

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Base Documentation](https://docs.base.org/)
- [ERC-4973 Specification](https://eips.ethereum.org/EIPS/eip-4973)
- [Ethereum Attestation Service](https://attest.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

Built with ❤️ for Base Bootcamp

---

## 🐛 Known Issues

- [ ] EAS integration uses mock registry for MVP
- [ ] No metadata standard enforcement
- [ ] Limited error messages for end users
- [ ] No batch minting functionality

---

## 🗺️ Roadmap

- [ ] Implement real EAS integration
- [ ] Add metadata validation
- [ ] Create frontend dApp
- [ ] Deploy to Base Mainnet
- [ ] Add batch operations
- [ ] Implement upgradeable proxy pattern
- [ ] Add more comprehensive events
- [ ] Create SDK for easy integration

---

**Happy Building! 🚀**
