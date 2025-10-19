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
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        assertEq(basicMerch.ownerOf(tokenId), user1);
        assertEq(basicMerch.getCurrentTokenId(), 1);
        
        vm.prank(minter);
        uint256 tokenId2 = basicMerch.mintSBT(user2, tokenURI);
        assertEq(basicMerch.ownerOf(tokenId2), user2);
        assertEq(basicMerch.getCurrentTokenId(), 2);
    }
    
    function testSBTBurnAccess() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.prank(address(premiumMerch));
        basicMerch.burnSBT(tokenId);
        
        // El token ya no existe, debería revertir con cualquier error de "no existe"
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
    }
    
    function testSBTBurnAccessFailure() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
        
        vm.prank(user2);
        vm.expectRevert(BasicMerch.NotPremiumContract.selector);
        basicMerch.burnSBT(tokenId);
    }
    
    function testUpgradeFeeCheck() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert("Insufficient fee");
        premiumMerch.upgradeSBT{value: 0.005 ether}(tokenId, owner);
    }
    
    function testUpgradeE2ELogic() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        uint256 treasuryBalanceBefore = treasury.balance;
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Verificar que el SBT fue quemado (cualquier error de "no existe" es válido)
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        // Verificar que el Premium NFT fue acuñado
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId), user1);
        
        // Verificar que el treasury recibió fondos
        assertTrue(treasury.balance > treasuryBalanceBefore);
    }
    
    function testDoubleUpgrade() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        // Primer upgrade exitoso
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
        
        // Segundo intento de upgrade debe fallar
        // El SBT ya fue quemado, así que debería revertir con SBTAlreadyUpgraded o SBTDoesNotExist
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2);
    }
    
    function testNonWhitelistedMinter() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.NotWhitelistedMinter.selector);
        basicMerch.mintSBT(user2, tokenURI);
    }
    
    function testSBTTransferRestrictions() public {
        string memory tokenURI = "https://api.merch.com/basic/1";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.prank(user1);
        vm.expectRevert(BasicMerch.TransferNotAllowed.selector);
        basicMerch.transferFrom(user1, user2, tokenId);
    }
}