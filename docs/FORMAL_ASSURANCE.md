# Formal Assurance Scope

This document maps each safety-critical subsystem to its automated evidence. It distinguishes
symbolic proofs from bounded state exploration and sampled differential checks. Passing these gates
does not constitute an external audit or a proof of every possible contract execution.

## Evidence Classes

| Class | Mechanism | Meaning |
|---|---|---|
| Symbolic | Halmos with Yices | The assertion holds for every input satisfying the assumptions in the named harness. |
| Stateful model | Foundry invariant handlers | Random operation sequences preserve an independently maintained accounting and order-book model. |
| Differential | Independent Python `Decimal` and Solidity quote oracles | Production output agrees with a separately implemented reference over the checked domain. |
| Behavioral | Unit, fuzz, boundary, corruption, reentrancy, and gas-isolated tests | Named execution paths have concrete regression coverage. |
| Static | Forge lint and Slither | The configured detector set reports no unaccepted finding. |

## Symbolic Obligations

`make formal-halmos` executes every `testFuzz_Formal*` function in
`test/RadixMatchingEngineFormal.t.sol`.

| Property | Symbolic domain | Harness |
|---|---|---|
| Single-maker bid accounting | Every maker/taker quantity pair in `[1, 8]`, covering underfill, exact fill, and overfill | `testFuzz_FormalBidAgainstAskConservesAndClaims` |
| Single-maker ask accounting | Bid-side mirror of the preceding domain | `testFuzz_FormalAskAgainstBidConservesAndClaims` |
| Uniform ask aggregation | Stop in first maker, stop in second maker, exact aggregate fill, and overfill | `testFuzz_FormalSameTickAskAggregateConserves` |
| Uniform bid aggregation | Bid-side mirror of the preceding states | `testFuzz_FormalSameTickBidAggregateConserves` |
| Best ask priority | Better-priced maker is partially or fully consumed before a worse-priced maker | `testFuzz_FormalBidConsumesBestAskFirst` |
| Best bid priority | Better-priced maker is partially or fully consumed before a worse-priced maker | `testFuzz_FormalAskConsumesBestBidFirst` |
| Historical ask no-rest | Underfill, exact fill, and overfill after production epoch rotation | `testFuzz_FormalHistoricalAskNeverRestsRemainder` |
| Historical bid no-rest | Bid-side mirror of the preceding states | `testFuzz_FormalHistoricalBidNeverRestsRemainder` |
| Optimized quote assembly | Every `uint160` quantity and both rounding modes at seven fixed exponent/sign boundary ticks: `int32.min`, `int32.min + 1`, `-1_000_000_000`, `0`, `1`, `int32.max - 1`, and `int32.max` | `QuoteArithmeticFormalTest.testFuzz_FormalQuote*` |
| Tick decomposition bounds | Every `int32` tick | `testFuzz_FormalTickDecompositionBounds` |
| Quote limb reconstruction | Arbitrary 256-bit high and low product limbs at production shifts 32, 128, and 224; remainder bounds at every shift in `[32, 224]` | `testFuzz_FormalQuoteLimbReconstruction*`, `testFuzz_FormalQuoteRemainderBound` |
| Ask floor correction | Arbitrary 256-bit products and every production binary shift in `[32, 224]` | `testFuzz_FormalAskCorrectionIsExact` |
| Bid ceiling correction | Arbitrary 256-bit products and every production binary shift in `[32, 224]` | `testFuzz_FormalBidCorrectionIsExact` |
| Correction-code capacity | Every valid pair of nonempty child leaf counts and child corrections with at most `2**32 - 2` leaves | `testFuzz_FormalCorrectionCodeCapacity` |

The matching proofs call the production insertion, matching, settlement, rotation, and cancellation
logic. The epoch harness changes only the next nonce so exhaustion can be reached in a bounded
sequence. The arithmetic proofs isolate protocol identities from tree control flow so the solver can
quantify their complete numeric domains.

## Stateful Model Obligations

The single-pool handler in `test/RadixMatchingEngineInvariant.t.sol` independently tracks owners,
remaining quantities, balances, collateral, order sides, price-time priority, nonces, and live tree
membership. Its invariants check:

