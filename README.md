# Radix Matching

Foundry prototype for a two-sided native-ETH/ERC20 matching engine backed by a single
`mapping(bytes32 => Branch)` radix tree store.

## Order Node Layout

Resting orders are packed into one `bytes32`:

- bits 224-255: signed 32-bit logarithmic tick
- bits 64-223: 160-bit quantity
- bits 32-63: 32-bit same-tick rounding correction code (zero in order leaves)
- bits 0-31: 32-bit decrementing nonce

Tick `t` represents `price = 2 ** (96 * t / 2**31)` quote units per base unit. Tick zero is
exactly 1:1, adjacent ticks differ by about 0.000309861 basis points, and the full signed domain
spans approximately `[2**-96, 2**96)`. Settlement uses a Q128 fractional factor and a binary
divisor in the range `[2**32, 2**224]`. This exponent bound guarantees that a live `uint160`
quantity produces a quote value that fits `uint256`.

Prices apply to raw token units. The engine does not read token decimals or normalize amounts;
routers must choose ticks that incorporate the decimal relationship of each token pair.

`DeepstateV1` exposes these order actions:

- `fill(FillParams params)`
- `fillRoute(FillParams[] fills)`
- `cancel(address token0, address token1, uint256 epoch, bytes32 order)`

`FillParams` contains sorted `token0` and `token1` addresses, the book epoch, a packed incoming order,
the bid/ask side, and `noRest` / `fillOrKill` controls. Incoming orders must leave nonce and correction
bits empty. Any permitted unmatched remainder receives the next decrementing nonce and rests in the
appropriate active book.

`DeepstateV1` also implements the Uniswap V4 swap-manager lifecycle used by swap routers: `unlock`,
`swap`, `sync`, `settle`, `settleFor`, `take`, `clear`, and both `exttload` overloads. Currency deltas,
the unlock state, the synced currency, and the nonzero-delta count use V4's canonical transient
storage layout. Existing V4 swap routers can therefore open an unlock callback, execute one or more
swaps, net intermediate currencies, and settle only their final deltas. `PoolKey.currency0` and
`currency1` must be strictly address-sorted; the compatibility key uses `fee = 0`,
`tickSpacing = 1`, and `hooks = address(0)` because protocol fees and top-of-book hooks are
configured independently. Every compatibility swap targets the pair's active epoch and is no-rest.

To remain below the EIP-170 runtime-size limit, the constructor deploys one immutable
`V4SwapManagerModule`. `DeepstateV1` handles `swap`, previews, radix mutations, fee calculation, and
delta recording itself. Its fallback forwards only the remaining V4 lifecycle selectors into the
module's fixed code using the engine's execution context, which is required for canonical transient
slots and engine-held balances. The module contains no persistent-storage writes and cannot be
reconfigured or replaced.

`SwapParams.amountSpecified < 0` requests exact input and `amountSpecified > 0` requests exact
output. Both `zeroForOne` directions and all four specified-currency modes are supported.
`sqrtPriceLimitX96` is converted conservatively to the nearest executable logarithmic tick.
Execution never rests an unmatched remainder and returns the actual partial result when the amount,
price limit, or available liquidity stops execution.

The returned `BalanceDelta` uses V4's packed caller-relative `int128` currency deltas. `swap` records
those deltas without transferring tokens; the unlock callback pays negative deltas and withdraws
positive deltas before returning. Native ETH remains currency address zero. A canonical key has no
V4 hook, so `hookData` is accepted for ABI compatibility but has no consumer. See
[docs/UNISWAP_V4_COMPATIBILITY.md](docs/UNISWAP_V4_COMPATIBILITY.md) for the precise compatibility
boundary and test provenance.

## Branch Encoding

The node layout remains one `bytes32`. Branch nodes do not use nonce tags, probes, or a separate namespace.

A branch node is addressed with an actual order boundary key from its children:

```text
path = price || nonce
branch_path = max(child_a_path, child_b_path)
```

The branch path is packed back into the same tick and nonce fields, while the quantity field stores
the exact sum of the child quantities. A uniform-tick branch stores `roundingCorrection + 1` in its
correction field, allowing aggregate matching to reproduce the exact sum of per-order rounded
notionals. Mixed-tick branches use correction code zero and recurse when their quote value is needed.
Because the boundary key is an actual order path, uniqueness comes from the decrementing order nonce
rather than from a synthetic branch nonce namespace.

Resting orders start at `type(uint32).max` and decrement from there.

Higher order nonce still means earlier time priority at the same price.

## Security Assumptions

- Builds are pinned to Solidity `0.8.28` with Foundry compiler auto-detection disabled and optimizer enabled. Do not deploy bytecode built with a different compiler/profile without rerunning the full test and invariant suite.
- `evm_version = "cancun"` is required because the reentrancy guard uses transient storage opcodes.
- `address(0)` denotes native ETH and is valid only as sorted token0. Native settlement requires enough `msg.value` to cover the caller's net ETH debit and refunds all excess after outputs and fees. Every nonzero token must be a standard exact-balance ERC20 selected by deployment configuration. Every ERC20 transfer is assumed to debit the source and credit the recipient by exactly the requested amount. Fee-on-transfer, rebasing, mint-on-transfer, or otherwise inexact tokens are out of scope for this contract and must be excluded before deployment.
- Filled resting orders are claimed through `cancel(token0, token1, epoch, order)`, which also withdraws any unfilled remainder.
- Pool hooks are best-effort notifications. Calls are gas-capped and failures are swallowed, so hook implementations must tolerate missed notifications and reconcile stale state themselves.
- Protocol fees are capped at 100 bps and apply only to matched taker output. The fee calculation supports the full signed settlement-delta domain without intermediate multiplication overflow.

