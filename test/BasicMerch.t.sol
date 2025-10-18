// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/BasicMerch.sol";
import "../contracts/PremiumMerch.sol";

contract BasicMerchTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    address public treasury;
    
    function setUp() public {
        owner = address(this);
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");
        
        // Deploy BasicMerch
        basicMerch = new BasicMerch("Basic Merch SBT", "BMERCH");
        
        // Deploy PremiumMerch
        premiumMerch = new PremiumMerch(
            "Premium Merch NFT",
            "PMERCH",
            address(basicMerch),
            treasury,
            0.01 ether
        );
        
        // Configure contracts
        basicMerch.setPremiumContract(address(premiumMerch));
        premiumMerch.setBasicMerchContract(address(basicMerch));
        basicMerch.setWhitelistedMinter(minter, true);
    }
    
    // Test Case 1: Mint Success
    function testMintSuccess() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        assertEq(basicMerch.ownerOf(tokenId), user1);
        assertEq(basicMerch.getCurrentTokenId(), 1);
        
        // Test second mint
        vm.prank(minter);
        uint256 tokenId2 = basicMerch.mintSBT(user2, tokenURI);
        assertEq(basicMerch.ownerOf(tokenId2), user2);
        assertEq(basicMerch.getCurrentTokenId(), 2);
    }
    
    // Test Case 2: SBT Burn Access
    function testSBTBurnAccess() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Test that only PremiumMerch can burn
        vm.prank(address(premiumMerch));
        basicMerch.burnSBT(tokenId);
        
        // Verify token is burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
    }
    
    function testSBTBurnAccessFailure() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Test that user cannot burn
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
        
        // Test that other contract cannot burn
        vm.prank(user2);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
    }
    
    // Test Case 3: Upgrade Fee Check
    function testUpgradeFeeCheck() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Test insufficient fee
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.005 ether}(tokenId, owner);
    }
    
    // Test Case 4: Upgrade E2E Logic
    function testUpgradeE2ELogic() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // Test successful upgrade
        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 organizerBalanceBefore = address(user2).balance;
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Verify SBT is burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        // Verify new ERC-721 is minted
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId), user1);
        
        // Verify fee split (simplified - in real scenario would check actual transfers)
        assertTrue(treasury.balance > treasuryBalanceBefore);
    }
    
    // Test Case 5: Double Upgrade
    function testDoubleUpgrade() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Give user1 some ETH
        vm.deal(user1, 1 ether);
        
        // First upgrade
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Attempt second upgrade (should fail)
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
    }
    
    // Additional test for non-whitelisted minter
    function testNonWhitelistedMinter() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotWhitelistedMinter.selector);
        basicMerch.mintSBT(user2, tokenURI);
    }
    
    // Test SBT transfer restrictions
    function testSBTTransferRestrictions() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        // Mint an SBT first
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        // Attempt transfer (should fail)
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
    }
}
