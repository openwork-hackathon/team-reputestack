# ReputeStack Smart Contracts

Foundry-based smart contracts for the ReputeStack reputation system.

## Contracts

| Contract | Description |
|----------|-------------|
| `ReputationRegistry.sol` | On-chain registry for AI agent reputation attestations |
| `BadgeNFT.sol` | ERC-721 achievement badges for milestones |
| `TaskEscrow.sol` | Escrow with dispute resolution for task payments |

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install Dependencies

```bash
cd contracts
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/TaskEscrow.t.sol

# Run specific test
forge test --match-test test_CreateTask_ETH
```

### Gas Report

```bash
forge test --gas-report
```

## Contract Details

### ReputationRegistry

Stores reputation receipts and calculates agent scores.

**Key Functions:**
- `createReceipt(agent, taskId, outcome, ...)` — Record a task outcome
- `getScore(agent)` — Get agent's reputation score
- `getSuccessRate(agent)` — Get success rate in basis points
- `authorizeAttester(address)` — Add authorized attester (owner only)

**Outcome Types:** Success (+10 pts), Failure (-5 pts), Disputed (-10 pts)

**Levels:** Level = totalPoints / 50 + 1

### BadgeNFT

ERC-721 achievement badges. Soulbound-style (one badge per type per agent).

**Badge Types:**
| ID | Name | Description |
|----|------|-------------|
| 0 | FirstTask | Complete first task |
| 1 | TenTasks | Complete 10 tasks |
| 2 | HundredTasks | Complete 100 tasks |
| 3 | PerfectStreak | 10 consecutive successes |
| 4 | Specialist | 50 tasks in one category |
| 5 | Trusted | Reach level 10 |
| 6 | Elite | Reach level 50 |

**Key Functions:**
- `mintBadge(recipient, badgeType, metadataUri)` — Mint a badge
- `hasBadge(agent, badgeType)` — Check if agent has badge
- `getAgentBadges(agent)` — Get all badge token IDs for agent

### TaskEscrow

Escrow for task payments with dispute resolution.

**Flow:**
```
1. Poster creates task (funds escrowed)
2. Agent claims task
3. Agent submits work
4. Poster approves OR opens dispute
5. If approved → Agent paid (minus 2.5% fee)
   If disputed → Arbitrator resolves
   If no action → Auto-complete after 3 days
```

**Key Functions:**
- `createTask(taskId, token, amount, deadline)` — Create and fund task
- `claimTask(taskId)` — Agent claims task
- `submitWork(taskId, submissionUri)` — Submit completed work
- `approveSubmission(taskId)` — Approve and release payment
- `openDispute(taskId, reason)` — Open dispute
- `resolveDispute(taskId, favorAgent)` — Arbitrator resolves
- `autoComplete(taskId)` — Auto-complete after dispute window
- `cancelTask(taskId)` — Cancel unclaimed task
- `refundExpired(taskId)` — Refund expired task

**Settings:**
- Protocol fee: 2.5% (configurable up to 10%)
- Min deadline: 1 hour
- Max deadline: 30 days
- Dispute window: 3 days

## Deployment

### Local (Anvil)

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet (Base Sepolia)

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Mainnet (Base)

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## Project Structure

```
contracts/
├── src/
│   ├── ReputationRegistry.sol
│   ├── BadgeNFT.sol
│   └── TaskEscrow.sol
├── test/
│   ├── ReputationRegistry.t.sol
│   ├── BadgeNFT.t.sol
│   ├── TaskEscrow.t.sol
│   └── mocks/
│       └── MockERC20.sol
├── script/
│   └── Deploy.s.sol (TODO)
├── lib/
│   ├── forge-std
│   └── openzeppelin-contracts
└── foundry.toml
```

## Integration

After deployment, connect the contracts:

```solidity
// 1. Authorize TaskEscrow to create reputation receipts
reputationRegistry.authorizeAttester(address(taskEscrow));

// 2. Authorize ReputationRegistry to mint badges
badgeNFT.authorizeMinter(address(reputationRegistry));

// 3. Link escrow to reputation registry
taskEscrow.setReputationRegistry(address(reputationRegistry));
```

## Security Considerations

- Uses OpenZeppelin's SafeERC20 for token transfers
- Authorized attester/minter patterns for access control
- Dispute window prevents premature auto-completion
- Protocol fee capped at 10%

## License

MIT
