# **Project: Merch MVP Testing Strategy**

This strategy focuses on validating the **low-friction UX** and the **monetization conversion loop** on the Base Sepolia testnet, ensuring the Basic Merch SBT is **retained** after upgrade.

## **1\. Smart Contract Testing (Hardhat/Foundry)**

| Test Area | Key Scenario | Pass Condition |
| :---- | :---- | :---- |
| **SBT Minting** | Standard minting of BasicMerch to a wallet. | SBT is minted; the transaction requires and consumes a minimal gas fee. |
| **Premium Companion Mint** | Wallet calls PremiumMerch.mintCompanion() with sufficient ETH and a valid SBT ID. | **SBT IS RETAINED** in the user's wallet; ERC-721 is minted; fee is split correctly. |
| **Access Control** | Attempt to mint Premium Merch without owning the corresponding Basic SBT. | Transaction is reverted with a custom error message. |
| **Fee Calculation** | Test upgrade payment with edge cases (slightly overpaid/underpaid). | Underpaid reverts; Overpaid succeeds, excess is returned to the user or treasury as defined. |

## **2\. Backend/API Testing**

| Test Area | Key Scenario | Pass Condition |
| :---- | :---- | :---- |
| **Verification** | POST /verify-code with a used/expired code. | Returns HTTP 400 with status code CLAIM\_INVALID. |
| **Off-Chain Reserve (Happy Path)** | POST /claim-offchain with valid code and email. | Returns HTTP 200 with reservationId; DB reflects reserved status. |
| **Redemption Update** | Minting the SBT after a reservation should mark the DB record as "CLAIMED." | Backend logic confirms SBT mint and updates off-chain status. |
| **EAS Attestation** | POST /attest-claim with a verified txHash for a Premium Mint. | Backend successfully issues EAS attestation with isPremium=true and sbtTokenId recorded. |
| **Security** | POST request to any endpoint without the X-API-KEY header. | Returns HTTP 401 (Unauthorized). |

## **3\. Frontend/UX Integration Testing**

| Test Area | Key Scenario | Pass Condition |
| :---- | :---- | :---- |
| **Off-Chain Reservation UX** | New user reserves claim using an email address. | UI shows success message, prompting user to check email/return later. No wallet connection required. |
| **Redemption Flow** | User returns, connects wallet, and mints a previously reserved claim. | Mini-App pulls reservation data from DB/Backend and mints SBT to the connected wallet, consuming the reservation and requiring gas. |
| **Dual Asset Display** | User successfully claims both the Basic SBT and the Premium ERC-721. | **Both tokens are visible** in the collection view, with clear labeling (POA vs. Tradable). |
| **Conversion Flow** | User successfully completes the Premium Mint transaction. | The Basic NFT **REMAINS VISIBLE** in the wallet; the new Premium NFT appears. |
| **Wallet Interaction** | User attempts both SBT mint and ERC-721 upgrade with an empty wallet balance. | Both transactions correctly prompt the user's wallet for funds and fail if the wallet is empty. |

