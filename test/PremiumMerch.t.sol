// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BasicMerch.sol";
import "../src/PremiumMerch.sol";

contract PremiumMerchTest is Test {
    BasicMerch public basicMerch;
    PremiumMerch public premiumMerch;
    
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    address public treasury;
    
    // Events
    event SBTUpgraded(address indexed user, uint256 indexed sbtId, uint256 indexed premiumId, uint256 fee);
    event FeeDistributed(address indexed organizer, uint256 treasuryAmount, uint256 organizerAmount);
    event ExcessRefunded(address indexed user, uint256 amount);
    event UpgradeFeeSet(uint256 newFee);
    event TreasurySet(address indexed newTreasury);
    event FeeSplitSet(uint256 treasurySplit, uint256 organizerSplit);
    
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
    
    function testInitialConfiguration() public {
        assertEq(premiumMerch.upgradeFee(), 0.01 ether);
        assertEq(premiumMerch.treasury(), treasury);
        assertEq(premiumMerch.treasurySplit(), 3750); // 37.5%
        assertEq(premiumMerch.organizerSplit(), 6250); // 62.5%
        assertEq(address(premiumMerch.basicMerchContract()), address(basicMerch));
    }
    
    function testUpgradeSuccess() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 organizerBalanceBefore = user2.balance;
        
        vm.expectEmit(true, true, true, true);
        emit SBTUpgraded(user1, tokenId, 0, 0.01 ether);
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
        
        // Verify SBT burned
        vm.expectRevert();
        basicMerch.ownerOf(tokenId);
        
        // Verify Premium minted
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        assertEq(premiumMerch.ownerOf(premiumId), user1);
        
        // Verify fee split (37.5% / 62.5%)
        uint256 expectedTreasuryAmount = (0.01 ether * 3750) / 10000;
        uint256 expectedOrganizerAmount = (0.01 ether * 6250) / 10000;
        
        assertEq(treasury.balance - treasuryBalanceBefore, expectedTreasuryAmount);
        assertEq(user2.balance - organizerBalanceBefore, expectedOrganizerAmount);
        
        // Verify mapping
        assertEq(premiumMerch.getPremiumTokenId(tokenId), premiumId);
        assertTrue(premiumMerch.isSBTUpgraded(tokenId));
    }
    
    function testUpgradeWithExcessRefund() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        uint256 user1BalanceBefore = user1.balance;
        uint256 excessAmount = 0.005 ether;
        
        vm.expectEmit(true, false, false, true);
        emit ExcessRefunded(user1, excessAmount);
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.015 ether}(tokenId, user2, user1);
        
        // Verify user got refund
        assertEq(user1.balance, user1BalanceBefore - 0.01 ether);
    }
    
    function testUpgradeInsufficientFeeFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert(PremiumMerch.InsufficientFee.selector);
        premiumMerch.upgradeSBT{value: 0.005 ether}(tokenId, user2, user1);
    }
    
    function testUpgradeNotOwnerFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user2, 1 ether);
        
        vm.prank(user2);
        vm.expectRevert(PremiumMerch.SBTNotOwned.selector);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user2);
    }
    
    function testUpgradeZeroOrganizerFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert(PremiumMerch.InvalidAddress.selector);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, address(0), user1);
    }
    
    function testDoubleUpgradeFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
        
        vm.prank(user1);
        vm.expectRevert(PremiumMerch.SBTAlreadyUpgraded.selector);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
    }
    
    function testUpgradeNonExistentSBTFails() public {
        vm.deal(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert(PremiumMerch.SBTNotOwned.selector);
        premiumMerch.upgradeSBT{value: 0.01 ether}(999, user2, user1);
    }
    
    function testSetUpgradeFee() public {
        uint256 newFee = 0.02 ether;
        
        vm.expectEmit(false, false, false, true);
        emit UpgradeFeeSet(newFee);
        
        premiumMerch.setUpgradeFee(newFee);
        assertEq(premiumMerch.upgradeFee(), newFee);
    }
    
    function testSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.expectEmit(true, false, false, false);
        emit TreasurySet(newTreasury);
        
        premiumMerch.setTreasury(newTreasury);
        assertEq(premiumMerch.treasury(), newTreasury);
    }
    
    function testSetTreasuryZeroAddressFails() public {
        vm.expectRevert(PremiumMerch.InvalidAddress.selector);
        premiumMerch.setTreasury(address(0));
    }
    
    function testSetFeeSplit() public {
        uint256 newTreasurySplit = 5000; // 50%
        uint256 newOrganizerSplit = 5000; // 50%
        
        vm.expectEmit(false, false, false, true);
        emit FeeSplitSet(newTreasurySplit, newOrganizerSplit);
        
        premiumMerch.setFeeSplit(newTreasurySplit, newOrganizerSplit);
        
        assertEq(premiumMerch.treasurySplit(), newTreasurySplit);
        assertEq(premiumMerch.organizerSplit(), newOrganizerSplit);
    }
    
    function testSetFeeSplitInvalidSumFails() public {
        vm.expectRevert(PremiumMerch.InvalidFeeSplit.selector);
        premiumMerch.setFeeSplit(3000, 4000); // Sum is 7000, not 10000
    }
    
    function testSetFeeSplitZeroSplitFails() public {
        vm.expectRevert(PremiumMerch.InvalidFeeSplit.selector);
        premiumMerch.setFeeSplit(0, 10000);
        
        vm.expectRevert(PremiumMerch.InvalidFeeSplit.selector);
        premiumMerch.setFeeSplit(10000, 0);
    }
    
    function testPauseUnpause() public {
        assertFalse(premiumMerch.paused());
        
        premiumMerch.pause();
        assertTrue(premiumMerch.paused());
        
        premiumMerch.unpause();
        assertFalse(premiumMerch.paused());
    }
    
    function testUpgradeWhilePausedFails() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        
        premiumMerch.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
    }
    
    function testCanUpgradeSBT() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        (bool canUpgrade, string memory reason) = premiumMerch.canUpgradeSBT(tokenId, user1);
        assertTrue(canUpgrade);
        assertEq(reason, "Can upgrade");
        
        // Test after upgrade
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(tokenId, user2, user1);
        
        (canUpgrade, reason) = premiumMerch.canUpgradeSBT(tokenId, user1);
        assertFalse(canUpgrade);
        assertEq(reason, "Already upgraded");
    }
    
    function testCanUpgradeSBTNotOwner() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        (bool canUpgrade, string memory reason) = premiumMerch.canUpgradeSBT(tokenId, user2);
        assertFalse(canUpgrade);
        assertEq(reason, "Not owner");
    }
    
    function testCanUpgradeSBTWhilePaused() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 tokenId = basicMerch.mintSBT(user1, tokenURI);
        
        premiumMerch.pause();
        
        (bool canUpgrade, string memory reason) = premiumMerch.canUpgradeSBT(tokenId, user1);
        assertFalse(canUpgrade);
        assertEq(reason, "Contract paused");
    }
    
    function testSetTokenURI() public {
        string memory tokenURI = "ipfs://QmTest";
        
        vm.prank(minter);
        uint256 sbtId = basicMerch.mintSBT(user1, tokenURI);
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        premiumMerch.upgradeSBT{value: 0.01 ether}(sbtId, user2, user1);
        
        uint256 premiumId = premiumMerch.getCurrentTokenId() - 1;
        
        string memory newTokenURI = "ipfs://QmNewURI";
        premiumMerch.setTokenURI(premiumId, newTokenURI);
        
        assertEq(premiumMerch.tokenURI(premiumId), newTokenURI);
    }
    
    function testSetTokenURINonExistentFails() public {
        vm.expectRevert(PremiumMerch.SBTDoesNotExist.selector);
        premiumMerch.setTokenURI(999, "ipfs://test");
    }
    
    function testEmergencyWithdraw() public {
        // Send ETH to contract
        vm.deal(address(premiumMerch), 1 ether);
        
        uint256 ownerBalanceBefore = address(this).balance;
        
        premiumMerch.emergencyWithdraw();
        
        assertTrue(address(this).balance > ownerBalanceBefore);
        assertEq(address(premiumMerch).balance, 0);
    }
    
    function testEmergencyWithdrawNoFundsFails() public {
        vm.expectRevert(PremiumMerch.NoFundsToWithdraw.selector);
        premiumMerch.emergencyWithdraw();
    }
    
    function testGetBalance() public {
        assertEq(premiumMerch.getBalance(), 0);
        
        vm.deal(address(premiumMerch), 1 ether);
        assertEq(premiumMerch.getBalance(), 1 ether);
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        premiumMerch.setUpgradeFee(0.02 ether);
        
        vm.expectRevert();
        premiumMerch.setTreasury(user2);
        
        vm.expectRevert();
        premiumMerch.setFeeSplit(5000, 5000);
        
        vm.expectRevert();
        premiumMerch.setBasicMerchContract(user2);
        
        vm.expectRevert();
        premiumMerch.pause();
        
        vm.expectRevert();
        premiumMerch.emergencyWithdraw();
        
        vm.stopPrank();
    }
    
    // Receive function to accept ETH in emergency withdraw test
    receive() external payable {}
}