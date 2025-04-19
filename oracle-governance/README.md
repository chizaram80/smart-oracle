# Cross-Chain Oracle Smart Contract

## Overview

The Enhanced Cross-Chain Oracle Smart Contract is a decentralized oracle solution built on the Stacks blockchain. This contract enables reliable and secure cross-chain data feeds through a network of incentivized data providers. It incorporates reputation management, staking mechanisms, data validation, and governance features to ensure high-quality data delivery.

## Features

- **Provider Registration**: Verified data providers can join the network by staking STX tokens
- **Reputation System**: Providers build reputation based on accuracy and consistency
- **Staking Mechanism**: Economic incentives to ensure honest behavior
- **Governance**: On-chain voting for protocol upgrades and parameter adjustments
- **Slashing Protocol**: Penalties for malicious or inaccurate data submissions
- **Rewards Distribution**: Compensation for reliable providers
- **Data Expiration**: Automatic invalidation of outdated information

## Contract Structure

The contract is organized into several functional components:

1. **Constants**: Error codes and system parameters
2. **Data Maps**: Storage for providers, oracle data, and governance proposals
3. **Data Variables**: System state variables
4. **Read-Only Functions**: Data retrieval interfaces
5. **Provider Management**: Registration and reputation functions
6. **Governance Functions**: Proposal submission and voting
7. **Reward Distribution**: Mechanisms for compensating honest providers
8. **Block Height Management**: Simulation utilities for testing

## Function Reference

### Provider Management

#### `register-new-provider`
Registers a new data provider with an initial stake.

```clarity
(define-public (register-new-provider (initial-stake-amount uint)))
```

Parameters:
- `initial-stake-amount`: Amount of STX to stake (minimum 1000)

Returns:
- `(ok true)` on success
- `ERR-PROVIDER-REGISTRATION-EXISTS` if already registered
- `ERR-INSUFFICIENT-STAKE-FUNDS` if stake is below minimum

#### `increase-provider-reputation`
Increases provider reputation through additional staking.

```clarity
(define-public (increase-provider-reputation (stake-amount uint)))
```

Parameters:
- `stake-amount`: Additional STX to stake

Returns:
- `(ok true)` on success
- `ERR-INSUFFICIENT-STAKE-FUNDS` if insufficient balance
- `ERR-UNAUTHORIZED-ACCESS` if not registered

### Governance Functions

#### `submit-governance-proposal`
Creates a new governance proposal (owner-only).

```clarity
(define-public (submit-governance-proposal (proposal-type (string-ascii 50)) (parameter-value uint)))
```

Parameters:
- `proposal-type`: Description of the proposal
- `parameter-value`: Numeric value related to the proposal

Returns:
- Proposal ID on success
- `ERR-UNAUTHORIZED-ACCESS` if not contract owner

#### `penalize-malicious-provider`
Slashes a provider's stake for submitting bad data (owner-only).

```clarity
(define-public (penalize-malicious-provider (provider-address principal) (penalty-amount uint)))
```

Parameters:
- `provider-address`: Address of the provider to penalize
- `penalty-amount`: Amount of STX to slash

Returns:
- `(ok true)` on success
- `ERR-UNAUTHORIZED-ACCESS` if not contract owner
- `ERR-INSUFFICIENT-STAKE-FUNDS` if penalty exceeds stake

### Reward Distribution

#### `distribute-community-rewards`
Distributes rewards from the community pool to eligible providers.

```clarity
(define-public (distribute-community-rewards))
```

Returns:
- `(ok true)` on success
- `ERR-UNAUTHORIZED-ACCESS` if reputation is too low

### Data Retrieval

#### `get-oracle-data`
Retrieves oracle data by identifier.

```clarity
(define-read-only (get-oracle-data (data-identifier (string-ascii 50))))
```

Parameters:
- `data-identifier`: Key for the data to retrieve

Returns:
- Data record if found, `none` otherwise

### Block Height Simulation

#### `increment-simulated-height`
Increments the simulated block height.

```clarity
(define-public (increment-simulated-height))
```

#### `set-simulated-block-height`
Sets the simulated block height to a specific value.

```clarity
(define-public (set-simulated-block-height (height-value uint)))
```

## Integration Guide

### Provider Registration

To register as a provider:

1. Ensure you have at least 1000 STX available
2. Call `register-new-provider` with your desired stake amount
3. Monitor your reputation and submission success rate

### Data Consumption

To integrate oracle data into your contract:

1. Import the oracle contract
2. Call `get-oracle-data` with the appropriate data identifier
3. Verify data freshness by checking the `submission-timestamp` and `data-expiration-time`

### Governance Participation

For protocol upgrades and parameter changes:

1. Submit proposals through `submit-governance-proposal` (owner only)
2. Vote on active proposals (voting function implementation pending)

## Security Considerations

- Provider reputation directly influences their impact on the oracle network
- All providers must maintain adequate stake to participate
- Data providers face slashing for submitting incorrect information
- Minimum stake requirements prevent Sybil attacks
- Data expiration prevents usage of stale information

## Technical Requirements

- Clarity language compatibility
- Stacks blockchain integration
- Minimum of 1000 STX tokens for provider registration