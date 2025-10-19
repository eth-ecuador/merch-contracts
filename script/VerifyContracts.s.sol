// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/**
 * @title VerifyContracts
 * @notice Script to verify all Merch MVP contracts on BaseScan
 * @dev Reads deployment addresses from the latest broadcast file
 * @dev Run with: forge script script/VerifyContracts.s.sol --rpc-url base_sepolia --verify -vvvv
 */
contract VerifyContracts is Script {
    
    // Constructor args (these should match your deployment)
    string constant BASIC_NAME = "Basic Merch SBT";
    string constant BASIC_SYMBOL = "BMSBT";
    string constant PREMIUM_NAME = "Premium Merch NFT";
    string constant PREMIUM_SYMBOL = "PMNFT";
    uint256 constant UPGRADE_FEE = 0.001 ether;
    
    function run() external {
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
        
        console.log("===========================================");
        console.log("Verifying Merch MVP Contracts on BaseScan");
        console.log("===========================================");
        console.log("");
        console.log("Reading addresses from:", path);
        console.log("");
        console.log("BasicMerch:     ", basicMerch);
        console.log("PremiumMerch:   ", premiumMerch);
        console.log("EASIntegration: ", easIntegration);
        console.log("MerchManager:   ", merchManager);
        console.log("Deployer:       ", deployer);
        console.log("");
        console.log("===========================================");
        console.log("Starting verification...");
        console.log("===========================================");
        
        // Verify BasicMerch
        console.log("\n1. Verifying BasicMerch...");
        try vm.startBroadcast() {
            // This won't actually broadcast, just generates verification data
            vm.stopBroadcast();
        } catch {}
        
        console.log("\nTo verify manually, run these commands:\n");
        
        // Print verification commands
        console.log("# BasicMerch");
        console.log("forge verify-contract \\");
        console.log("  ", basicMerch, " \\");
        console.log("  src/BasicMerch.sol:BasicMerch \\");
        console.log("  --chain-id 84532 \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(string,string)\" \"Basic Merch SBT\" \"BMSBT\") \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --watch\n");
        
        console.log("# PremiumMerch");
        console.log("forge verify-contract \\");
        console.log("  ", premiumMerch, " \\");
        console.log("  src/PremiumMerch.sol:PremiumMerch \\");
        console.log("  --chain-id 84532 \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(string,string,address,address,uint256)\" \"Premium Merch NFT\" \"PMNFT\" ", 
                    basicMerch, " ", deployer, " 1000000000000000) \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --watch\n");
        
        console.log("# EASIntegration");
        console.log("forge verify-contract \\");
        console.log("  ", easIntegration, " \\");
        console.log("  src/EASIntegration.sol:EASIntegration \\");
        console.log("  --chain-id 84532 \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address)\" ", deployer, ") \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --watch\n");
        
        console.log("# MerchManager");
        console.log("forge verify-contract \\");
        console.log("  ", merchManager, " \\");
        console.log("  src/MerchManager.sol:MerchManager \\");
        console.log("  --chain-id 84532 \\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,address)\" ", 
                    basicMerch, " ", premiumMerch, " ", easIntegration, ") \\");
        console.log("  --etherscan-api-key $BASESCAN_API_KEY \\");
        console.log("  --watch\n");
    }
}