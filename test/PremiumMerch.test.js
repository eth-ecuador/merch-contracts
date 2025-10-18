const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PremiumMerch", function () {
  let basicMerch;
  let premiumMerch;
  let owner;
  let user1;
  let user2;
  let organizer;
  let treasury;

  const UPGRADE_FEE = ethers.utils.parseEther("0.01");

  beforeEach(async function () {
    [owner, user1, user2, organizer, treasury] = await ethers.getSigners();

    // Deploy BasicMerch
    const BasicMerch = await ethers.getContractFactory("BasicMerch");
    basicMerch = await BasicMerch.deploy("Basic Merch SBT", "BMERCH");
    await basicMerch.deployed();

    // Deploy PremiumMerch
    const PremiumMerch = await ethers.getContractFactory("PremiumMerch");
    premiumMerch = await PremiumMerch.deploy(
      "Premium Merch NFT",
      "PMERCH",
      basicMerch.address,
      treasury.address,
      UPGRADE_FEE
    );
    await premiumMerch.deployed();

    // Configure contracts
    await basicMerch.setPremiumContract(premiumMerch.address);
    await premiumMerch.setBasicMerchContract(basicMerch.address);
    await basicMerch.setWhitelistedMinter(owner.address, true);
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await premiumMerch.name()).to.equal("Premium Merch NFT");
      expect(await premiumMerch.symbol()).to.equal("PMERCH");
    });

    it("Should set the correct upgrade fee", async function () {
      expect(await premiumMerch.upgradeFee()).to.equal(UPGRADE_FEE);
    });

    it("Should set the correct treasury", async function () {
      expect(await premiumMerch.treasury()).to.equal(treasury.address);
    });

    it("Should set default fee split", async function () {
      expect(await premiumMerch.treasurySplit()).to.equal(3750); // 37.5%
      expect(await premiumMerch.organizerSplit()).to.equal(6250); // 62.5%
    });
  });

  describe("SBT Upgrade", function () {
    beforeEach(async function () {
      // Mint an SBT for user1
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.mintSBT(user1.address, tokenURI);
    });

    it("Should allow SBT owner to upgrade with correct fee", async function () {
      const initialTreasuryBalance = await treasury.getBalance();
      const initialOrganizerBalance = await organizer.getBalance();

      await expect(
        premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE })
      ).to.emit(premiumMerch, "SBTUpgraded")
        .withArgs(user1.address, 0, 0, UPGRADE_FEE);

      // Check that SBT was burned
      await expect(basicMerch.ownerOf(0)).to.be.revertedWith("ERC721: invalid token ID");

      // Check that premium NFT was minted
      expect(await premiumMerch.ownerOf(0)).to.equal(user1.address);

      // Check fee distribution
      const treasuryAmount = UPGRADE_FEE.mul(3750).div(10000);
      const organizerAmount = UPGRADE_FEE.sub(treasuryAmount);

      expect(await treasury.getBalance()).to.equal(initialTreasuryBalance.add(treasuryAmount));
      expect(await organizer.getBalance()).to.equal(initialOrganizerBalance.add(organizerAmount));
    });

    it("Should not allow upgrade with insufficient fee", async function () {
      const insufficientFee = UPGRADE_FEE.sub(ethers.utils.parseEther("0.001"));
      
      await expect(
        premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: insufficientFee })
      ).to.be.revertedWith("Insufficient fee");
    });

    it("Should not allow non-SBT owner to upgrade", async function () {
      await expect(
        premiumMerch.connect(user2).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE })
      ).to.be.revertedWith("SBTNotOwned");
    });

    it("Should not allow upgrading non-existent SBT", async function () {
      await expect(
        premiumMerch.connect(user1).upgradeSBT(999, organizer.address, { value: UPGRADE_FEE })
      ).to.be.revertedWith("SBTDoesNotExist");
    });

    it("Should not allow upgrading with zero organizer address", async function () {
      await expect(
        premiumMerch.connect(user1).upgradeSBT(0, ethers.constants.AddressZero, { value: UPGRADE_FEE })
      ).to.be.revertedWith("Invalid organizer address");
    });

    it("Should not allow upgrading the same SBT twice", async function () {
      // First upgrade
      await premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE });

      // Try to upgrade again (should fail)
      await expect(
        premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE })
      ).to.be.revertedWith("SBTAlreadyUpgraded");
    });
  });

  describe("Fee Management", function () {
    it("Should allow owner to set upgrade fee", async function () {
      const newFee = ethers.utils.parseEther("0.02");
      await expect(premiumMerch.setUpgradeFee(newFee))
        .to.emit(premiumMerch, "UpgradeFeeSet")
        .withArgs(newFee);

      expect(await premiumMerch.upgradeFee()).to.equal(newFee);
    });

    it("Should not allow non-owner to set upgrade fee", async function () {
      const newFee = ethers.utils.parseEther("0.02");
      await expect(
        premiumMerch.connect(user1).setUpgradeFee(newFee)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to set treasury", async function () {
      await expect(premiumMerch.setTreasury(user1.address))
        .to.emit(premiumMerch, "TreasurySet")
        .withArgs(user1.address);

      expect(await premiumMerch.treasury()).to.equal(user1.address);
    });

    it("Should not allow setting zero treasury", async function () {
      await expect(
        premiumMerch.setTreasury(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid treasury address");
    });

    it("Should allow owner to set fee split", async function () {
      const newTreasurySplit = 5000; // 50%
      const newOrganizerSplit = 5000; // 50%

      await expect(premiumMerch.setFeeSplit(newTreasurySplit, newOrganizerSplit))
        .to.emit(premiumMerch, "FeeSplitSet")
        .withArgs(newTreasurySplit, newOrganizerSplit);

      expect(await premiumMerch.treasurySplit()).to.equal(newTreasurySplit);
      expect(await premiumMerch.organizerSplit()).to.equal(newOrganizerSplit);
    });

    it("Should not allow invalid fee split", async function () {
      await expect(
        premiumMerch.setFeeSplit(3000, 4000) // Doesn't add up to 100%
      ).to.be.revertedWith("Invalid fee split");
    });

    it("Should not allow zero splits", async function () {
      await expect(
        premiumMerch.setFeeSplit(0, 10000)
      ).to.be.revertedWith("Splits must be positive");
    });
  });

  describe("Contract Management", function () {
    it("Should allow owner to set basic merch contract", async function () {
      await premiumMerch.setBasicMerchContract(user1.address);
      expect(await premiumMerch.basicMerchContract()).to.equal(user1.address);
    });

    it("Should not allow setting zero address", async function () {
      await expect(
        premiumMerch.setBasicMerchContract(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid contract address");
    });

    it("Should allow owner to pause and unpause", async function () {
      await premiumMerch.pause();
      expect(await premiumMerch.paused()).to.be.true;

      await premiumMerch.unpause();
      expect(await premiumMerch.paused()).to.be.false;
    });

    it("Should not allow upgrade when paused", async function () {
      // Mint SBT
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.mintSBT(user1.address, tokenURI);

      // Pause contract
      await premiumMerch.pause();

      // Try to upgrade
      await expect(
        premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE })
      ).to.be.revertedWith("Pausable: paused");
    });
  });

  describe("Base URI", function () {
    it("Should allow owner to set base URI", async function () {
      const newBaseURI = "https://newapi.merch.com/premium/";
      await expect(premiumMerch.setBaseURI(newBaseURI))
        .to.emit(premiumMerch, "BaseURISet")
        .withArgs(newBaseURI);

      expect(await premiumMerch._baseURI()).to.equal(newBaseURI);
    });

    it("Should not allow non-owner to set base URI", async function () {
      await expect(
        premiumMerch.connect(user1).setBaseURI("https://newapi.merch.com/premium/")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow owner to emergency withdraw", async function () {
      // Send some ETH to the contract
      await owner.sendTransaction({
        to: premiumMerch.address,
        value: ethers.utils.parseEther("0.1")
      });

      const initialOwnerBalance = await owner.getBalance();
      await premiumMerch.emergencyWithdraw();
      const finalOwnerBalance = await owner.getBalance();

      expect(finalOwnerBalance).to.be.gt(initialOwnerBalance);
    });

    it("Should not allow non-owner to emergency withdraw", async function () {
      await expect(
        premiumMerch.connect(user1).emergencyWithdraw()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("View Functions", function () {
    it("Should return correct current token ID", async function () {
      expect(await premiumMerch.getCurrentTokenId()).to.equal(0);
    });

    it("Should return correct balance", async function () {
      expect(await premiumMerch.getBalance()).to.equal(0);
    });

    it("Should track upgraded SBTs correctly", async function () {
      // Mint and upgrade SBT
      const tokenURI = "https://api.merch.com/basic/1";
      await basicMerch.mintSBT(user1.address, tokenURI);
      await premiumMerch.connect(user1).upgradeSBT(0, organizer.address, { value: UPGRADE_FEE });

      expect(await premiumMerch.isSBTUpgraded(0)).to.be.true;
      expect(await premiumMerch.getPremiumTokenId(0)).to.equal(0);
    });
  });
});
