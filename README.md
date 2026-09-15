# Radix Matching

Foundry prototype for a two-sided native-ETH/ERC20 matching engine backed by a single
`mapping(bytes32 => Branch)` radix tree store addressed by stable node nonce.

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
bits empty. Any permitted unmatched remainder receives the next decrementing order nonce and rests in the
appropriate active book.

## Branch Encoding

The packed node layout remains one `bytes32`, stored in its parent pointer. The low 32-bit nonce is
the node's unique, stable identity: a branch's child pointers are stored at
`tree[bytes32(branchNonce)]`, not at a key derived from the full mutable packed word. Price,
quantity, correction, and nonce all remain in the parent pointer. A partial fill can therefore
rewrite the branch summary in its parent while its own two children stay in the same mapping slot.

Order and branch identities share one collision-free 32-bit namespace with allocation fronts that
move toward one another:

```text
order_nonce  = uint32.max, uint32.max - 1, ...
branch_nonce = 1, 2, ...
```

Each insertion into a nonempty side allocates exactly one new branch identity. The book rotates
before the two allocation fronts meet, so branch identities cannot alias order leaves. Radix
routing derives keys from descendant order leaves rather than treating a branch identity as part of
the path. The quantity field stores the exact sum of the child quantities. A uniform-tick branch
stores `roundingCorrection + 1` in its
correction field, allowing aggregate matching to reproduce the exact sum of per-order rounded
notionals. Mixed-tick branches use correction code zero and recurse when their quote value is needed.
The nonce is a unique node identity and addresses that node's stored child-pointer pair.

Resting order nonces start at `type(uint32).max` and decrement by one. Branch nonces start at one and
increment by one. A book epoch remains restable only while the next order identity is above the next
branch identity.

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
forge test --isolate --force --match-contract '(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)' --gas-report
forge snapshot --isolate --force --match-contract '(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)' --snap .gas-snapshot.runtime
forge snapshot --isolate --force --match-contract '(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)' --check .gas-snapshot.runtime
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
