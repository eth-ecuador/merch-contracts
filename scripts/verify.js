const { ethers } = require("hardhat");

async function main() {
  console.log("Starting contract verification...");
  
  // Load deployment info
  const fs = require('fs');
  const path = require('path');
  const deploymentsDir = path.join(__dirname, '../deployments');
  
  // Find the most recent deployment file
  const files = fs.readdirSync(deploymentsDir)
    .filter(file => file.startsWith('deployment-') && file.endsWith('.json'))
    .sort()
    .reverse();
  
  if (files.length === 0) {
    console.error("No deployment files found. Please run deployment first.");
    process.exit(1);
  }
  
  const deploymentFile = path.join(deploymentsDir, files[0]);
  const deploymentInfo = JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
  
  console.log("Using deployment file:", deploymentFile);
  console.log("Network:", deploymentInfo.network);
  
  try {
    // Verify BasicMerch
    console.log("\n1. Verifying BasicMerch contract...");
    await hre.run("verify:verify", {
      address: deploymentInfo.contracts.BasicMerch,
      constructorArguments: [
        deploymentInfo.parameters.basicMerchName,
        deploymentInfo.parameters.basicMerchSymbol
      ]
    });
    console.log("✓ BasicMerch verified");

    // Verify EASIntegration
    console.log("\n2. Verifying EASIntegration contract...");
    await hre.run("verify:verify", {
      address: deploymentInfo.contracts.EASIntegration,
      constructorArguments: [
        ethers.constants.AddressZero // Mock EAS registry
      ]
    });
    console.log("✓ EASIntegration verified");

    // Verify PremiumMerch
    console.log("\n3. Verifying PremiumMerch contract...");
    await hre.run("verify:verify", {
      address: deploymentInfo.contracts.PremiumMerch,
      constructorArguments: [
        deploymentInfo.parameters.premiumMerchName,
        deploymentInfo.parameters.premiumMerchSymbol,
        deploymentInfo.contracts.BasicMerch,
        deploymentInfo.parameters.treasury,
        deploymentInfo.parameters.upgradeFee
      ]
    });
    console.log("✓ PremiumMerch verified");

    // Verify MerchManager
    console.log("\n4. Verifying MerchManager contract...");
    await hre.run("verify:verify", {
      address: deploymentInfo.contracts.MerchManager,
      constructorArguments: [
        deploymentInfo.contracts.BasicMerch,
        deploymentInfo.contracts.PremiumMerch,
        deploymentInfo.contracts.EASIntegration
      ]
    });
    console.log("✓ MerchManager verified");

    console.log("\n=== ALL CONTRACTS VERIFIED SUCCESSFULLY ===");
    
  } catch (error) {
    console.error("Verification failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
