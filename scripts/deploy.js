const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment of Merch MVP contracts...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deployment parameters
  const BASIC_MERCH_NAME = "Basic Merch SBT";
  const BASIC_MERCH_SYMBOL = "BMERCH";
  const PREMIUM_MERCH_NAME = "Premium Merch NFT";
  const PREMIUM_MERCH_SYMBOL = "PMERCH";
  const UPGRADE_FEE = ethers.utils.parseEther("0.01"); // 0.01 ETH upgrade fee
  const TREASURY_ADDRESS = deployer.address; // Use deployer as treasury for now

  try {
    // 1. Deploy BasicMerch contract
    console.log("\n1. Deploying BasicMerch contract...");
    const BasicMerch = await ethers.getContractFactory("BasicMerch");
    const basicMerch = await BasicMerch.deploy(BASIC_MERCH_NAME, BASIC_MERCH_SYMBOL);
    await basicMerch.deployed();
    console.log("BasicMerch deployed to:", basicMerch.address);

    // 2. Deploy EASIntegration contract
    console.log("\n2. Deploying EASIntegration contract...");
    const EASIntegration = await ethers.getContractFactory("EASIntegration");
    const easIntegration = await EASIntegration.deploy(ethers.constants.AddressZero); // Mock EAS registry
    await easIntegration.deployed();
    console.log("EASIntegration deployed to:", easIntegration.address);

    // 3. Deploy PremiumMerch contract
    console.log("\n3. Deploying PremiumMerch contract...");
    const PremiumMerch = await ethers.getContractFactory("PremiumMerch");
    const premiumMerch = await PremiumMerch.deploy(
      PREMIUM_MERCH_NAME,
      PREMIUM_MERCH_SYMBOL,
      basicMerch.address,
      TREASURY_ADDRESS,
      UPGRADE_FEE
    );
    await premiumMerch.deployed();
    console.log("PremiumMerch deployed to:", premiumMerch.address);

    // 4. Deploy MerchManager contract
    console.log("\n4. Deploying MerchManager contract...");
    const MerchManager = await ethers.getContractFactory("MerchManager");
    const merchManager = await MerchManager.deploy(
      basicMerch.address,
      premiumMerch.address,
      easIntegration.address
    );
    await merchManager.deployed();
    console.log("MerchManager deployed to:", merchManager.address);

    // 5. Configure contracts
    console.log("\n5. Configuring contracts...");
    
    // Set premium contract in BasicMerch
    console.log("Setting premium contract in BasicMerch...");
    await basicMerch.setPremiumContract(premiumMerch.address);
    
    // Set basic merch contract in PremiumMerch
    console.log("Setting basic merch contract in PremiumMerch...");
    await premiumMerch.setBasicMerchContract(basicMerch.address);
    
    // Set base URIs
    console.log("Setting base URIs...");
    await basicMerch.setBaseURI("https://api.merch.com/basic/");
    await premiumMerch.setBaseURI("https://api.merch.com/premium/");

    // 6. Whitelist the MerchManager as a minter
    console.log("\n6. Whitelisting MerchManager as minter...");
    await basicMerch.setWhitelistedMinter(merchManager.address, true);

    // 7. Register a sample event
    console.log("\n7. Registering sample event...");
    const sampleEventId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Sample Event 2024"));
    await merchManager.registerEvent(sampleEventId, "Sample Event 2024 - Test Event");

    // 8. Display deployment summary
    console.log("\n=== DEPLOYMENT SUMMARY ===");
    console.log("Network:", network.name);
    console.log("Deployer:", deployer.address);
    console.log("BasicMerch:", basicMerch.address);
    console.log("PremiumMerch:", premiumMerch.address);
    console.log("EASIntegration:", easIntegration.address);
    console.log("MerchManager:", merchManager.address);
    console.log("Upgrade Fee:", ethers.utils.formatEther(UPGRADE_FEE), "ETH");
    console.log("Treasury:", TREASURY_ADDRESS);

    // 9. Save deployment info
    const deploymentInfo = {
      network: network.name,
      deployer: deployer.address,
      contracts: {
        BasicMerch: basicMerch.address,
        PremiumMerch: premiumMerch.address,
        EASIntegration: easIntegration.address,
        MerchManager: merchManager.address
      },
      parameters: {
        upgradeFee: UPGRADE_FEE.toString(),
        treasury: TREASURY_ADDRESS,
        basicMerchName: BASIC_MERCH_NAME,
        basicMerchSymbol: BASIC_MERCH_SYMBOL,
        premiumMerchName: PREMIUM_MERCH_NAME,
        premiumMerchSymbol: PREMIUM_MERCH_SYMBOL
      },
      timestamp: new Date().toISOString()
    };

    const fs = require('fs');
    const path = require('path');
    const deploymentsDir = path.join(__dirname, '../deployments');
    
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const filename = `deployment-${network.name}-${Date.now()}.json`;
    const filepath = path.join(deploymentsDir, filename);
    fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));
    console.log(`\nDeployment info saved to: ${filepath}`);

    console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
    
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
