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

Resting orders start at `type(uint40).max` and decrement from there.

Higher order nonce still means earlier time priority at the same price.

## Security Assumptions

- Builds are pinned to Solidity `0.8.28` with Foundry compiler auto-detection disabled and optimizer enabled. Do not deploy bytecode built with a different compiler/profile without rerunning the full test and invariant suite.
- `evm_version = "cancun"` is required because the reentrancy guard uses transient storage opcodes.
- Base and quote tokens must be standard exact-balance ERC20s selected by deployment configuration. Every transfer is assumed to debit the source and credit the recipient by exactly the requested amount. Fee-on-transfer, rebasing, mint-on-transfer, or otherwise inexact tokens are out of scope for this contract and must be excluded before deployment.
- Filled resting orders are claimed through `cancel(bytes32 order)`, which also withdraws any unfilled remainder.

## Commands

```sh
make verify
make verify-deep
make verify-security
make gas-runtime
make snapshot-runtime
make snapshot-runtime-check
make coverage
make coverage-check
make formal-halmos
make formal-kevm-build
make formal-kevm
```

Equivalent individual commands:

```sh
forge fmt --check
forge lint
forge test --force -vv --no-match-contract '.*RadixMatchingEngineInvariantTest.*'
forge test --force --match-contract '.*RadixMatchingEngineInvariantTest.*' --match-test 'invariant_.*'
FOUNDRY_INVARIANT_RUNS=2048 FOUNDRY_INVARIANT_DEPTH=64 forge test --force --match-contract '.*RadixMatchingEngineInvariantTest.*' --match-test 'invariant_.*'
forge test --force --match-contract RadixMatchingEngineGasTest --gas-report
forge snapshot --force --match-contract RadixMatchingEngineGasTest --snap .gas-snapshot.runtime
forge snapshot --force --match-contract RadixMatchingEngineGasTest --check .gas-snapshot.runtime
forge build --sizes
uv tool run --from slither-analyzer slither src/RadixMatchingEngine.sol --config-file slither.config.json --exclude-informational
forge coverage --report summary --no-match-coverage 'test|script' --no-match-contract 'RadixMatchingEngineInvariantTest'
make coverage-check
uv tool run --from halmos halmos --match-contract RadixMatchingEngineFormalTest --match-test '^testFuzz_Formal' --solver z3 --solver-timeout-assertion 120s --no-status
```

`gas-runtime` and `snapshot-runtime` use a fixed harness that pauses setup gas and meters one target `fill` or `cancel` call per test. Deployment-heavy negative-token and reentrancy tests remain in `make verify`, but they are intentionally outside the runtime gas profile.
`make verify` runs the invariant contract through its dedicated `invariant` target, so the regular `test` target excludes that contract to avoid duplicate invariant execution.
`make verify` and `make verify-deep` include `snapshot-runtime-check` so runtime gas drift is reviewed instead of silently accepted.
Pull requests run both `make verify` and the additional security job for `make coverage-check` plus `make formal-halmos`.
`coverage-check` fails unless `src/RadixMatchingEngine.sol` stays at 100% line, statement, branch, and function coverage in the Forge summary.
`make verify-security` is the heavyweight local gate: it runs the deep invariant profile, runtime gas snapshot check, build-size check, clean Slither gate, enforced contract-focused Forge coverage summary, and Halmos symbolic tests. `formal-kevm-build` and `formal-kevm` are optional KEVM/Kontrol targets and require Docker.

Deploy script:

```sh
BASE_TOKEN=0x... QUOTE_TOKEN=0x... forge script script/RadixMatchingEngine.s.sol:RadixMatchingEngineScript --rpc-url <rpc> --private-key <key> --broadcast
```
