// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BadgeNFT} from "../src/BadgeNFT.sol";

contract BadgeNFTTest is Test {
    BadgeNFT public badge;
    
    address owner = address(this);
    address minter = address(0x1);
    address agent = address(0x2);
    address agent2 = address(0x3);
    
    function setUp() public {
        badge = new BadgeNFT();
    }
    
    function test_InitialState() public view {
        assertEq(badge.name(), "ReputeStack Badge");
        assertEq(badge.symbol(), "REPBADGE");
        assertEq(badge.owner(), owner);
        assertTrue(badge.authorizedMinters(owner));
    }
    
    function test_AuthorizeMinter() public {
        badge.authorizeMinter(minter);
        assertTrue(badge.authorizedMinters(minter));
    }
    
    function test_RevokeMinter() public {
        badge.authorizeMinter(minter);
        badge.revokeMinter(minter);
        assertFalse(badge.authorizedMinters(minter));
    }
    
    function test_MintBadge() public {
        uint256 tokenId = badge.mintBadge(
            agent,
            BadgeNFT.BadgeType.FirstTask,
            "ipfs://badge/firsttask"
        );
        
        assertEq(tokenId, 0);
        assertEq(badge.ownerOf(tokenId), agent);
        assertEq(badge.balanceOf(agent), 1);
        assertTrue(badge.hasBadge(agent, BadgeNFT.BadgeType.FirstTask));
    }
    
    function test_MintMultipleBadgeTypes() public {
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        badge.mintBadge(agent, BadgeNFT.BadgeType.TenTasks, "ipfs://2");
        badge.mintBadge(agent, BadgeNFT.BadgeType.PerfectStreak, "ipfs://3");
        
        assertEq(badge.balanceOf(agent), 3);
        
        uint256[] memory agentBadges = badge.getAgentBadges(agent);
        assertEq(agentBadges.length, 3);
    }
    
    function test_RevertWhen_DuplicateBadge() public {
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        
        vm.expectRevert("Badge already earned");
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://2");
    }
    
    function test_DifferentAgentsSameBadge() public {
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        badge.mintBadge(agent2, BadgeNFT.BadgeType.FirstTask, "ipfs://2");
        
        assertTrue(badge.hasBadge(agent, BadgeNFT.BadgeType.FirstTask));
        assertTrue(badge.hasBadge(agent2, BadgeNFT.BadgeType.FirstTask));
        assertEq(badge.balanceOf(agent), 1);
        assertEq(badge.balanceOf(agent2), 1);
    }
    
    function test_RevertWhen_UnauthorizedMinter() public {
        vm.prank(minter);
        vm.expectRevert("Not authorized");
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
    }
    
    function test_GetBadge() public {
        uint256 tokenId = badge.mintBadge(
            agent,
            BadgeNFT.BadgeType.TenTasks,
            "ipfs://tentasks"
        );
        
        BadgeNFT.Badge memory b = badge.getBadge(tokenId);
        assertEq(uint(b.badgeType), uint(BadgeNFT.BadgeType.TenTasks));
        assertEq(b.metadataUri, "ipfs://tentasks");
        assertGt(b.earnedAt, 0);
    }
    
    function test_TokenURI() public {
        uint256 tokenId = badge.mintBadge(
            agent,
            BadgeNFT.BadgeType.Elite,
            "ipfs://elite-badge"
        );
        
        assertEq(badge.tokenURI(tokenId), "ipfs://elite-badge");
    }
    
    function test_Transfer() public {
        uint256 tokenId = badge.mintBadge(
            agent,
            BadgeNFT.BadgeType.FirstTask,
            "ipfs://1"
        );
        
        vm.prank(agent);
        badge.transferFrom(agent, agent2, tokenId);
        
        assertEq(badge.ownerOf(tokenId), agent2);
        assertEq(badge.balanceOf(agent), 0);
        assertEq(badge.balanceOf(agent2), 1);
    }
    
    function test_Approve() public {
        uint256 tokenId = badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        
        vm.prank(agent);
        badge.approve(minter, tokenId);
        
        assertEq(badge.getApproved(tokenId), minter);
        
        // Approved address can transfer
        vm.prank(minter);
        badge.transferFrom(agent, agent2, tokenId);
        
        assertEq(badge.ownerOf(tokenId), agent2);
    }
    
    function test_SetApprovalForAll() public {
        badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        badge.mintBadge(agent, BadgeNFT.BadgeType.TenTasks, "ipfs://2");
        
        vm.prank(agent);
        badge.setApprovalForAll(minter, true);
        
        assertTrue(badge.isApprovedForAll(agent, minter));
        
        // Operator can transfer any token
        vm.prank(minter);
        badge.transferFrom(agent, agent2, 0);
        
        assertEq(badge.ownerOf(0), agent2);
    }
    
    function test_SupportsInterface() public view {
        assertTrue(badge.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(badge.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertTrue(badge.supportsInterface(0x01ffc9a7)); // ERC165
    }
    
    function test_RevertWhen_TransferNotApproved() public {
        uint256 tokenId = badge.mintBadge(agent, BadgeNFT.BadgeType.FirstTask, "ipfs://1");
        
        vm.prank(minter);
        vm.expectRevert("Not authorized");
        badge.transferFrom(agent, agent2, tokenId);
    }
    
    function test_TransferOwnership() public {
        address newOwner = address(0x99);
        badge.transferOwnership(newOwner);
        assertEq(badge.owner(), newOwner);
    }
}
