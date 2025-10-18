const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EASIntegration", function () {
  let easIntegration;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy EASIntegration
    const EASIntegration = await ethers.getContractFactory("EASIntegration");
    easIntegration = await EASIntegration.deploy(ethers.constants.AddressZero); // Mock EAS registry
    await easIntegration.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await easIntegration.owner()).to.equal(owner.address);
    });

    it("Should set the EAS registry", async function () {
      expect(await easIntegration.easRegistry()).to.equal(ethers.constants.AddressZero);
    });
  });

  describe("Attestation Creation", function () {
    const eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    const tokenId = 1;

    it("Should create attendance attestation", async function () {
      await expect(
        easIntegration.createAttendanceAttestation(eventId, user1.address, tokenId, false)
      ).to.emit(easIntegration, "AttestationCreated")
        .withArgs(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
          ["bytes32", "address", "uint256", "uint64", "uint256"],
          [eventId, user1.address, tokenId, await ethers.provider.getBlockNumber(), 0]
        )), eventId, user1.address, tokenId, false);

      const attestationId = await easIntegration.getUserAttestations(user1.address);
      expect(attestationId.length).to.equal(1);
    });

    it("Should not allow creating attestation with zero event ID", async function () {
      await expect(
        easIntegration.createAttendanceAttestation(ethers.constants.HashZero, user1.address, tokenId, false)
      ).to.be.revertedWith("Invalid event ID");
    });

    it("Should not allow creating attestation with zero address", async function () {
      await expect(
        easIntegration.createAttendanceAttestation(eventId, ethers.constants.AddressZero, tokenId, false)
      ).to.be.revertedWith("Invalid attendee");
    });

    it("Should not allow non-owner to create attestation", async function () {
      await expect(
        easIntegration.connect(user1).createAttendanceAttestation(eventId, user2.address, tokenId, false)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Attestation Retrieval", function () {
    let eventId;
    let attestationId;

    beforeEach(async function () {
      eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 1, false);
      const attestations = await easIntegration.getUserAttestations(user1.address);
      attestationId = attestations[0];
    });

    it("Should retrieve attestation data", async function () {
      const attestation = await easIntegration.getAttestation(attestationId);
      expect(attestation.eventId).to.equal(eventId);
      expect(attestation.attendee).to.equal(user1.address);
      expect(attestation.tokenId).to.equal(1);
      expect(attestation.isPremiumUpgrade).to.be.false;
    });

    it("Should not retrieve non-existent attestation", async function () {
      const nonExistentId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("non-existent"));
      await expect(
        easIntegration.getAttestation(nonExistentId)
      ).to.be.revertedWith("AttestationNotFound");
    });

    it("Should get user attestations", async function () {
      const userAttestations = await easIntegration.getUserAttestations(user1.address);
      expect(userAttestations.length).to.equal(1);
      expect(userAttestations[0]).to.equal(attestationId);
    });

    it("Should get event attestations", async function () {
      const eventAttestations = await easIntegration.getEventAttestations(eventId);
      expect(eventAttestations.length).to.equal(1);
      expect(eventAttestations[0]).to.equal(attestationId);
    });

    it("Should get user attestation count", async function () {
      expect(await easIntegration.getUserAttestationCount(user1.address)).to.equal(1);
    });

    it("Should get event attestation count", async function () {
      expect(await easIntegration.getEventAttestationCount(eventId)).to.equal(1);
    });
  });

  describe("Event Attendance Check", function () {
    let eventId;

    beforeEach(async function () {
      eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    });

    it("Should return true if user attended event", async function () {
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 1, false);
      expect(await easIntegration.hasUserAttendedEvent(user1.address, eventId)).to.be.true;
    });

    it("Should return false if user did not attend event", async function () {
      expect(await easIntegration.hasUserAttendedEvent(user1.address, eventId)).to.be.false;
    });

    it("Should return false for different event", async function () {
      const otherEventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Other Event"));
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 1, false);
      expect(await easIntegration.hasUserAttendedEvent(user1.address, otherEventId)).to.be.false;
    });
  });

  describe("Premium Upgrades", function () {
    let eventId;

    beforeEach(async function () {
      eventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test Event"));
    });

    it("Should get user premium upgrades", async function () {
      // Create basic attestation
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 1, false);
      
      // Create premium upgrade attestation
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 2, true);

      const premiumUpgrades = await easIntegration.getUserPremiumUpgrades(user1.address);
      expect(premiumUpgrades.length).to.equal(1);
    });

    it("Should return empty array if no premium upgrades", async function () {
      await easIntegration.createAttendanceAttestation(eventId, user1.address, 1, false);
      const premiumUpgrades = await easIntegration.getUserPremiumUpgrades(user1.address);
      expect(premiumUpgrades.length).to.equal(0);
    });
  });

  describe("Batch Operations", function () {
    let eventIds;
    let attendees;
    let tokenIds;
    let isPremiumUpgrades;

    beforeEach(async function () {
      eventIds = [
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 1")),
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Event 2"))
      ];
      attendees = [user1.address, user2.address];
      tokenIds = [1, 2];
      isPremiumUpgrades = [false, true];
    });

    it("Should batch create attestations", async function () {
      await expect(
        easIntegration.batchCreateAttestations(eventIds, attendees, tokenIds, isPremiumUpgrades)
      ).to.emit(easIntegration, "AttestationCreated");

      expect(await easIntegration.getUserAttestationCount(user1.address)).to.equal(1);
      expect(await easIntegration.getUserAttestationCount(user2.address)).to.equal(1);
    });

    it("Should not allow mismatched array lengths", async function () {
      const mismatchedAttendees = [user1.address]; // Different length
      
      await expect(
        easIntegration.batchCreateAttestations(eventIds, mismatchedAttendees, tokenIds, isPremiumUpgrades)
      ).to.be.revertedWith("Array length mismatch");
    });

    it("Should not allow non-owner to batch create", async function () {
      await expect(
        easIntegration.connect(user1).batchCreateAttestations(eventIds, attendees, tokenIds, isPremiumUpgrades)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("EAS Registry Management", function () {
    it("Should allow owner to set EAS registry", async function () {
      await expect(easIntegration.setEASRegistry(user1.address))
        .to.emit(easIntegration, "EASRegistrySet")
        .withArgs(user1.address);

      expect(await easIntegration.easRegistry()).to.equal(user1.address);
    });

    it("Should not allow setting zero EAS registry", async function () {
      await expect(
        easIntegration.setEASRegistry(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid registry address");
    });

    it("Should not allow non-owner to set EAS registry", async function () {
      await expect(
        easIntegration.connect(user1).setEASRegistry(user2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
