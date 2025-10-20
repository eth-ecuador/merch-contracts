// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/**
 * @title VerifyContracts
 * @notice Script to print verification commands for all Merch MVP contracts
 * @dev Reads deployment addresses from deployments/base-sepolia.json
 * @dev Run with: forge script script/VerifyContracts.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL -vvvv
 */
contract VerifyContracts is Script {
    
    function run() external view {
        // Read deployment file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/base-sepolia.json");
        
        console.log("===========================================");
        console.log("Verifying Merch MVP Contracts on BaseScan");
        console.log("===========================================");
        console.log("Reading from:", path);
        
        string memory json = vm.readFile(path);
        
        // Parse addresses
        address basicMerch = vm.parseJsonAddress(json, ".contracts.basicMerch");
        address premiumMerch = vm.parseJsonAddress(json, ".contracts.premiumMerch");
        address easIntegration = vm.parseJsonAddress(json, ".contracts.easIntegration");
        address merchManager = vm.parseJsonAddress(json, ".contracts.merchManager");
        address deployer = vm.parseJsonAddress(json, ".deployer");
        address treasury = vm.parseJsonAddress(json, ".treasury");
        
        console.log("\nContract Addresses:");
        console.log("BasicMerch:    ", basicMerch);
        console.log("PremiumMerch:  ", premiumMerch);
        console.log("EASIntegration:", easIntegration);
        console.log("MerchManager:  ", merchManager);
        console.log("Deployer:      ", deployer);
        console.log("Treasury:      ", treasury);
        
        printCommands(basicMerch, premiumMerch, easIntegration, merchManager, deployer, treasury);
    }
    
    function printCommands(
        address basicMerch,
        address premiumMerch,
        address easIntegration,
        address merchManager,
        address deployer,
        address treasury
    ) internal view {
        console.log("\n===========================================");
        console.log("VERIFICATION COMMANDS");
        console.log("===========================================\n");
        
        // BasicMerch
        console.log("# 1. BasicMerch");
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(string,string)' 'Basic Merch SBT' 'BMSBT') \\");
        console.log(" ", basicMerch);
        console.log("  src/BasicMerch.sol:BasicMerch\n");
        
        // PremiumMerch
        console.log("# 2. PremiumMerch");
        console.log("BASIC=", basicMerch);
        console.log("TREASURY=", treasury);
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(string,string,address,address,uint256)' \\");
        console.log("    'Premium Merch NFT' 'PMNFT' $BASIC $TREASURY 1000000000000000) \\");
        console.log(" ", premiumMerch);
        console.log("  src/PremiumMerch.sol:PremiumMerch\n");
        
        // EASIntegration
        console.log("# 3. EASIntegration");
        console.log("DEPLOYER=", deployer);
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address)' $DEPLOYER) \\");
        console.log(" ", easIntegration);
        console.log("  src/EASIntegration.sol:EASIntegration\n");
        
        // MerchManager
        console.log("# 4. MerchManager");
        console.log("PREMIUM=", premiumMerch);
        console.log("EAS=", easIntegration);
        console.log("forge verify-contract --chain-id 84532 --watch \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address,address,address)' \\");
        console.log("    $BASIC $PREMIUM $EAS) \\");
        console.log(" ", merchManager);
        console.log("  src/MerchManager.sol:MerchManager\n");
        
        console.log("===========================================");
        console.log("TIP: Use verify-contracts.sh for automation");
        console.log("===========================================");
    }
}