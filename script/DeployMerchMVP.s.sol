// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";
import "../src/EASIntegration.sol";
import "../src/MerchManager.sol";

/**
 * @title DeployMerchMVP
 * @notice Deployment script for the complete Merch MVP system on Base Sepolia
 * @dev Run with: forge script script/DeployMerchMVP.s.sol:DeployMerchMVP --rpc-url base_sepolia --broadcast --verify
 */
contract DeployMerchMVP is Script {
    // Deployment configuration
    string constant BASIC_NAME = "Basic Merch SBT";
    string constant BASIC_SYMBOL = "BMSBT";
    string constant PREMIUM_NAME = "Premium Merch NFT";
    string constant PREMIUM_SYMBOL = "PMNFT";
    
    // Upgrade fee: 0.001 ETH (adjust as needed for Base Sepolia)
    uint256 constant UPGRADE_FEE = 0.001 ether;
    
    // Fee split: 37.5% treasury, 62.5% organizer
    uint256 constant TREASURY_SPLIT = 3750;
    uint256 constant ORGANIZER_SPLIT = 6250;
    
    // Deployed contract addresses (will be set during deployment)
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    EASIntegration public easIntegration;
    MerchManager public merchManager;
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get treasury address (can be same as deployer or different)
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        
        // Mock EAS Registry for Base Sepolia (replace with actual if available)
        // For now using deployer address as placeholder
        address easRegistry = vm.envOr("EAS_REGISTRY_ADDRESS", deployer);
        
        console.log("===========================================");
        console.log("Deploying Merch MVP to Base Sepolia");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("EAS Registry:", easRegistry);
        console.log("Upgrade Fee:", UPGRADE_FEE);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy BasicMerch (SBT Contract)
        console.log("\n1. Deploying BasicMerch...");
        basicMerch = new BasicMerch(BASIC_NAME, BASIC_SYMBOL);
        console.log("BasicMerch deployed at:", address(basicMerch));
        
        // 2. Deploy PremiumMerch (Premium NFT Contract)
        console.log("\n2. Deploying PremiumMerch...");
        premiumMerch = new PremiumMerch(
            PREMIUM_NAME,
            PREMIUM_SYMBOL,
            address(basicMerch),
            treasury,
            UPGRADE_FEE
        );
        console.log("PremiumMerch deployed at:", address(premiumMerch));
        
        // 3. Deploy EASIntegration
        console.log("\n3. Deploying EASIntegration...");
        easIntegration = new EASIntegration(easRegistry);
        console.log("EASIntegration deployed at:", address(easIntegration));
        
        // 4. Deploy MerchManager
        console.log("\n4. Deploying MerchManager...");
        merchManager = new MerchManager(
            address(basicMerch),
            address(premiumMerch),
            address(easIntegration)
        );
        console.log("MerchManager deployed at:", address(merchManager));
        
        // 5. Configure contracts
        console.log("\n5. Configuring contracts...");
        
        // Set PremiumMerch as authorized burner in BasicMerch
        basicMerch.setPremiumContract(address(premiumMerch));
        console.log("  - BasicMerch: Set premium contract");
        
        // Whitelist MerchManager as minter
        basicMerch.setWhitelistedMinter(address(merchManager), true);
        console.log("  - BasicMerch: Whitelisted MerchManager as minter");
        
        // Whitelist deployer as minter (for testing)
        basicMerch.setWhitelistedMinter(deployer, true);
        console.log("  - BasicMerch: Whitelisted deployer as minter");
        
        // Set BasicMerch reference in PremiumMerch (should already be set, but confirming)
        premiumMerch.setBasicMerchContract(address(basicMerch));
        console.log("  - PremiumMerch: Set basic merch contract");
        
        // Transfer ownership of EASIntegration to MerchManager
        easIntegration.transferOwnership(address(merchManager));
        console.log("  - EASIntegration: Transferred ownership to MerchManager");
        
        vm.stopBroadcast();
        
        // Print deployment summary
        printDeploymentSummary(deployer, treasury);
        
        // Save deployment addresses to file
        saveDeploymentAddresses();
    }
    
    function printDeploymentSummary(address deployer, address treasury) internal view {
        console.log("\n===========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("===========================================");
        console.log("Network: Base Sepolia");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("\nContract Addresses:");
        console.log("-------------------------------------------");
        console.log("BasicMerch:      ", address(basicMerch));
        console.log("PremiumMerch:    ", address(premiumMerch));
        console.log("EASIntegration:  ", address(easIntegration));
        console.log("MerchManager:    ", address(merchManager));
        console.log("===========================================");
        console.log("\nNext Steps:");
        console.log("1. Verify contracts on BaseScan");
        console.log("2. Register events in MerchManager");
        console.log("3. Set up backend to interact with MerchManager");
        console.log("4. Configure metadata URIs");
        console.log("===========================================");
    }
    
    function saveDeploymentAddresses() internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "base-sepolia",\n',
            '  "basicMerch": "', vm.toString(address(basicMerch)), '",\n',
            '  "premiumMerch": "', vm.toString(address(premiumMerch)), '",\n',
            '  "easIntegration": "', vm.toString(address(easIntegration)), '",\n',
            '  "merchManager": "', vm.toString(address(merchManager)), '"\n',
            '}'
        ));
        
        vm.writeFile("deployments/base-sepolia.json", json);
        console.log("\nDeployment addresses saved to: deployments/base-sepolia.json");
    }
}