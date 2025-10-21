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
 * @dev Run with: forge script script/DeployMerchMVP.s.sol:DeployMerchMVP --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv
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
    
    // Configuration addresses
    address public backendIssuer;
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get treasury address (can be same as deployer or different)
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        
        // Get backend issuer address for signature verification
        backendIssuer = vm.envOr("BACKEND_ISSUER_ADDRESS", deployer);
        
        // Mock EAS Registry for Base Sepolia (replace with actual if available)
        // For now using deployer address as placeholder
        address easRegistry = vm.envOr("EAS_REGISTRY_ADDRESS", deployer);
        
        console.log("===========================================");
        console.log("Deploying Merch MVP to Base Sepolia");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Backend Issuer:", backendIssuer);
        console.log("EAS Registry:", easRegistry);
        console.log("Upgrade Fee:", UPGRADE_FEE);
        console.log("Treasury Split: %s bps (%s%%)", TREASURY_SPLIT, TREASURY_SPLIT / 100);
        console.log("Organizer Split: %s bps (%s%%)", ORGANIZER_SPLIT, ORGANIZER_SPLIT / 100);
        console.log("===========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy BasicMerch (SBT Contract)
        console.log("\n[1/4] Deploying BasicMerch...");
        basicMerch = new BasicMerch(BASIC_NAME, BASIC_SYMBOL);
        console.log("  BasicMerch deployed at:", address(basicMerch));
        
        // 2. Deploy PremiumMerch (Premium NFT Contract)
        console.log("\n[2/4] Deploying PremiumMerch...");
        premiumMerch = new PremiumMerch(
            PREMIUM_NAME,
            PREMIUM_SYMBOL,
            address(basicMerch),
            treasury,
            UPGRADE_FEE
        );
        console.log("  PremiumMerch deployed at:", address(premiumMerch));
        
        // 3. Deploy EASIntegration
        console.log("\n[3/4] Deploying EASIntegration...");
        easIntegration = new EASIntegration(easRegistry);
        console.log("  EASIntegration deployed at:", address(easIntegration));
        
        // 4. Deploy MerchManager
        console.log("\n[4/4] Deploying MerchManager...");
        merchManager = new MerchManager(
            address(basicMerch),
            address(premiumMerch),
            address(easIntegration)
        );
        console.log("  MerchManager deployed at:", address(merchManager));
        
        // 5. Configure contracts
        console.log("\n===========================================");
        console.log("Configuring Contracts");
        console.log("===========================================");
        
        // Set backend issuer for signature verification
        console.log("\n[1/4] Setting backend issuer for signature verification...");
        basicMerch.setBackendIssuer(backendIssuer);
        console.log("  BasicMerch: Backend issuer set to", backendIssuer);
        
        // Confirm BasicMerch reference in PremiumMerch
        console.log("\n[2/4] Confirming BasicMerch reference in PremiumMerch...");
        premiumMerch.setBasicMerchContract(address(basicMerch));
        console.log("  PremiumMerch: BasicMerch reference confirmed");
        
        // Transfer ownership of EASIntegration to MerchManager
        console.log("\n[3/4] Transferring EASIntegration ownership to MerchManager...");
        easIntegration.transferOwnership(address(merchManager));
        console.log("  EASIntegration: Ownership transferred to MerchManager");
        
        // Set metadata base URIs (optional)
        console.log("\n[4/4] Setting metadata base URIs...");
        basicMerch.setBaseURI("https://api.merch.com/metadata/sbt/");
        premiumMerch.setBaseURI("https://api.merch.com/metadata/premium/");
        console.log("  Metadata base URIs set");
        
        vm.stopBroadcast();
        
        // Verify deployment
        console.log("\n===========================================");
        console.log("Verifying Deployment Configuration");
        console.log("===========================================");
        verifyDeployment(deployer);
        
        // Print deployment summary
        printDeploymentSummary(deployer, treasury);
        
        // Save deployment addresses to file
        saveDeploymentAddresses(deployer, treasury);
    }
    
    function verifyDeployment(address deployer) internal view {
        bool allGood = true;
        
        // Check BasicMerch configuration
        console.log("\nBasicMerch Configuration:");
        console.log("  Backend Issuer:", basicMerch.backendIssuer());
        // Note: _baseURI() is internal, so we can't access it directly
        console.log("  Base URI: [Internal function - not accessible]");
        
        if (basicMerch.backendIssuer() == address(0)) {
            console.log("  [ERROR] Backend issuer not set!");
            allGood = false;
        }
        
        // Check PremiumMerch configuration
        console.log("\nPremiumMerch Configuration:");
        console.log("  BasicMerch Contract:", address(premiumMerch.basicMerchContract()));
        console.log("  Upgrade Fee:", premiumMerch.upgradeFee());
        console.log("  Treasury:", premiumMerch.treasury());
        console.log("  Treasury Split:", premiumMerch.treasurySplit(), "bps");
        console.log("  Organizer Split:", premiumMerch.organizerSplit(), "bps");
        
        if (address(premiumMerch.basicMerchContract()) != address(basicMerch)) {
            console.log("  [ERROR] BasicMerch reference not set correctly!");
            allGood = false;
        }
        
        // Check EASIntegration ownership
        console.log("\nEASIntegration Configuration:");
        console.log("  Owner:", easIntegration.owner());
        console.log("  EAS Registry:", easIntegration.easRegistry());
        
        if (easIntegration.owner() != address(merchManager)) {
            console.log("  [ERROR] EASIntegration ownership not transferred!");
            allGood = false;
        }
        
        // Check MerchManager configuration
        console.log("\nMerchManager Configuration:");
        (address basic, address premium, address eas) = merchManager.getContractAddresses();
        console.log("  BasicMerch:", basic);
        console.log("  PremiumMerch:", premium);
        console.log("  EASIntegration:", eas);
        
        if (basic != address(basicMerch) || premium != address(premiumMerch) || eas != address(easIntegration)) {
            console.log("  [ERROR] Contract references not set correctly!");
            allGood = false;
        }
        
        console.log("\n===========================================");
        if (allGood) {
            console.log("Deployment Verification: PASSED");
        } else {
            console.log("Deployment Verification: FAILED");
            console.log("Please check the errors above!");
        }
        console.log("===========================================");
    }
    
    function printDeploymentSummary(address deployer, address treasury) internal view {
        console.log("\n===========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("===========================================");
        console.log("Network: Base Sepolia (Chain ID: 84532)");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("\nContract Addresses:");
        console.log("-------------------------------------------");
        console.log("BasicMerch:      ", address(basicMerch));
        console.log("PremiumMerch:    ", address(premiumMerch));
        console.log("EASIntegration:  ", address(easIntegration));
        console.log("MerchManager:    ", address(merchManager));
        console.log("===========================================");
        console.log("\nQuick Test Commands:");
        console.log("-------------------------------------------");
        console.log("# Mint a test SBT with signature");
        console.log("cast send", vm.toString(address(basicMerch)), "\\");
        console.log("  'mintSBT(address,uint256,string,bytes)' \\");
        console.log("  ", deployer, " \\");
        console.log("  1 \\");
        console.log("  'ipfs://QmTest' \\");
        console.log("  '0x<signature_from_backend_issuer>' \\");
        console.log("  --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console.log("  --private-key $PRIVATE_KEY");
        console.log("\n# Mint companion for SBT");
        console.log("cast send", vm.toString(address(premiumMerch)), "\\");
        console.log("  'mintCompanion(uint256,address,address)' \\");
        console.log("  0 \\");
        console.log("  ", deployer, " \\");
        console.log("  ", deployer, " \\");
        console.log("  --value 0.001ether \\");
        console.log("  --rpc-url $BASE_SEPOLIA_RPC_URL \\");
        console.log("  --private-key $PRIVATE_KEY");
        console.log("===========================================");
        console.log("\nNext Steps:");
        console.log("1. Verify contracts on BaseScan (see verify-contracts.sh)");
        console.log("2. Set up backend to generate signatures for SBT minting");
        console.log("3. Configure metadata base URIs if needed");
        console.log("4. Test the full flow: mint SBT -> mint companion (SBT retained)");
        console.log("5. Set up EAS attestations for attendance tracking");
        console.log("===========================================");
    }
    
    function saveDeploymentAddresses(address deployer, address treasury) internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "base-sepolia",\n',
            '  "chainId": 84532,\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "treasury": "', vm.toString(treasury), '",\n',
            '  "backendIssuer": "', vm.toString(backendIssuer), '",\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "contracts": {\n',
            '    "basicMerch": "', vm.toString(address(basicMerch)), '",\n',
            '    "premiumMerch": "', vm.toString(address(premiumMerch)), '",\n',
            '    "easIntegration": "', vm.toString(address(easIntegration)), '",\n',
            '    "merchManager": "', vm.toString(address(merchManager)), '"\n',
            '  },\n',
            '  "configuration": {\n',
            '    "upgradeFee": "', vm.toString(UPGRADE_FEE), '",\n',
            '    "treasurySplit": ', vm.toString(TREASURY_SPLIT), ',\n',
            '    "organizerSplit": ', vm.toString(ORGANIZER_SPLIT), ',\n',
            '    "signatureBasedMinting": true,\n',
            '    "sbtRetention": true\n',
            '  }\n',
            '}'
        ));
        
        vm.writeFile("deployments/base-sepolia.json", json);
        console.log("\nDeployment data saved to: deployments/base-sepolia.json");
    }
}