- collateral equality and individual claim collateralization;
- actor balances and total token-supply conservation;
- branch shape, aggregate quantities, reachability, and node uniqueness;
- owner and side mappings, cancel routing, and inactive-order absence;
- strict nonce decrement, bid/ask storage separation, and zero-quantity storage absence;
- uncrossed books, best-price selection, and same-price time priority;
- right-spine lower bounds while optimized anchors are dirty; and
- sequential cancel and claim liveness for tracked orders.

The multi-pool handler in `test/DeepstateV1Invariant.t.sol` maintains a separate model across three
tokens and three pair combinations. Random actions include direct fills, forward and reverse routes,
cancels, fee changes, hook changes, and accelerated epoch rotation. Its invariants jointly check:

- per-actor balances, engine collateral, fee balances, and total supply;
- book-scoped ownership, order side, remaining quantity, best price, best nonce, and uncrossed books;
- pool epochs, fee configuration, hook configuration, validated hook calls, and absence of unexpected
  fill, route, or cancel reverts.

`make invariant-deep-shards` partitions the configured 2,048-run, depth-64 campaign into deterministic
shards. Stateful invariant results are bounded exploration, not universal proofs over arbitrary-length
histories.

## Tick And Quote Oracles

`script/check_tick_math.py` parses the production factor tables rather than importing generated test
answers. It checks every table constant against a high-precision `Decimal` exponential calculation,
then checks deterministic boundary, exponent-boundary, nibble-boundary, and seeded random ticks. For
each sampled tick it verifies:

- the independently calculated exponent shift;
- normalized Q128 factor bounds;
- at most 64 Q128 ulps of factor error; and
- strict monotonicity against the next tick.

`test/QuoteMath.sol` always reconstructs the full 512-bit quantity-factor product. Production-path
tests use it as a deliberately slower settlement oracle, independently of the production one-word
product shortcut. Halmos proves both implementations equal for every `uint160` quantity and both
rounding directions at the seven fixed ticks listed above. The dense factors at tick `-1` and tick
`1_000_000_000` are full-width Forge differential fuzz targets because the nonlinear SMT queries for
those constants do not terminate reliably within the formal gate's 30-second per-assertion budget.
The same production control-flow regimes are symbolically covered at neighboring and endpoint
factors, while a separate dynamic-shift differential check and the symbolic limb identities cover
the quotient/remainder reconstruction.

## Explicit Assumptions

The assurance claims depend on the following conditions:

1. The deployed bytecode is built from the reviewed commit with Solidity `0.8.28`, the pinned Foundry
   profile, and Cancun EVM semantics.
2. Supported assets have exact-transfer ERC20 behavior. Rebasing, fee-on-transfer, mint-on-transfer,
   and other balance-changing token semantics are outside the accounting model.
3. Keccak-256 collisions for pool, book, and order identifiers are computationally infeasible.
4. Optional hooks are untrusted best-effort notifications. Hook correctness is not required for
   matching correctness, and missed hook calls must be reconciled by the hook consumer.
5. Administrative fee and hook configuration is controlled according to `SECURITY.md`.

## Residual Scope

The following claims are intentionally not made:

- Halmos does not quantify arbitrary-length order histories or arbitrary tree populations.
- Direct production/oracle quote equivalence is symbolic at seven representative boundary ticks,
  not at all `2**32` tick factors. Tick `-1` and tick `1_000_000_000` remain full-width differential
  fuzz checks for the solver-tractability reason documented above.
- The independent real-number tick oracle samples the 32-bit tick domain; it does not enumerate all
  `2**32` ticks. The decomposition bounds themselves are symbolically proved for the complete domain.
- Stateful fuzzing does not prove that no longer or adversarially selected sequence can fail.
- The repository does not prove properties of third-party token or hook implementations.
- Runtime gas bounds and liveness under a block gas limit are benchmarked, not formally proved.

These residuals are why an independent audit of the exact release commit remains a deployment
requirement even when every automated gate passes.

## Reproduction

Run the complete local security gate:

```sh
make verify-security
```

Run the principal assurance layers separately:

```sh
make formal-halmos
make tick-reference
make invariant-deep-shards
make coverage-check
make slither
```
