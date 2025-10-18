const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BasicMerch", function () {
  let basicMerch;
  let premiumMerch;
  let owner;
  let minter;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, minter, user1, user2] = await ethers.getSigners();

    // Deploy BasicMerch
    const BasicMerch = await ethers.getContractFactory("BasicMerch");
    basicMerch = await BasicMerch.deploy("Basic Merch SBT", "BMERCH");
    await basicMerch.deployed();

    // Deploy mock PremiumMerch
    const PremiumMerch = await ethers.getContractFactory("PremiumMerch");
    premiumMerch = await PremiumMerch.deploy(
      "Premium Merch NFT",
      "PMERCH",
      basicMerch.address,
      owner.address,
      ethers.utils.parseEther("0.01")
    );
    await premiumMerch.deployed();

    // Configure contracts
    await basicMerch.setPremiumContract(premiumMerch.address);
    await premiumMerch.setBasicMerchContract(basicMerch.address);
    await basicMerch.setWhitelistedMinter(minter.address, true);
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await basicMerch.name()).to.equal("Basic Merch SBT");
      expect(await basicMerch.symbol()).to.equal("BMERCH");
    });

    it("Should set the correct owner", async function () {
      expect(await basicMerch.owner()).to.equal(owner.address);
    });
  });

  describe("Minting", function () {
    it("Should allow whitelisted minter to mint SBT", async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      
      await expect(basicMerch.connect(minter).mintSBT(user1.address, tokenURI))
        .to.emit(basicMerch, "SBTMinted")
        .withArgs(user1.address, 0, tokenURI);

      expect(await basicMerch.ownerOf(0)).to.equal(user1.address);
      expect(await basicMerch.getCurrentTokenId()).to.equal(1);
    });

    it("Should not allow non-whitelisted address to mint", async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      
      await expect(
        basicMerch.connect(user1).mintSBT(user2.address, tokenURI)
      ).to.be.revertedWith("NotWhitelistedMinter");
    });

    it("Should not allow minting to zero address", async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      
      await expect(
        basicMerch.connect(minter).mintSBT(ethers.constants.AddressZero, tokenURI)
      ).to.be.revertedWith("Cannot mint to zero address");
    });

    it("Should not allow empty token URI", async function () {
      await expect(
        basicMerch.connect(minter).mintSBT(user1.address, "")
      ).to.be.revertedWith("Token URI cannot be empty");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.connect(minter).mintSBT(user1.address, tokenURI);
    });

    it("Should allow premium contract to burn SBT", async function () {
      await expect(basicMerch.connect(premiumMerch.address).burnSBT(0))
        .to.emit(basicMerch, "SBTBurned")
        .withArgs(0);

      await expect(basicMerch.ownerOf(0)).to.be.revertedWith("ERC721: invalid token ID");
    });

    it("Should not allow non-premium contract to burn", async function () {
      await expect(
        basicMerch.connect(user1).burnSBT(0)
      ).to.be.revertedWith("NotPremiumContract");
    });

    it("Should not allow burning non-existent token", async function () {
      await expect(
        basicMerch.connect(premiumMerch.address).burnSBT(999)
      ).to.be.revertedWith("TokenDoesNotExist");
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to whitelist minters", async function () {
      await expect(basicMerch.setWhitelistedMinter(user1.address, true))
        .to.emit(basicMerch, "MinterWhitelisted")
        .withArgs(user1.address, true);

      expect(await basicMerch.whitelistedMinters(user1.address)).to.be.true;
    });

    it("Should not allow non-owner to whitelist minters", async function () {
      await expect(
        basicMerch.connect(user1).setWhitelistedMinter(user2.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to set premium contract", async function () {
      await expect(basicMerch.setPremiumContract(user1.address))
        .to.emit(basicMerch, "PremiumContractSet")
        .withArgs(user1.address);

      expect(await basicMerch.premiumMerchContract()).to.equal(user1.address);
    });
  });

  describe("SBT Behavior", function () {
    beforeEach(async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.connect(minter).mintSBT(user1.address, tokenURI);
    });

    it("Should not allow transfers between users", async function () {
      await expect(
        basicMerch.connect(user1).transferFrom(user1.address, user2.address, 0)
      ).to.be.revertedWith("TransferNotAllowed");
    });

    it("Should not allow approvals", async function () {
      await expect(
        basicMerch.connect(user1).approve(user2.address, 0)
      ).to.be.revertedWith("TransferNotAllowed");
    });

    it("Should not allow setting approval for all", async function () {
      await expect(
        basicMerch.connect(user1).setApprovalForAll(user2.address, true)
      ).to.be.revertedWith("TransferNotAllowed");
    });
  });

  describe("isApprovedOrOwner", function () {
    beforeEach(async function () {
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.connect(minter).mintSBT(user1.address, tokenURI);
    });

    it("Should return true for token owner", async function () {
      expect(await basicMerch.isApprovedOrOwner(user1.address, 0)).to.be.true;
    });

    it("Should return false for non-owner", async function () {
      expect(await basicMerch.isApprovedOrOwner(user2.address, 0)).to.be.false;
    });

    it("Should return false for non-existent token", async function () {
      expect(await basicMerch.isApprovedOrOwner(user1.address, 999)).to.be.false;
    });
  });

  describe("Base URI", function () {
    it("Should allow owner to set base URI", async function () {
      const newBaseURI = "https://newapi.merch.com/basic/";
      await basicMerch.setBaseURI(newBaseURI);
      expect(await basicMerch._baseURI()).to.equal(newBaseURI);
    });

    it("Should not allow non-owner to set base URI", async function () {
      await expect(
        basicMerch.connect(user1).setBaseURI("https://newapi.merch.com/basic/")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
