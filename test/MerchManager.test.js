const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MerchManager", function () {
  let basicMerch;
  let premiumMerch;
  let easIntegration;
  let merchManager;
  let owner;
  let user1;
  let user2;
  let organizer;

  const UPGRADE_FEE = ethers.utils.parseEther("0.01");

  beforeEach(async function () {
    [owner, user1, user2, organizer] = await ethers.getSigners();

    // Deploy BasicMerch
    const BasicMerch = await ethers.getContractFactory("BasicMerch");
    basicMerch = await BasicMerch.deploy("Basic Merch SBT", "BMERCH");
    await basicMerch.deployed();

    // Deploy EASIntegration
    const EASIntegration = await ethers.getContractFactory("EASIntegration");
    easIntegration = await EASIntegration.deploy(ethers.constants.AddressZero);
    await easIntegration.deployed();

    // Deploy PremiumMerch
    const PremiumMerch = await ethers.getContractFactory("PremiumMerch");
    premiumMerch = await PremiumMerch.deploy(
      "Premium Merch NFT",
      "PMERCH",
      basicMerch.address,
      owner.address,
      UPGRADE_FEE
    );
    await premiumMerch.deployed();

    // Deploy MerchManager
    const MerchManager = await ethers.getContractFactory("MerchManager");
    merchManager = await MerchManager.deploy(
      basicMerch.address,
      premiumMerch.address,
      easIntegration.address
    );
    await merchManager.deployed();

    // Configure contracts
    await basicMerch.setPremiumContract(premiumMerch.address);
    await premiumMerch.setBasicMerchContract(basicMerch.address);
    await basicMerch.setWhitelistedMinter(merchManager.address, true);
  });

  describe("Deployment", function () {
    it("Should set the correct contract addresses", async function () {
      const [basicAddr, premiumAddr, easAddr] = await merchManager.getContractAddresses();
      expect(basicAddr).to.equal(basicMerch.address);
      expect(premiumAddr).to.equal(premiumMerch.address);
      expect(easAddr).to.equal(easIntegration.address);
    });

    it("Should set the correct owner", async function () {
      expect(await merchManager.owner()).to.equal(owner.address);
    });
  });

  describe("Event Registration", function () {
    const eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    const metadata = "Test Event 2024 - Sample Event";

    it("Should allow owner to register event", async function () {
      await expect(merchManager.registerEvent(eventId, metadata))
        .to.emit(merchManager, "EventRegistered")
        .withArgs(eventId, metadata);

      expect(await merchManager.getEventMetadata(eventId)).to.equal(metadata);
    });

    it("Should not allow non-owner to register event", async function () {
      await expect(
        merchManager.connect(user1).registerEvent(eventId, metadata)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should not allow registering event with zero ID", async function () {
      await expect(
        merchManager.registerEvent(ethers.constants.HashZero, metadata)
      ).to.be.revertedWith("Invalid event ID");
    });

    it("Should not allow registering duplicate event", async function () {
      await merchManager.registerEvent(eventId, metadata);
      await expect(
        merchManager.registerEvent(eventId, "Different metadata")
      ).to.be.revertedWith("Event already registered");
    });
  });

  describe("SBT Minting with Attestation", function () {
    const eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    const tokenURI = "https://api.merch.com/basic/1";

    beforeEach(async function () {
      await merchManager.registerEvent(eventId, "Test Event 2024");
    });

    it("Should mint SBT and create attestation", async function () {
      await expect(
        merchManager.mintSBTWithAttestation(user1.address, tokenURI, eventId)
      ).to.emit(merchManager, "SBTMintedWithAttestation");

      // Check SBT was minted
      expect(await basicMerch.ownerOf(0)).to.equal(user1.address);

      // Check attestation was created
      const userAttestations = await merchManager.getUserAttendanceHistory(user1.address);
      expect(userAttestations.length).to.equal(1);
    });

    it("Should not allow minting for unregistered event", async function () {
      const unregisteredEventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Unregistered Event"));
      
      await expect(
        merchManager.mintSBTWithAttestation(user1.address, tokenURI, unregisteredEventId)
      ).to.be.revertedWith("EventNotRegistered");
    });

    it("Should not allow non-owner to mint", async function () {
      await expect(
        merchManager.connect(user1).mintSBTWithAttestation(user2.address, tokenURI, eventId)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("SBT Upgrade with Attestation", function () {
    const eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    const tokenURI = "https://api.merch.com/basic/1";

    beforeEach(async function () {
      await merchManager.registerEvent(eventId, "Test Event 2024");
      await merchManager.mintSBTWithAttestation(user1.address, tokenURI, eventId);
    });

    it("Should upgrade SBT and create attestation", async function () {
      await expect(
        merchManager.connect(user1).upgradeSBTWithAttestation(0, organizer.address, eventId, { value: UPGRADE_FEE })
      ).to.emit(merchManager, "SBTUpgradedWithAttestation");

      // Check SBT was burned
      await expect(basicMerch.ownerOf(0)).to.be.revertedWith("ERC721: invalid token ID");

      // Check premium NFT was minted
      expect(await premiumMerch.ownerOf(0)).to.equal(user1.address);

      // Check attestation was created
      const userAttestations = await merchManager.getUserAttendanceHistory(user1.address);
      expect(userAttestations.length).to.equal(2); // Original + upgrade
    });

    it("Should not allow upgrading for unregistered event", async function () {
      const unregisteredEventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Unregistered Event"));
      
      await expect(
        merchManager.connect(user1).upgradeSBTWithAttestation(0, organizer.address, unregisteredEventId, { value: UPGRADE_FEE })
      ).to.be.revertedWith("EventNotRegistered");
    });

    it("Should not allow non-SBT owner to upgrade", async function () {
      await expect(
        merchManager.connect(user2).upgradeSBTWithAttestation(0, organizer.address, eventId, { value: UPGRADE_FEE })
      ).to.be.revertedWith("SBTNotOwned");
    });
  });

  describe("Attendance Tracking", function () {
    const eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    const tokenURI = "https://api.merch.com/basic/1";

    beforeEach(async function () {
      await merchManager.registerEvent(eventId, "Test Event 2024");
      await merchManager.mintSBTWithAttestation(user1.address, tokenURI, eventId);
    });

    it("Should get user attendance history", async function () {
      const history = await merchManager.getUserAttendanceHistory(user1.address);
      expect(history.length).to.equal(1);
    });

    it("Should get event attendance", async function () {
      const attendance = await merchManager.getEventAttendance(eventId);
      expect(attendance.length).to.equal(1);
    });

    it("Should check if user attended event", async function () {
      expect(await merchManager.hasUserAttendedEvent(user1.address, eventId)).to.be.true;
      expect(await merchManager.hasUserAttendedEvent(user2.address, eventId)).to.be.false;
    });

    it("Should get user premium upgrades", async function () {
      // Upgrade SBT
      await merchManager.connect(user1).upgradeSBTWithAttestation(0, organizer.address, eventId, { value: UPGRADE_FEE });
      
      const premiumUpgrades = await merchManager.getUserPremiumUpgrades(user1.address);
      expect(premiumUpgrades.length).to.equal(1);
    });
  });

  describe("Contract Management", function () {
    it("Should allow owner to update contracts", async function () {
      await merchManager.updateContracts(user1.address, user2.address, organizer.address);
      
      const [basicAddr, premiumAddr, easAddr] = await merchManager.getContractAddresses();
      expect(basicAddr).to.equal(user1.address);
      expect(premiumAddr).to.equal(user2.address);
      expect(easAddr).to.equal(organizer.address);
    });

    it("Should not allow non-owner to update contracts", async function () {
      await expect(
        merchManager.connect(user1).updateContracts(user1.address, user2.address, organizer.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should not allow setting zero addresses", async function () {
      await expect(
        merchManager.updateContracts(ethers.constants.AddressZero, premiumMerch.address, easIntegration.address)
      ).to.be.revertedWith("Invalid basic merch address");
    });
  });

  describe("Batch Operations", function () {
    it("Should batch register events", async function () {
      const eventIds = [
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 1")),
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 2"))
      ];
      const metadataArray = ["Event 1 Metadata", "Event 2 Metadata"];

      await merchManager.batchRegisterEvents(eventIds, metadataArray);

      expect(await merchManager.getEventMetadata(eventIds[0])).to.equal(metadataArray[0]);
      expect(await merchManager.getEventMetadata(eventIds[1])).to.equal(metadataArray[1]);
    });

    it("Should not allow mismatched array lengths", async function () {
      const eventIds = [ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 1"))];
      const metadataArray = ["Event 1 Metadata", "Event 2 Metadata"];

      await expect(
        merchManager.batchRegisterEvents(eventIds, metadataArray)
      ).to.be.revertedWith("Array length mismatch");
    });

    it("Should not allow non-owner to batch register", async function () {
      const eventIds = [ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 1"))];
      const metadataArray = ["Event 1 Metadata"];

      await expect(
        merchManager.connect(user1).batchRegisterEvents(eventIds, metadataArray)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
