# **Project: Merch MVP Smart Contract Specification**

This specification details the design and core functions of the smart contracts**.

## **1\. Events**
| Standard | Simple Storage (Basic On-Chain Struct) |
| :---- | :---- |
| **Purpose** | **Stores BASIC EVENT METADATA** relevant for contract integrations (identification, minimal off-chain lookup key). Intended to be minimal—no full event details are on-chain. | 
| **Struct event data (eventMetadata)** | **eventId (uint256)**: Unique event identifier. <br> , **imageURI (string):** image of the standard merch for the event. <br> **isActive (bool)**: Whether the event is currently active/enabled. <br> **organizer (address):** The wallet address of the organizer (who creates the event) **eventMetadataURI (string)**: Pointer to the off-chain event metadata. |
| **Key data fiedls:** | **events (eventMetadata[]):** The list of the events.
| **Core Functions** | **createEvent(string memory eventMetadataURI):** Registers a new event, returns eventId.<br> **setEventStatus(uint256 eventId, bool isActive):** Enables/disables minting or activity for an event.<br> **getEvent(uint256 eventId):** Returns the on-chain event struct, including the offchain reference for metadata lookup. |
| **Access Control** | Any wallet can create the events but only the wallet that create the event can modify it. |

## **2\. Attestation**

| Standard | Minimal On-Chain Attestation / ERC-4973-Inspired SBT |
| :---- | :---- |
| **Purpose** | **Records on-chain attestations of unique event attendance for a wallet.** Represents non-transferable, permanent proof of attendance for a specific event. Enables further interactions (such as upgrades to Premium Merch). |
| **Key Data Fields** | **attestationId (uint256):** Unique ID for each attestation. <br> **eventId (uint256):** References the event this attestation is for. <br> **attendee (address):** The wallet address being attested. <br> **issuedAt (uint256):** Timestamp of attestation mint. <br> **attestationMetadataURI (string):** Optional pointer to offchain data for further proof/context. <br> **tokens (uint256[]):**  ids for the merch tokens associated, <br> **featuredToken(uint256):** Token that is main token for the proof of attendance attestation |
| **Core Functions** | **attest(address attendee, uint256 eventId, string memory claimCode, string memory attestationMetadataURI):** Organizer-only. Mints a new, non-transferable attestation to the attendee for a specific event. <br> **getAttestations(address attendee):** Returns all attestation IDs owned by a specific address. <br> **getAttestation(uint256 attestationId):** Returns full struct of the attestation.<br> **attestationExists(address attendee, uint256 eventId):** Checks if the wallet already has an attestation for event. |
| **Logic** | * Event's claim code white list minting. <br>* Prevents duplicate attestations per wallet per event. <br>* Prevents duplicate attestations per claim code per event. <br>* Attestations are non-transferable. <br>* Follows SBT logic: cannot be transferred, traded, or approved. |
| **Access Control** | An claim code list will generated in the offchain backend to control who can mint (attest) the proof of attendance for each event. Attestations can never be transferred (soulbound). |

**Key Notes:**
- **attest** enforces one-per-wallet-per-event.
- No transfer/approval functions.
- Designed to integrate with Merch/NFT 'upgrades' in later contracts.


## **3\. Merch Contract (Merch.sol)**

| Standard | ERC-4973 (Soulbound Token \- SBT) |
| :---- | :---- |
| **Purpose** | **PERMANENT, VISIBLE PROOF OF ATTENDANCE (POA).** Non-transferable token. |
| **Key Functions** | **mint(address \_to, uint256 \_eventId):** getByEvent(address \_owner, uint256 \_eventId): Lookup the SBT ID for a given user/event. |
| **Access Control** | This function mus be called by the Attestation contract to mint standard merch token for the event using the default merch image associated to the event.* |

## **4\. Premium Merch Contract (PremiumMerch.sol)**

| Standard | ERC-721 (Transferable NFT) |
| :---- | :---- |
| **Purpose** | Tradable, high-value digital collectible (the NFT 'upgrade' asset and revenue source). |
| **Key Functions** | **upgrade(uint256 \_attestationId, string memory \_tokenID): CRITICAL MONETIZATION FUNCTION.** |
| **Logic** | 1\. **VERIFIES OWNERSHIP** of \_attestationId of the Proof Of Attendance (caller must own the attestation for this event). 2\. Accepts a payment (msg.value in test ETH).  3\. Use the token ID of the ERC-721 to transfer ownership to the user. 4\. Transfers the payment to the original owner of the Preimum Merch Token, the organizer share to the Organizer and the Protocol share to the Protocol Treasury. |
| **Access Control** | The upgrade function must ensure the caller owns the prerequisite \_attestationId before proceeding. The Treasury address must be configurable in other contract. |

## **5. System Global Configuration**

The Merch system requires a global configuration structure to support flexibility, security, and upgradability across all smart contracts in the system. This section defines the specification for shared configuration parameters.

| Standard      | Ownable, Upgradeable Storage or Registry Pattern |
|---------------|--------------------------------------------------|
| **Purpose**   | Provides global addresses, parameters, and protocol-level constants that are referenced by all core contracts (attestation, merch, and premium merch). Enables coordinated upgrades and governance. |
| **Key Data Fields** | **protocolTreasury (address):** The address where protocol fees are sent.<br> **defaultOrganizerShare (uint16):** Default basis points (parts per 10,000) for organizer revenue share.<br> **defaultProtocolShare (uint16):** Default basis points for protocol revenue share.<br> **backendIssuer (address):** Address authorized for validate claim codes<br> **upgradeContract (address):** Address of the current Premium Merch contract (for cross-contract calls/upgrades).<br> **attestationContract (address):** Address of the current Attestation contract.<br> **merchContract (address):** Address of the current Merch (SBT) contract.<br> **admin (address):** Owner (admin) of the config contract, with permission to update key values. |
| **Core Functions** | <ul><li>**setProtocolTreasury(address newTreasury):** Only admin. Updates protocol treasury address.</li><li>**setShares(uint16 newOrganizerShare, uint16 newProtocolShare):** Only admin. Updates default revenue shares.</li><li>**setBackendIssuer(address newIssuer):** Only admin. Updates trusted signature verifier.</li><li>**setContractAddresses(address attestation, address merch, address upgrade):** Only admin. Updates core contract addresses.</li><li>**transferAdmin(address newAdmin):** Only admin. Transfers ownership of the config contract.</li><li>**getters:** Functions to read all config fields. All contracts read from global config for up-to-date values.</li></ul> |
| **Logic** | <ul><li>All state-changing functions are restricted to the current admin address.</li><li>Core contracts reference config fields on-demand to ensure dynamic updates apply immediately system-wide.</li><li>Upgradeable/proxy deployment pattern is recommended for long-term protocol sustainability.</li></ul> |
| **Access Control** | Only the current `admin` can update configuration values. All functions that change state must be restricted accordingly. |

**Implementation Note:** Configuration can be implemented as a single `Config.sol` contract, referenced by other contracts (either passed in via constructor/setter, or via hardcoded address for minimum gas). The config contract should be upgradeable (via proxy or setter functions) and support ownership transfer.

**Examples of Usage:**
- Merch (SBT) contract checks `config.backendIssuer()` for signature verification.
- Premium Merch contract queries `config.protocolTreasury()` to route protocol fee.
- Attestation contract may check config for current protocol addresses for safe cross-contract calls.
- Shares percentages can be updated by protocol governance without redeploying child contracts.





