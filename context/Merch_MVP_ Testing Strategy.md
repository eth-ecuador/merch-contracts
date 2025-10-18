# **Merch MVP: Testing Strategy**

Testing for the Merch MVP is focused on validating the zero-gas UX and the security of the monetization logic. All tests should be executed on **Base Sepolia**.

### **1\. Smart Contract Unit Tests (Foundry)**

| Test Case | Contract | Objective | Expected Outcome |
| :---- | :---- | :---- | :---- |
| **Mint Success** | BasicMerch (SBT) | Verify the mintSBT function is callable only by the Minter role. | Mint succeeds; token is non-transferable. |
| **SBT Burn Access** | BasicMerch (SBT) | Verify that only the PremiumMerch contract can call burnSBT. | Burn by user/other contract fails; burn by PremiumMerch succeeds. |
| **Upgrade Fee Check** | PremiumMerch (ERC-721) | Test upgradeSBT with insufficient msg.value. | Transaction reverts with insufficient fee error. |
| **Upgrade E2E Logic** | PremiumMerch (ERC-721) | Test successful upgrade execution. | SBT is burned; new ERC-721 is minted to user; **Fee is split correctly** to Treasury/Organizer addresses. |
| **Double Upgrade** | PremiumMerch (ERC-721) | Attempt to upgrade the same SBT twice. | Transaction reverts due to failure to burn the non-existent SBT. |

### **2\. Integration Tests**

These tests validate the interaction between on-chain and off-chain components.

| Test Case | Components | Objective | Expected Outcome |
| :---- | :---- | :---- | :---- |
| **Paymaster Sponsorship** | BasicMerch \+ Paymaster | Verify a mintSBT transaction is executed with the gas cost covered by the Paymaster service. | Transaction succeeds; gas fee paid by the Paymaster (verified on block explorer/CDP dashboard). |
| **EAS Attestation Trigger** | BasicMerch \+ Backend API | Verify the EAS record is created after the SBT mint. | SBT is minted; a corresponding Attestation with the correct schema data is found on EAS Scan. |
| **Monetization Oracle** | Frontend \+ Backend API | Verify the frontend accurately calculates and displays the required ETH/USDC fee. | Frontend accurately calculates required value based on test oracle rates before transaction submission. |

### **3\. End-to-End (E2E) User Flow Tests**

These tests replicate the live Mini-App experience in a staging environment.

| Test Case | Scenario | Focus | Required Verification |
| :---- | :---- | :---- | :---- |
| **E2E Claim (Happy Path)** | User claims Merch with a valid code. | Zero-Gas UX | **No gas prompt shown.** SBT appears in the wallet/Merch Viewer screen. |
| **E2E Upgrade (Happy Path)** | User upgrades their claimed SBT. | Monetization Logic | User is prompted for a transaction and pays the fee. Old SBT vanishes; new ERC-721 appears. |
| **E2E Negative (Invalid Code)** | User attempts to claim with a forged/used code. | Security/Code Verification | Backend API rejects the code; no transaction is submitted. |
| **E2E Insufficient Funds** | User attempts to upgrade without enough ETH/USDC. | Upgrade UX | Wallet prompts with an "Insufficient Funds" error; transaction fails before execution. |

