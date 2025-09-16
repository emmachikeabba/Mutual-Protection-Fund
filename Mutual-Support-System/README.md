# Decentralized Mutual Insurance Pool (DMIP) Smart Contract

## Overview

The Decentralized Mutual Insurance Pool (DMIP) is a blockchain-based mutual insurance platform built on Stacks. It enables community members to stake tokens to create a shared insurance pool, earn yield on their contributions, and participate in transparent governance for resolving insurance claims.

## Features

- **Token Staking**: Members can stake STX tokens to join the insurance pool
- **Yield Generation**: Participants earn yield rewards on their staked tokens
- **Insurance Claims**: Pool members can file insurance claims with detailed descriptions
- **Governance**: Claims are processed through administrative oversight
- **Withdrawal System**: Time-locked token withdrawal mechanism
- **Emergency Controls**: Administrative functions for protocol management

## Contract Constants

### Financial Parameters
- **Minimum Participation Stake**: 1,000,000 microSTX (1 STX)
- **Maximum Claim Payout**: 100,000,000 microSTX (100 STX)
- **Token Lock Duration**: 144 blocks
- **Maximum Yield Rate**: 1,000 basis points (10%)
- **Minimum Claim Description**: 5 characters

### Error Codes
- `ERR-ACCESS-DENIED (100)`: Unauthorized access attempt
- `ERR-INSUFFICIENT-BALANCE (101)`: Insufficient funds for operation
- `ERR-PARTICIPANT-NOT-FOUND (102)`: Participant not registered in pool
- `ERR-CLAIM-ALREADY-PROCESSED (103)`: Claim has already been resolved
- `ERR-CLAIM-REJECTED (104)`: Claim was denied
- `ERR-STAKE-BELOW-MINIMUM (105)`: Stake amount below minimum requirement
- `ERR-TOKENS-LOCKED (106)`: Tokens still in lock period
- `ERR-THRESHOLD-INVALID (107)`: Invalid governance threshold
- `ERR-CLAIM-AMOUNT-INVALID (108)`: Invalid claim amount
- `ERR-YIELD-RATE-TOO-HIGH (109)`: Yield rate exceeds maximum
- `ERR-INVALID-PARAMETER (110)`: Invalid parameter provided
- `ERR-DESCRIPTION-TOO-SHORT (111)`: Claim description too short
- `ERR-INVALID-RECIPIENT (112)`: Invalid recipient address
- `ERR-CLAIM-NOT-EXISTS (113)`: Claim does not exist

## Data Structures

### Pool Participants
Stores member information including staked amount, stake start block, and last yield collection block.

### Claim Requests
Manages insurance claims with claimant address, amount, description, submission block, and status.

### Protocol State Variables
- Total pool funds
- Total payouts distributed
- Next available claim ID
- Active yield percentage
- Required consensus percentage

## Core Functions

### Staking Operations

#### `stake-tokens-in-pool (stake-amount uint)`
Stakes STX tokens to join the insurance pool. Minimum stake required.

**Parameters:**
- `stake-amount`: Amount of microSTX to stake

**Returns:**
- Success: Staked amount
- Error: Appropriate error code

#### `withdraw-staked-tokens (withdrawal-amount uint)`
Withdraws staked tokens after lock period expires.

**Parameters:**
- `withdrawal-amount`: Amount of microSTX to withdraw

**Returns:**
- Success: Withdrawn amount
- Error: Appropriate error code

#### `collect-yield-rewards ()`
Collects accumulated yield rewards from staking.

**Returns:**
- Success: Yield amount collected
- Error: Appropriate error code

### Insurance Claims

#### `file-insurance-claim (requested-amount uint) (claim-description (string-utf8 256))`
Submits a new insurance claim to the pool.

**Parameters:**
- `requested-amount`: Claim amount in microSTX
- `claim-description`: Detailed description of the claim

**Returns:**
- Success: Claim ID
- Error: Appropriate error code

#### `process-claim-decision (claim-identifier uint) (approve-claim bool)`
Processes insurance claim resolution (admin only).

**Parameters:**
- `claim-identifier`: ID of the claim to process
- `approve-claim`: Boolean indicating approval or denial

**Returns:**
- Success: Boolean result
- Error: Appropriate error code

### Administrative Functions

#### `set-new-yield-rate (new-rate uint)`
Updates the protocol yield rate (admin only).

**Parameters:**
- `new-rate`: New yield rate in basis points

#### `set-consensus-requirement (new-threshold uint)`
Updates governance consensus threshold (admin only).

**Parameters:**
- `new-threshold`: New threshold percentage

#### `recover-protocol-funds (recovery-amount uint) (recovery-recipient principal)`
Emergency function to recover protocol funds (admin only).

**Parameters:**
- `recovery-amount`: Amount to recover
- `recovery-recipient`: Recipient address

### Read-Only Functions

#### Query Functions
- `fetch-participant-info (participant-address principal)`: Get participant details
- `fetch-claim-details (claim-id uint)`: Get claim information
- `get-current-pool-balance ()`: Get total pool balance
- `get-total-claim-payouts ()`: Get total payouts distributed
- `get-current-yield-rate ()`: Get current yield rate
- `get-governance-threshold ()`: Get consensus threshold

#### Utility Functions
- `compute-pending-yield (participant-address principal)`: Calculate pending yield
- `can-withdraw-tokens (participant-address principal)`: Check withdrawal eligibility
- `check-text-length (input-string (string-utf8 256))`: Validate text length
- `is-valid-transfer-recipient (recipient-address principal)`: Validate recipient

## Usage Flow

### Joining the Pool
1. Call `stake-tokens-in-pool` with desired stake amount (minimum 1 STX)
2. Tokens are locked for 144 blocks
3. Yield accumulation begins immediately

### Filing Claims
1. Ensure you're a pool participant
2. Call `file-insurance-claim` with amount and description
3. Wait for administrative review and decision

### Collecting Rewards
1. Call `collect-yield-rewards` to claim accumulated yield
2. Yield is calculated based on stake amount and time elapsed

### Withdrawing Funds
1. Wait for lock period to expire (144 blocks)
2. Call `withdraw-staked-tokens` with desired withdrawal amount
3. Any pending yield is automatically collected

## Security Considerations

- **Time Locks**: Staked tokens are locked for 144 blocks to prevent flash loan attacks
- **Administrative Controls**: Critical functions require contract owner authorization
- **Validation**: Extensive input validation and error handling
- **Balance Checks**: Ensures sufficient funds before transfers
- **Status Tracking**: Claims cannot be processed multiple times

## Deployment Notes

- Contract owner is set to the deployer address
- Initial yield rate is set to 1% (100 basis points)
- Initial consensus requirement is set to 51% (5100 basis points)
- All monetary values are in microSTX (1 STX = 1,000,000 microSTX)

## Development and Testing

When deploying or testing this contract:

1. Ensure sufficient STX balance for staking operations
2. Test all error conditions and edge cases
3. Verify time-lock functionality with block progression
4. Test administrative functions with proper authorization
5. Validate yield calculations and distributions