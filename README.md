# Merch MVP - Soul Bound Token & Premium NFT System

[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-61%2F61%20Passing-success)](https://github.com)

A complete system for event attendance proof using Soul Bound Tokens (SBT) with the ability to upgrade to tradable Premium NFTs. Built and deployed on Base Sepolia testnet.

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

1. **Free Tier (SBT)**: Non-transferable proof of attendance token (ERC-4973-like)
2. **Paid Tier (Premium NFT)**: Tradable collectible NFT (ERC-721) with monetization

### Key Features

- ✅ Soul Bound Tokens for free attendance proof
- ✅ Upgrade mechanism to Premium NFTs via MerchManager
- ✅ Automatic fee distribution (37.5% platform / 62.5% organizer)
- ✅ Ethereum Attestation Service (EAS) integration
- ✅ Pausable and upgradeable architecture
- ✅ Gas optimized with unchecked increments
- ✅ Excess payment refund mechanism
- ✅ Batch operations support
- ✅ Built with OpenZeppelin v5 contracts
- ✅ Comprehensive test coverage (61/61 tests passing)

---

## 🗂️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       MerchManager                          │
│                  (Main Orchestrator)                        │
│  • Register Events                                          │
│  • Mint SBT with Attestation                               │
│  • Upgrade SBT to Premium with Attestation                 │
│  • Batch Operations                                        │
└──────────────┬───────────────┬──────────────┬───────────────┘
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
4. **Upgrade (Optional)**: User pays 0.001 ETH to upgrade SBT to Premium NFT
5. **Fee Distribution**: Payment is split between treasury (37.5%) and event organizer (62.5%)
6. **SBT Burn**: Original SBT is burned during upgrade
7. **Premium Mint**: Tradable ERC-721 NFT is minted to user

> **⚠️ Important**: All upgrades MUST go through `MerchManager.upgradeSBTWithAttestation()`. Direct calls to `PremiumMerch.upgradeSBT()` are not intended for end users.

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
- Non-transferable tokens (ERC-4973-like behavior)
- Whitelisted minter access control
- Can only be burned by PremiumMerch contract
- Uses OpenZeppelin v5 `_update` override for transfer prevention

---

### 2. PremiumMerch.sol (ERC-721 Premium NFT)

**Purpose**: Tradable collectible with upgrade logic and monetization

**Key Functions**:
```solidity
// Upgrade SBT to Premium NFT (requires payment) - Called by MerchManager
function upgradeSBT(uint256 _sbtId, address _organizer, address _upgrader) external payable

// Set upgrade fee
function setUpgradeFee(uint256 _newFee) external onlyOwner

// Set fee split
function setFeeSplit(uint256 _treasurySplit, uint256 _organizerSplit) external onlyOwner

// Check if user can upgrade
function canUpgradeSBT(uint256 _sbtId, address _user) external view returns (bool, string memory)

// Pause/unpause
function pause() external onlyOwner
function unpause() external onlyOwner
```

**Features**:
- ERC-721 standard implementation
- Automatic fee distribution (37.5% treasury / 62.5% organizer)
- Excess payment refund mechanism
- Pausable for emergencies
- Upgrade tracking (prevents double upgrades)
- Emergency withdraw function

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

// Get premium upgrades
function getUserPremiumUpgrades(address _user) external view returns (bytes32[] memory)

// Batch create attestations
function batchCreateAttestations(...) external returns (bytes32[] memory)
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

**Features**:
- Unique attestation IDs using counter + hash
- Gas-optimized queries with unchecked increments
- Batch operations support

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
function canUserUpgradeSBT(uint256 _sbtId, address _user) external view returns (bool, string memory)
function getUpgradeFee() external view returns (uint256)

// Batch operations
function batchRegisterEvents(bytes32[] memory _eventIds, string[] memory _metadataArray) external
```

**Features**:
- Centralized entry point for all operations
- Automatic attestation creation
- Event validation
- Contract address management

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
cp env.example .env

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

# Optional: Custom treasury address (defaults to deployer)
TREASURY_ADDRESS=0x...

# Optional: EAS Registry address (defaults to deployer for MVP)
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
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test
forge test --match-test testCompleteUserJourney

# Gas report
forge test --gas-report

# Coverage report
forge coverage
```

**Test Results**: ✅ 61/61 tests passing

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

### Verify Contracts on BaseScan

```bash
# Option 1: Use the script to get verification commands
forge script script/VerifyContracts.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Option 2: Use the bash script for automatic verification
chmod +x verify-all.sh
./verify-all.sh
```

### Deployment Artifacts

After deployment, addresses are saved to:
- `deployments/base-sepolia.json` - Contract addresses and configuration
- `broadcast/DeployMerchMVP.s.sol/84532/run-latest.json` - Full deployment data

---

## 🧪 Testing the Flow

Replace `<ADDRESSES>` with actual deployed addresses from `deployments/base-sepolia.json`.

### 1. Register an Event

```bash
cast send 0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2 \
  "registerEvent(bytes32,string)" \
  $(cast keccak "MyEvent2025") \
  "My Event 2025 - Description" \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Mint a Free SBT

```bash
cast send 0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2 \
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
cast call 0x51FEb9273B01d96C3cff5Ded91521248AaAc587B \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Get balance
cast call 0x51FEb9273B01d96C3cff5Ded91521248AaAc587B \
  "balanceOf(address)" <USER_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 4. Upgrade to Premium NFT

```bash
cast send 0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2 \
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
cast call 0x51FEb9273B01d96C3cff5Ded91521248AaAc587B \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Check Premium NFT ownership
cast call 0xa3A7C33C21c6B347B220B174928609A7Ae74BD10 \
  "ownerOf(uint256)" 0 \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 6. Query Attestations

```bash
# Get user's attendance history
cast call 0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2 \
  "getUserAttendanceHistory(address)(bytes32[])" \
  <USER_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC_URL

# Check if user attended specific event
cast call 0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2 \
  "hasUserAttendedEvent(address,bytes32)(bool)" \
  <USER_ADDRESS> \
  $(cast keccak "MyEvent2025") \
  --rpc-url $BASE_SEPOLIA_RPC_URL
```

---

## 🌐 Frontend Integration

### Contract Addresses (Base Sepolia)

```javascript
const ADDRESSES = {
  basicMerch: '0x51FEb9273B01d96C3cff5Ded91521248AaAc587B',
  premiumMerch: '0xa3A7C33C21c6B347B220B174928609A7Ae74BD10',
  easIntegration: '0xBF4AD57ec927016ca5beBc9F23ba4162871B018D',
  merchManager: '0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2'
};

const CHAIN_ID = 84532; // Base Sepolia
const UPGRADE_FEE = '0.001'; // ETH
```

### Using ethers.js v6

```bash
npm install ethers
```

#### Setup

```javascript
import { ethers } from 'ethers';

// Initialize provider
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// ABI (minimal example - import full ABIs from artifacts)
const MERCH_MANAGER_ABI = [
  "function registerEvent(bytes32 eventId, string memory metadata) external",
  "function mintSBTWithAttestation(address to, string memory tokenURI, bytes32 eventId) external returns (uint256, bytes32)",
  "function upgradeSBTWithAttestation(uint256 sbtId, address organizer, bytes32 eventId) external payable returns (uint256, bytes32)",
  "function getUserAttendanceHistory(address user) external view returns (bytes32[] memory)",
  "function hasUserAttendedEvent(address user, bytes32 eventId) external view returns (bool)",
  "function getUpgradeFee() external view returns (uint256)"
];

// Connect to contract
const merchManager = new ethers.Contract(
  ADDRESSES.merchManager,
  MERCH_MANAGER_ABI,
  signer
);
```

#### Register Event

```javascript
async function registerEvent(eventName, eventDescription) {
  const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
  const tx = await merchManager.registerEvent(eventId, eventDescription);
  await tx.wait();
  return tx.hash;
}
```

#### Mint Free SBT

```javascript
async function mintFreeSBT(userAddress, eventName, metadataURI) {
  const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
  const tx = await merchManager.mintSBTWithAttestation(
    userAddress,
    metadataURI,
    eventId
  );
  const receipt = await tx.wait();
  return receipt.hash;
}
```

#### Upgrade to Premium

```javascript
async function upgradeToPremium(sbtTokenId, eventName, organizerAddress) {
  const upgradeFee = await merchManager.getUpgradeFee();
  const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
  
  const tx = await merchManager.upgradeSBTWithAttestation(
    sbtTokenId,
    organizerAddress,
    eventId,
    { value: upgradeFee }
  );
  
  const receipt = await tx.wait();
  return {
    txHash: receipt.hash,
    fee: ethers.formatEther(upgradeFee)
  };
}
```

#### Check Attendance

```javascript
async function checkAttendance(userAddress, eventName) {
  const eventId = ethers.keccak256(ethers.toUtf8Bytes(eventName));
  return await merchManager.hasUserAttendedEvent(userAddress, eventId);
}
```

---

## 📍 Contract Addresses

### Base Sepolia Testnet (Deployed & Verified)

| Contract | Address | Explorer |
|----------|---------|----------|
| **BasicMerch** | `0x51FEb9273B01d96C3cff5Ded91521248AaAc587B` | [View](https://sepolia.basescan.org/address/0x51FEb9273B01d96C3cff5Ded91521248AaAc587B#code) |
| **PremiumMerch** | `0xa3A7C33C21c6B347B220B174928609A7Ae74BD10` | [View](https://sepolia.basescan.org/address/0xa3A7C33C21c6B347B220B174928609A7Ae74BD10#code) |
| **EASIntegration** | `0xBF4AD57ec927016ca5beBc9F23ba4162871B018D` | [View](https://sepolia.basescan.org/address/0xBF4AD57ec927016ca5beBc9F23ba4162871B018D#code) |
| **MerchManager** | `0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2` | [View](https://sepolia.basescan.org/address/0x3ddaEe7C8f655c46FB5827eBb8D21EE7194216a2#code) |

**Configuration:**
- **Upgrade Fee**: 0.001 ETH
- **Fee Split**: 37.5% Treasury / 62.5% Organizer
- **Network**: Base Sepolia (Chain ID: 84532)
- **RPC**: https://sepolia.base.org
- **Explorer**: https://sepolia.basescan.org

---

## 🔒 Security

### Access Control

- **BasicMerch**: Only whitelisted addresses (MerchManager) can mint SBTs
- **PremiumMerch**: Only BasicMerch contract can burn SBTs; requires payment for upgrades
- **MerchManager**: Owner-only functions for event registration and minting
- **EASIntegration**: Owner (MerchManager) controlled attestation creation

### Security Features

- ✅ ReentrancyGuard on all state-changing functions
- ✅ Pausable mechanism for emergency stops
- ✅ Fee validation before processing upgrades
- ✅ Double-upgrade prevention via mapping
- ✅ Input validation on all functions
- ✅ Excess payment refund mechanism
- ✅ Custom errors for gas efficiency
- ✅ Centralized upgrade flow through MerchManager

### Best Practices Implemented

- OpenZeppelin v5 battle-tested contracts
- Events emitted for all state changes
- Checks-Effects-Interactions pattern
- Gas optimizations (unchecked increments, packed storage)
- Comprehensive test coverage (61/61 tests)

### Audit Status

⚠️ **This code has not been audited.** Currently deployed on testnet only.

**For production deployment:**
1. Get a professional security audit
2. Implement timelocks for admin functions
3. Use multi-sig for ownership
4. Set up monitoring and alerting
5. Consider bug bounty program
6. Add more granular access control

---

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Base Documentation](https://docs.base.org/)
- [ERC-4973 Specification](https://eips.ethereum.org/EIPS/eip-4973)
- [Ethereum Attestation Service](https://attest.sh/)
- [OpenZeppelin Contracts v5](https://docs.openzeppelin.com/contracts/5.x/)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 💡 Known Issues & Future Improvements

### Current Limitations
- EAS integration uses mock registry for MVP (not production EAS)
- No metadata standard enforcement
- No batch minting for SBTs
- Treasury and organizer addresses cannot be contracts without fallback

### Roadmap
- [ ] Integrate with production EAS on Base
- [ ] Add ERC-721 metadata standard enforcement
- [ ] Implement batch minting operations
- [ ] Create frontend dApp
- [ ] Deploy to Base Mainnet
- [ ] Implement upgradeable proxy pattern
- [ ] Add IPFS pinning service integration
- [ ] Create SDK for easy integration
- [ ] Support for multiple currencies (USDC, etc.)

---

## 🎉 Acknowledgments

Built with ❤️ for **Base Bootcamp**

**Contributors:**
- Smart Contract Development
- Testing & Security
- Documentation

---

**Happy Building! 🚀**

For support or questions, please open an issue on GitHub.
