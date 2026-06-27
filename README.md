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

## Branch Nonce Reservation

The node layout remains one `bytes32`. Branch nodes reserve the single maximum nonce value:

- `type(uint40).max`: branch nodes
- `type(uint40).max - 1` and below: resting orders, assigned by the decrementing nonce

Higher order nonce still means earlier time priority at the same price.

## Commands

```sh
forge build
forge test
```

Deploy script:

```sh
BASE_TOKEN=0x... QUOTE_TOKEN=0x... forge script script/RadixMatchingEngine.s.sol:RadixMatchingEngineScript --rpc-url <rpc> --private-key <key> --broadcast
```
