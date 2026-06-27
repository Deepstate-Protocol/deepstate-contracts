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

## Internal Node Namespaces

The node layout remains one `bytes32`, but the engine reserves the two high bits of the 40-bit nonce field for internal keys:

- `00`: resting orders, with a 38-bit decrementing nonce
- `01`: side metadata in `ownerOfOrder`, used by `cancel(bytes32)` to distinguish bid claims from ask claims
- `10`: bid-tree branch nodes
- `11`: ask-tree branch nodes

Branch nodes are still self-addressed from their own bytes. The branch address packs the side tag, aggregate quantity, and a heap-indexed radix prefix so different branch depths cannot alias each other while both conceptual trees coexist in the single `tree` mapping.

This means `nextNonce` starts at `2^38 - 1`; higher nonce still means earlier time priority at the same price.

## Commands

```sh
forge build
forge test
```

Deploy script:

```sh
BASE_TOKEN=0x... QUOTE_TOKEN=0x... forge script script/RadixMatchingEngine.s.sol:RadixMatchingEngineScript --rpc-url <rpc> --private-key <key> --broadcast
```
