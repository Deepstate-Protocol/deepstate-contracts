# Radix Matching

Foundry prototype for a two-sided ERC20 matching engine backed by a single `mapping(bytes32 => Branch)` radix tree store.

## Order Node Layout

Resting orders are packed into one `bytes32`:

- bits 232-255: 24-bit price
- bits 40-231: 192-bit quantity
- bits 0-39: 40-bit decrementing nonce

The contract exposes the two order actions:

- `fill(bytes32 order, bool isBid)`
- `cancel(bytes32 order)`

Incoming `fill` orders must leave nonce bits empty. Any unfilled remainder receives the next decrementing nonce and rests on the bid or ask tree.

## Branch Encoding

The node layout remains one `bytes32`. Branch nodes do not use nonce tags, probes, or a separate namespace.

A branch node is addressed with an actual order boundary key from its children:

```text
path = price || nonce
branch_path = max(child_a_path, child_b_path)
```

The branch path is packed back into the same price and nonce fields, while the quantity field stores the exact sum of the child quantities. Because the boundary key is an actual order path, uniqueness comes from the globally decrementing order nonce rather than from a synthetic branch nonce namespace.

Resting orders start at `type(uint40).max - 1` and decrement from there. The maximum nonce value is left unused by order assignment.

Higher order nonce still means earlier time priority at the same price.

## Security Assumptions

- `evm_version = "cancun"` is required because the reentrancy guard uses transient storage opcodes.
- Base and quote tokens must be standard exact-balance ERC20s. Fee-on-transfer, rebasing, or otherwise inexact transfers revert.
- Filled resting orders are claimed through `cancel(bytes32 order)`, which also withdraws any unfilled remainder.

## Commands

```sh
forge build
forge test
```

Deploy script:

```sh
BASE_TOKEN=0x... QUOTE_TOKEN=0x... forge script script/RadixMatchingEngine.s.sol:RadixMatchingEngineScript --rpc-url <rpc> --private-key <key> --broadcast
```
