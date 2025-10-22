# Merch MVP - Soul Bound Token & Premium NFT System

[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-56%2F56%20Passing-success)](https://github.com)

A complete system for event attendance proof using Soul Bound Tokens (SBT) with the ability to upgrade to tradable Premium NFTs. Built and deployed on Base Sepolia testnet with **signature-based public minting** for maximum scalability.

## 🔄 Recent Updates - Option B

### Signature-Based Public Minting

The system now supports **public minting** with backend-issued signatures for maximum scalability.

**Previous Flow (❌):** Backend pays gas → Expensive at scale  
**New Flow (✅):** Backend signs (free) → User pays gas → Zero backend cost

**Benefits:**
- 💰 Zero transaction costs for backend (signatures are free)
- 🚀 Infinitely scalable - no funding needed
- 🔐 Secure - signatures verified on-chain with ecrecover  
- 🌐 Decentralized - users interact directly with contracts

---

## 🗂️ Architecture

```
User requests mint → Backend API verifies claim → Backend signs (free)
         ↓
User calls contract with signature (pays gas) → Signature verified on-chain
         ↓
SBT minted + Attestation created ✅
```

### Contract Addresses (Base Sepolia)

| Contract | Address |
|----------|---------|
| **BasicMerch** | `0x5eEC061B0A4d5d2Be4aCF831DE73E27e39F442fF` |
| **PremiumMerch** | `0xd668020ed16f83B5E0f7E772D843A51972Dd25A9` |
| **EASIntegration** | `0x07446D2465E8390025dda9a53Dd3d43E6BA75eC6` |
| **MerchManager** | `0x900DB725439Cf512c2647d2B1d327dc9d1D85a6C` |

---

## 📄 Key Smart Contract Changes

### BasicMerch.sol
```solidity
// ✅ PUBLIC MINT - Anyone can call with valid backend signature
function mintSBT(
    address _to, 
    uint256 _eventId, 
    string memory _tokenURI, 
    bytes memory _signature  // From backend API
) external returns (uint256)
```

### MerchManager.sol  
```solidity
// ✅ PUBLIC - No onlyOwner restriction
function mintSBTWithAttestation(
    address _to,
    string memory _tokenURI,
    bytes32 _eventId,
    bytes memory _signature  // From backend API
) external returns (uint256, bytes32)
```

---

## 🌐 Frontend Integration Example

```javascript
import { ethers } from 'ethers';

async function claimMerch(claimCode) {
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  const userAddress = await signer.getAddress();
  
  // 1. Get signature from backend API
  const response = await fetch('https://api.yourbackend.com/verify-code', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: claimCode, walletAddress: userAddress })
  });
  
  const { eventId, tokenURI, signature } = await response.json();
  
  // 2. User calls contract with signature (pays gas)
  const merchManager = new ethers.Contract(
    '0x900DB725439Cf512c2647d2B1d327dc9d1D85a6C',
    ['function mintSBTWithAttestation(address,string,bytes32,bytes) external returns (uint256,bytes32)'],
    signer
  );
  
  const tx = await merchManager.mintSBTWithAttestation(
    userAddress, tokenURI, eventId, signature
  );
  
  await tx.wait();
  return tx.hash;
}
```

---

## 🖥️ Backend API Example

```javascript
const express = require('express');
const { ethers } = require('ethers');

const app = express();
const backendWallet = new ethers.Wallet(process.env.BACKEND_ISSUER_PRIVATE_KEY);

app.post('/verify-code', async (req, res) => {
  const { code, walletAddress } = req.body;
  
  // Verify claim code
  const claim = await db.getClaim(code);
  if (!claim || claim.used) {
    return res.status(400).json({ error: 'Invalid code' });
  }
  
  // Mark as used
  await db.markAsUsed(code);
  
  // Generate signature (FREE - no transaction)
  const messageHash = ethers.solidityPackedKeccak256(
    ['address', 'uint256', 'string'],
    [walletAddress, claim.eventId, claim.tokenURI]
  );
  
  const signature = await backendWallet.signMessage(ethers.getBytes(messageHash));
  
  res.json({ eventId: claim.eventId, tokenURI: claim.tokenURI, signature });
});

app.listen(3000);
```

---

## 🚀 Quick Start

```bash
# Install
forge install

# Configure .env
cp env.example .env
nano .env

# Deploy
forge script script/DeployMerchMVP.s.sol:DeployMerchMVP \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Run tests
forge test
```

---

## 📊 Cost Comparison

| Metric | Old Model | New Model (Option B) |
|--------|-----------|---------------------|
| Backend cost per mint | ~$0.02 | **$0** |
| Cost for 1000 users | $20 | **$0** |
| User pays gas | No | Yes (~$0.20 on Base) |
| Scalability | Limited | ✅ Infinite |

---

## 🔐 Security

- ✅ ECDSA signature verification with ecrecover
- ✅ EIP-191 standard for message signing
- ✅ Backend issuer wallet requires no ETH (only signs)
- ✅ ReentrancyGuard on all functions
- ✅ 56/56 tests passing

**Backend Issuer Security:**
- Store private key in secure environment variables
- NEVER commit to Git
- Rotate periodically
- Does NOT need funding

---

## 📚 Documentation

For complete documentation, see:
- Full README (this file)
- [Migration Guide](./docs/MIGRATION_GUIDE.md) - Technical details
- [Backend API Guide](./docs/BACKEND_README.md) - Complete backend setup
- [Deployment Checklist](./docs/DEPLOYMENT_CHECKLIST.md) - Step-by-step guide

---

## 📄 License

MIT License

---

**Happy Building! 🚀**

With signature-based minting, your system is ready to scale to millions of users at zero transaction cost.
