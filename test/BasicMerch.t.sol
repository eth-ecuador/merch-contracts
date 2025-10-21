// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";

contract BasicMerchTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    
    address public owner;
    address public backendIssuer;
    address public user1;
    address public user2;
    address public treasury;
    
    // Events for testing
    event SBTMinted(address indexed to, uint256 indexed tokenId, uint256 indexed eventId, string tokenURI);
    event BackendIssuerSet(address indexed issuer);
    event BaseURISet(string newBaseURI);
    event TokenURISet(uint256 indexed tokenId, string tokenURI);
    
    function setUp() public {
        owner = address(this);
        backendIssuer = makeAddr("backendIssuer");
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
        
        basicMerch.setBackendIssuer(backendIssuer);
    }
    
    /**
     * @dev Helper function to generate signature for minting
     */
    function _generateSignature(
        address _to,
        uint256 _eventId,
        string memory _tokenURI
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(_to, _eventId, _tokenURI));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(backendIssuer)), ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }
    
    function testMintSuccess() public {
        string memory tokenURI = "ipfs://QmTest123";
        uint256 eventId = 1;
        
        bytes memory signature = _generateSignature(user1, eventId, tokenURI);
        
        vm.expectEmit(true, true, true, true);
        emit SBTMinted(user1, 0, eventId, tokenURI);
        
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, tokenURI, signature);
        
        assertEq(basicMerch.ownerOf(tokenId), user1);
        assertEq(basicMerch.getCurrentTokenId(), 1);
        assertEq(basicMerch.balanceOf(user1), 1);
        assertEq(basicMerch.getSBTByEvent(user1, eventId), tokenId);
        assertEq(basicMerch.getEventIdByToken(tokenId), eventId);
        
        // Test token URI
        assertEq(basicMerch.tokenURI(tokenId), tokenURI);
    }
    
    function testMintMultiple() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId1 = 1;
        uint256 eventId2 = 2;
        
        bytes memory signature1 = _generateSignature(user1, eventId1, tokenURI);
        bytes memory signature2 = _generateSignature(user2, eventId2, tokenURI);
        
        uint256 tokenId1 = basicMerch.mintSBT(user1, eventId1, tokenURI, signature1);
        uint256 tokenId2 = basicMerch.mintSBT(user2, eventId2, tokenURI, signature2);
        
        assertEq(basicMerch.ownerOf(tokenId1), user1);
        assertEq(basicMerch.ownerOf(tokenId2), user2);
        assertEq(basicMerch.getCurrentTokenId(), 2);
        assertEq(basicMerch.getSBTByEvent(user1, eventId1), tokenId1);
        assertEq(basicMerch.getSBTByEvent(user2, eventId2), tokenId2);
    }
    
    function testMintToZeroAddressFails() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(address(0), eventId, tokenURI);
        
        vm.expectRevert(BasicMerch.InvalidAddress.selector);
        basicMerch.mintSBT(address(0), eventId, tokenURI, signature);
    }
    
    function testMintEmptyURIFails() public {
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, "");
        
        vm.expectRevert(BasicMerch.EmptyTokenURI.selector);
        basicMerch.mintSBT(user1, eventId, "", signature);
    }
    
    function testInvalidSignatureFails() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        bytes memory invalidSignature = "invalid_signature";
        
        vm.expectRevert(BasicMerch.InvalidSignature.selector);
        basicMerch.mintSBT(user1, eventId, tokenURI, invalidSignature);
    }
    
    function testDuplicateEventMintFails() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        
        bytes memory signature1 = _generateSignature(user1, eventId, tokenURI);
        bytes memory signature2 = _generateSignature(user1, eventId, tokenURI);
        
        // First mint should succeed
        basicMerch.mintSBT(user1, eventId, tokenURI, signature1);
        
        // Second mint for same user+event should fail
        vm.expectRevert(BasicMerch.DuplicateEventMint.selector);
        basicMerch.mintSBT(user1, eventId, tokenURI, signature2);
    }
    
    function testSBTTransferPrevention() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, tokenURI);
        
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, tokenURI, signature);
        
        // Attempt to transfer should fail
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
    }
    
    function testSBTTransferRestrictions() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, tokenURI);
        
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, tokenURI, signature);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.safeTransferFrom(user1, user2, tokenId);
    }
    
    function testIsApprovedOrOwner() public {
        string memory tokenURI = "ipfs://QmTest";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, tokenURI);
        
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, tokenURI, signature);
        
        assertTrue(basicMerch.isApprovedOrOwner(user1, tokenId));
        assertFalse(basicMerch.isApprovedOrOwner(user2, tokenId));
        assertFalse(basicMerch.isApprovedOrOwner(user1, 999));
    }
    
    function testBackendIssuerSet() public {
        address newIssuer = makeAddr("newIssuer");
        
        vm.expectEmit(true, false, false, false);
        emit BackendIssuerSet(newIssuer);
        
        basicMerch.setBackendIssuer(newIssuer);
        assertEq(basicMerch.backendIssuer(), newIssuer);
    }
    
    function testBackendIssuerZeroAddressFails() public {
        vm.expectRevert(BasicMerch.InvalidAddress.selector);
        basicMerch.setBackendIssuer(address(0));
    }
    
    
    function testSetBaseURI() public {
        string memory newBaseURI = "https://api.merch.com/metadata/";
        
        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);
        
        basicMerch.setBaseURI(newBaseURI);
        
        // Mint a token to test URI with non-empty tokenURI
        string memory customURI = "custom.json";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, customURI);
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, customURI, signature);
        
        // Should return custom URI (not baseURI + tokenId)
        assertEq(basicMerch.tokenURI(tokenId), customURI);
    }
    
    function testTokenURIWithCustomURI() public {
        string memory customURI = "ipfs://QmCustom123";
        uint256 eventId = 1;
        bytes memory signature = _generateSignature(user1, eventId, customURI);
        
        uint256 tokenId = basicMerch.mintSBT(user1, eventId, customURI, signature);
        
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