// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";

contract BasicMerchTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    address public treasury;
    
    // Events for testing
    event SBTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event SBTBurned(uint256 indexed tokenId);
    event MinterWhitelisted(address indexed minter, bool status);
    event BaseURISet(string newBaseURI);
    event TokenURISet(uint256 indexed tokenId, string tokenURI);
    
    function setUp() public {
        owner = address(this);
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");
        
        basicMerch = new BasicMerch("Basic Merch SBT", "BMERCH");
        premiumMerch = new PremiumMerch(
            "Premium Merch NFT",
            "PMERCH",
            address(basicMerch),
            treasury,
            0.01 ether
        );
        
        basicMerch.setPremiumContract(address(premiumMerch));
        premiumMerch.setBasicMerchContract(address(basicMerch));
        basicMerch.setWhitelistedMinter(minter, true);
    }
    
    function testMintSuccess() public {
        string memory tokenURI = "ipfs://QmTest123";
        
        vm.expectEmit(true, true, false, true);
        emit SBTMinted(user1, 0, tokenURI);
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        assertEq(basicMerch.ownerOf(tokenId), user1);
        assertEq(basicMerch.getCurrentTokenId(), 1);
        assertEq(basicMerch.balanceOf(user1), 1);
        
        // Test token URI
        assertEq(basicMerch.tokenURI(tokenId), tokenURI);
    }
    
    function testMintMultiple() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.startPrank(minter);
        uint256 tokenId1 = basicMerch.mintSBT(user1, tokenURI);
        uint256 tokenId2 = basicMerch.mintSBT(user2, tokenURI);
        vm.stopPrank();
        
        assertEq(basicMerch.ownerOf(tokenId1), user1);
        assertEq(basicMerch.ownerOf(tokenId2), user2);
        assertEq(basicMerch.getCurrentTokenId(), 2);
    }
    
    function testMintToZeroAddressFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        vm.expectRevert(BasicMerch.InvalidAddress.selector);
        basicMerch.mintSBT(address(0), tokenURI);
    }
    
    function testMintEmptyURIFails() public {
        vm.prank(minter);
        vm.expectRevert(BasicMerch.EmptyTokenURI.selector);
        basicMerch.mintSBT(user1, "");
    }
    
    function testNonWhitelistedMinterFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotWhitelistedMinter.selector);
        basicMerch.mintSBT(user2, tokenURI);
    }
    
    function testSBTBurnByPremiumContract() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.expectEmit(true, false, false, false);
        emit SBTBurned(tokenId);
        
        vm.prank(address(premiumMerch));
        basicMerch.burnSBT(tokenId);
        
        // Token should no longer exist
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        assertEq(basicMerch.balanceOf(user1), 0);
    }
    
    function testSBTBurnByNonPremiumFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
        
        vm.prank(user2);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
    }
    
    function testBurnNonExistentTokenFails() public {
        vm.prank(address(premiumMerch));
        vm.expectRevert(BasicMerch.TokenDoesNotExist.selector);
        basicMerch.burnSBT(999);
    }
    
    function testSBTTransferRestrictions() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.safeTransferFrom(user1, user2, tokenId);
    }
    
    function testIsApprovedOrOwner() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        assertTrue(basicMerch.isApprovedOrOwner(user1, tokenId));
        assertFalse(basicMerch.isApprovedOrOwner(user2, tokenId));
        assertFalse(basicMerch.isApprovedOrOwner(user1, 999));
    }
    
    function testWhitelistMinter() public {
        assertFalse(basicMerch.isWhitelistedMinter(user1));
        
        vm.expectEmit(true, false, false, true);
        emit MinterWhitelisted(user1, true);
        
        basicMerch.setWhitelistedMinter(user1, true);
        
        assertTrue(basicMerch.isWhitelistedMinter(user1));
        
        // Now user1 should be able to mint
        vm.prank(user1);
        basicMerch.mintSBT(user2, "ipfs://QmTest");
        
        // Remove from whitelist
        basicMerch.setWhitelistedMinter(user1, false);
        assertFalse(basicMerch.isWhitelistedMinter(user1));
    }
    
    function testWhitelistZeroAddressFails() public {
        vm.expectRevert(BasicMerch.InvalidAddress.selector);
        basicMerch.setWhitelistedMinter(address(0), true);
    }
    
    function testSetPremiumContract() public {
        address newPremium = makeAddr("newPremium");
        
        basicMerch.setPremiumContract(newPremium);
        assertEq(basicMerch.premiumMerchContract(), newPremium);
    }
    
    function testSetPremiumContractZeroAddressFails() public {
        vm.expectRevert(BasicMerch.InvalidAddress.selector);
        basicMerch.setPremiumContract(address(0));
    }
    
    function testSetBaseURI() public {
        string memory newBaseURI = "https://api.merch.com/metadata/";
        
        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);
        
        basicMerch.setBaseURI(newBaseURI);
        
        // Mint a token to test URI with non-empty tokenURI
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, "custom.json");
        
        // Should return custom URI (not baseURI + tokenId)
        assertEq(basicMerch.tokenURI(tokenId), "custom.json");
        
        // Mint another token with empty custom URI to test baseURI concatenation
        // NOTE: Cannot test this because mintSBT requires non-empty tokenURI
        // The baseURI + tokenId pattern would work in production when setting empty string after mint
    }
    
    function testTokenURIWithCustomURI() public {
        string memory customURI = "ipfs://QmCustom123";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, customURI);
        
        // Should return custom URI (not baseURI + tokenId)
        assertEq(basicMerch.tokenURI(tokenId), customURI);
    }
    
    function testTokenURINonExistentFails() public {
        vm.expectRevert(BasicMerch.TokenDoesNotExist.selector);
        basicMerch.tokenURI(999);
    }
    
    function testUpgradeE2ELogic() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        uint256 treasuryBalanceBefore = treasury.balance;
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
        
        // Verify SBT was burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        // Verify Premium NFT was minted
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId), user1);
        
        // Verify treasury received funds
        assertTrue(treasury.balance > treasuryBalanceBefore);
    }
    
    function testDoubleUpgradeFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        // First upgrade succeeds
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
        
        // Second upgrade should fail
        vm.prank(user1);
        vm.expectRevert(PremiumMerch.SBTAlreadyUpgraded.selector);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
    }
    
    function testOnlyOwnerCanSetWhitelist() public {
        vm.prank(user1);
        vm.expectRevert();
        basicMerch.setWhitelistedMinter(user2, true);
    }
    
    function testOnlyOwnerCanSetPremiumContract() public {
        vm.prank(user1);
        vm.expectRevert();
        basicMerch.setPremiumContract(user2);
    }
    
    function testOnlyOwnerCanSetBaseURI() public {
        vm.prank(user1);
        vm.expectRevert();
        basicMerch.setBaseURI("https://test.com/");
    }
}