See [SECURITY.md](SECURITY.md) for the deployment checklist, administrative trust model, supported-token requirements, and vulnerability-reporting process. The contracts have extensive automated verification but have not yet received an independent external audit.
See [docs/FORMAL_ASSURANCE.md](docs/FORMAL_ASSURANCE.md) for the property-to-evidence map,
symbolic proof domains, stateful model scope, and residual assumptions.
See [docs/PROOF_OBLIGATIONS.md](docs/PROOF_OBLIGATIONS.md) for the exact theorem registry and
[docs/INDUCTIVE_PROOFS.md](docs/INDUCTIVE_PROOFS.md) for the finite-history preservation proof.

## Commands

Install the pinned Python tool runner before invoking verification targets:

```sh
python3 -m pip install uv==0.11.29
```

```sh
make verify
make verify-deep
make verify-security
make invariant-deep-shard
make invariant-deep-shards
make gas-runtime
make snapshot-runtime
make snapshot-runtime-check
make tick-reference
make uniswap-v4
make coverage
make coverage-check
make toolchain-lock-check
make formal-smt
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
INVARIANT_RUNS=2048 INVARIANT_DEPTH=64 INVARIANT_SHARDS=8 INVARIANT_SHARD=1 make invariant-deep-shard
INVARIANT_RUNS=2048 INVARIANT_DEPTH=64 INVARIANT_SHARDS=8 make invariant-deep-shards
forge test --isolate --force --match-contract 'RadixMatchingEngine(Gas|HookGas|FeeGas)Test' --gas-report
forge snapshot --isolate --force --match-contract 'RadixMatchingEngine(Gas|HookGas|FeeGas)Test' --snap .gas-snapshot.runtime
forge snapshot --isolate --force --match-contract 'RadixMatchingEngine(Gas|HookGas|FeeGas)Test' --check .gas-snapshot.runtime
forge build --sizes
python3 script/check_tick_math.py --check test/TickMath32.t.sol
uv run --locked --only-group static slither src/DeepstateV1.sol --config-file slither.config.json --exclude-informational
forge coverage --ir-minimum --skip RadixMatchingEngineInvariant.t.sol --skip RadixMatchingEngineGas.t.sol --skip RadixMatchingEngineAccessList.t.sol --report lcov --report summary --no-match-coverage 'test|script' --no-match-contract 'RadixMatchingEngineInvariantTest'
make coverage-check
make formal-halmos
```

`gas-runtime` and `snapshot-runtime` use a fixed harness that pauses setup gas and meters one target `fill` or `cancel` call per test. Deployment-heavy negative-token and reentrancy tests remain in `make verify`, but they are intentionally outside the runtime gas profile.
`make verify` runs the invariant contract through its dedicated `invariant` target, so the regular `test` target excludes that contract to avoid duplicate invariant execution.
`invariant-deep-shard` and `invariant-deep-shards` split the deep invariant suite into deterministic batches with `INVARIANT_SHARDS` and `INVARIANT_SHARD`, which makes long 2048-run profiles easier to audit and retry.
`make verify` and `make verify-deep` include `snapshot-runtime-check` so runtime gas drift is reviewed instead of silently accepted.
Pull requests run the components of `make verify` as parallel jobs, plus coverage, SMT, and Halmos
formal jobs corresponding to the additional gates in `make verify-security`.
The Python verification environment is resolved by `uv.lock`; CI uses Python `3.12.13`, uv
`0.11.29`, immutable GitHub Action revisions, and the explicit `ubuntu-24.04` runner family.
`make toolchain-lock-check` rejects a stale lock before static or formal analysis runs.
The security job also runs `make tick-reference`, an independent Python `Decimal` check of the
logarithmic settlement constants and thousands of deterministic full-domain tick samples.
The Halmos gate proves bid- and ask-side accounting for every quantity pair in `[1, 8]`, same-tick
aggregate settlement states, best-price priority, historical-book no-rest behavior, the complete
signed-tick exponent/shift domain, native ETH settlement transitions, representative full-width
quote arithmetic, two-limb quotient reconstruction, and generic binary rounding-correction bounds.
It uses a minimal exact-transfer ERC-20 model so the solver analyzes matching state rather than
third-party token internals. Broader state sequences and multi-pool interactions remain covered by
independent models, fuzz tests, and stateful invariants as detailed in the assurance map.
`coverage-check` emits `lcov.info` and fails unless the tracked source contracts stay at 100% line, statement, branch, and function coverage after explicit exclusions.
`make formal-smt` discharges the complete-domain arithmetic, encoding, namespace, epoch, route,
native-solvency, and termination lemmas used by the protocol's inductive proofs. `make verify-security` is the
heavyweight local gate: it runs the deep invariant profile, runtime gas snapshot check, build-size
check, clean Slither gate, enforced contract-focused Forge LCOV plus summary coverage, the SMT
lemmas, and Halmos symbolic tests. `formal-kevm-build` and `formal-kevm` are optional KEVM/Kontrol
targets and require Docker.

Deploy script:

```sh
forge script script/DeepstateV1.s.sol:DeepstateV1Script --rpc-url <rpc> --private-key <key> --broadcast
```
