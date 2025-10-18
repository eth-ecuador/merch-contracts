# **Merch MVP: Smart Contract Specification**

This document details the essential logic and public interfaces for the two core token contracts and the Ethereum Attestation Service (EAS) implementation for the MVP deployed on Base Sepolia.

### **1\. ERC-4973: Basic Merch SBT Contract (BasicMerch.sol)**

This contract handles the non-transferable proof of attendance (Free Tier).

| Function | Type | Description | Access Control |
| :---- | :---- | :---- | :---- |
| mintSBT(address \_to, string memory \_tokenURI) | External | **Sponsored Function.** Mints a new SBT to \_to. This is the zero-cost entry point for the user. | Only callable by a whitelisted address (e.g., the Backend API/Minter Role). |
| burnSBT(uint256 \_tokenId) | External | **Core Logic.** Allows the Premium NFT contract to burn the SBT during the upgrade process. | Only callable by the PremiumMerch.sol contract address. |
| isApprovedOrOwner(address \_spender, uint256 \_tokenId) | Public/View | Required for the ERC-721 contract to perform the burn on the user's behalf. | Any caller. |

### **2\. ERC-721: Premium Merch NFT Contract (PremiumMerch.sol)**

This contract handles the tradable collectible, monetization, and upgrade logic (Paid Tier).

| Function | Type | Description | Access Control |
| :---- | :---- | :---- | :---- |
| upgradeSBT(uint256 \_sbtId, address \_organizer) | **Payable External** | **Monetization Logic.** The core function to upgrade a Basic Merch SBT to a Premium ERC-721. Requires a specific amount of test ETH/USDC sent with the transaction. | Any user holding a valid SBT. |
| **Upgrade Logic (Internal)** | Internal (in upgradeSBT) | **1\. Fee Check:** Confirms msg.value meets the required test upgrade fee. **2\. Burn SBT:** Calls BasicMerch.burnSBT(\_sbtId). **3\. Fee Split:** Distributes msg.value to the mock Treasury and the \_organizer address based on the predefined split (e.g., 37.5% / 62.5%). **4\. Mint ERC-721:** Mints a new ERC-721 to msg.sender. | N/A |
| setBaseURI(string memory \_uri) | Only Owner | Sets the base URI for the collectible metadata. | Contract Owner. |

### **3\. Ethereum Attestation Service (EAS)**

| Element | Specification | Purpose |
| :---- | :---- | :---- |
| **Attestation Schema** | bytes32 event\_id, uint64 timestamp, bool is\_premium\_upgrade | Data structure to prove *what* was attended and *when*, with a flag to denote the upgrade status. |
| **Issuance Points** | Executed in two places: | 1\. **After BasicMerch.mintSBT():** Records the foundational attendance proof (is\_premium\_upgrade \= false). 2\. **After PremiumMerch.upgradeSBT():** Records the upgrade action (is\_premium\_upgrade \= true). |

