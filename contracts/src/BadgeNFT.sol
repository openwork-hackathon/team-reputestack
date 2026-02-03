// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BadgeNFT
 * @notice Achievement badge NFTs for AI agents
 * @dev ERC-721 tokens representing reputation milestones
 */
contract BadgeNFT {
    // Token data
    string public name = "ReputeStack Badge";
    string public symbol = "REPBADGE";
    
    // Badge type enumeration
    enum BadgeType {
        FirstTask,      // Complete first task
        TenTasks,       // Complete 10 tasks
        HundredTasks,   // Complete 100 tasks
        PerfectStreak,  // 10 successes in a row
        Specialist,     // 50 tasks in one category
        Trusted,        // Reach level 10
        Elite           // Reach level 50
    }
    
    // Badge metadata
    struct Badge {
        BadgeType badgeType;
        uint256 earnedAt;
        string metadataUri;
    }
    
    // Storage
    uint256 private _tokenIdCounter;
    mapping(uint256 => Badge) public badges;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // Track which badges an agent has earned (prevent duplicates)
    mapping(address => mapping(BadgeType => bool)) public hasBadge;
    mapping(address => uint256[]) public agentBadges;
    
    // Authorized minters (reputation registry)
    mapping(address => bool) public authorizedMinters;
    address public owner;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event BadgeMinted(address indexed recipient, uint256 indexed tokenId, BadgeType badgeType);
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedMinters[msg.sender] = true;
    }
    
    /**
     * @notice Mint a badge to an agent
     * @param recipient Agent wallet address
     * @param badgeType Type of badge to mint
     * @param metadataUri URI for badge metadata
     * @return tokenId The minted token ID
     */
    function mintBadge(
        address recipient,
        BadgeType badgeType,
        string calldata metadataUri
    ) external onlyAuthorized returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(!hasBadge[recipient][badgeType], "Badge already earned");
        
        uint256 tokenId = _tokenIdCounter++;
        
        badges[tokenId] = Badge({
            badgeType: badgeType,
            earnedAt: block.timestamp,
            metadataUri: metadataUri
        });
        
        _owners[tokenId] = recipient;
        _balances[recipient]++;
        hasBadge[recipient][badgeType] = true;
        agentBadges[recipient].push(tokenId);
        
        emit Transfer(address(0), recipient, tokenId);
        emit BadgeMinted(recipient, tokenId, badgeType);
        
        return tokenId;
    }
    
    /**
     * @notice Get all badge token IDs for an agent
     * @param agentWallet Agent wallet address
     * @return Array of token IDs
     */
    function getAgentBadges(address agentWallet) external view returns (uint256[] memory) {
        return agentBadges[agentWallet];
    }
    
    /**
     * @notice Get badge details
     * @param tokenId Token ID
     * @return Badge struct
     */
    function getBadge(uint256 tokenId) external view returns (Badge memory) {
        require(_owners[tokenId] != address(0), "Badge does not exist");
        return badges[tokenId];
    }
    
    // ERC-721 Standard Functions
    
    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0), "Invalid address");
        return _balances[_owner];
    }
    
    function ownerOf(uint256 tokenId) external view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token does not exist");
        return tokenOwner;
    }
    
    function approve(address to, uint256 tokenId) external {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || _operatorApprovals[tokenOwner][msg.sender], "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }
    
    function getApproved(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenApprovals[tokenId];
    }
    
    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address _owner, address operator) external view returns (bool) {
        return _operatorApprovals[_owner][operator];
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        require(from == _owners[tokenId], "Wrong owner");
        require(to != address(0), "Invalid recipient");
        
        _tokenApprovals[tokenId] = address(0);
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        this.transferFrom(from, to, tokenId);
    }
    
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata) external {
        this.transferFrom(from, to, tokenId);
    }
    
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return badges[tokenId].metadataUri;
    }
    
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd || // ERC721
               interfaceId == 0x5b5e139f || // ERC721Metadata
               interfaceId == 0x01ffc9a7;   // ERC165
    }
    
    // Admin functions
    
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }
    
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
    
    // Internal
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _owners[tokenId];
        return (spender == tokenOwner || 
                _tokenApprovals[tokenId] == spender || 
                _operatorApprovals[tokenOwner][spender]);
    }
}
