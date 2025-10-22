// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/**
 * @title VerifyContracts
 * @notice Script to print verification commands for all Merch MVP contracts on BaseScan
 * @dev Reads deployment addresses from deployments/base-sepolia.json
 * @dev Run with: forge script script/VerifyContracts.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL
 */
contract VerifyContracts is Script {
    
    function run() external view {
        // Read deployment file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/base-sepolia.json");
        string memory json = vm.readFile(path);
        
        // Parse addresses from JSON
        address basicMerch = vm.parseJsonAddress(json, ".contracts.basicMerch");
        address premiumMerch = vm.parseJsonAddress(json, ".contracts.premiumMerch");
        address easIntegration = vm.parseJsonAddress(json, ".contracts.easIntegration");
        address merchManager = vm.parseJsonAddress(json, ".contracts.merchManager");
        address deployer = vm.parseJsonAddress(json, ".deployer");
        address treasury = vm.parseJsonAddress(json, ".treasury");
        
        console.log("===========================================");
        console.log("Merch MVP - Verification Commands");
        console.log("===========================================");
        console.log("");
        console.log("Contract Addresses:");
        console.log("  BasicMerch:    ", basicMerch);
        console.log("  PremiumMerch:  ", premiumMerch);
        console.log("  EASIntegration:", easIntegration);
        console.log("  MerchManager:  ", merchManager);
        console.log("");
        console.log("===========================================");
        console.log("COPY AND RUN THESE COMMANDS");
        console.log("===========================================");
        console.log("");
        
        // First load environment
        console.log("# Load environment variables");
        console.log("source .env");
        console.log("");
        
        // BasicMerch
        console.log("# [1/4] BasicMerch");
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(string,string)' 'Basic Merch SBT' 'BMSBT') \\");
        console.log(string.concat("  ", vm.toString(basicMerch), " \\"));
        console.log("  src/BasicMerch.sol:BasicMerch");
        console.log("");
        
        // PremiumMerch - FIXED: No spaces after =
        console.log("# [2/4] PremiumMerch");
        console.log(string.concat("BASIC=", vm.toString(basicMerch)));
        console.log(string.concat("TREASURY=", vm.toString(treasury)));
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(string,string,address,address,uint256)' \\");
        console.log("    'Premium Merch NFT' 'PMNFT' $BASIC $TREASURY 1000000000000000) \\");
        console.log(string.concat("  ", vm.toString(premiumMerch), " \\"));
        console.log("  src/PremiumMerch.sol:PremiumMerch");
        console.log("");
        
        // EASIntegration - FIXED: No spaces after =
        console.log("# [3/4] EASIntegration");
        console.log(string.concat("DEPLOYER=", vm.toString(deployer)));
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address)' $DEPLOYER) \\");
        console.log(string.concat("  ", vm.toString(easIntegration), " \\"));
        console.log("  src/EASIntegration.sol:EASIntegration");
        console.log("");
        
        // MerchManager - FIXED: No spaces after =
        console.log("# [4/4] MerchManager");
        console.log(string.concat("BASIC=", vm.toString(basicMerch)));
        console.log(string.concat("PREMIUM=", vm.toString(premiumMerch)));
        console.log(string.concat("EAS=", vm.toString(easIntegration)));
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address,address,address)' \\");
        console.log("    $BASIC $PREMIUM $EAS) \\");
        console.log(string.concat("  ", vm.toString(merchManager), " \\"));
        console.log("  src/MerchManager.sol:MerchManager");
        console.log("");
        
        console.log("===========================================");
        console.log("View on BaseScan:");
        console.log(string.concat("https://sepolia.basescan.org/address/", vm.toString(basicMerch)));
        console.log(string.concat("https://sepolia.basescan.org/address/", vm.toString(premiumMerch)));
        console.log(string.concat("https://sepolia.basescan.org/address/", vm.toString(easIntegration)));
        console.log(string.concat("https://sepolia.basescan.org/address/", vm.toString(merchManager)));
    }
}
