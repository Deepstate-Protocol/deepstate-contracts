# Formal Assurance Scope

This document maps each safety-critical subsystem to its automated evidence. It distinguishes
complete-domain algebraic proofs, production-bytecode symbolic proofs, mathematical induction,
bounded state exploration, and sampled differential checks. The precise theorem statements and
assumptions are in [PROOF_OBLIGATIONS.md](PROOF_OBLIGATIONS.md), with the history-preservation
arguments in [INDUCTIVE_PROOFS.md](INDUCTIVE_PROOFS.md). Passing these gates does not replace an
independent audit of the exact release bytecode.

## Evidence Classes

| Class | Mechanism | Meaning |
|---|---|---|
| Complete-domain SMT | Z3 over integer and bit-vector models source-bound to production expressions | The stated finite-domain algebraic or encoding proposition has no counterexample and its assumptions are satisfiable. |
| Symbolic | Halmos with Yices | The assertion holds for every input satisfying the assumptions in the named harness. |
| Inductive | Explicit base case and operation-local preservation arguments | The local theorems lift to every finite valid protocol history under the stated trusted bases. |
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
| Native bid settlement | Every fee rate in `[0, 100]` and representative positive quantities; native ask liability is fully consumed and split between taker output and fee | `testFuzz_FormalNativeBidFillPreservesSolvency` |
| Native ask settlement | Every maker/taker quantity pair in `[1, 8]`, covering underfill, exact fill, overfill, bid claim, and resting-ask cancellation | `testFuzz_FormalNativeAskFillAndRestPreserveSolvency` |
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

The native-asset handler in `test/DeepstateV1NativeETHInvariant.t.sol` maintains an independent
price-time matching and settlement model for an `ETH / ERC20` pool. Random actions include resting
bids and asks, no-rest taker fills in both directions, partial and full maker fills, cancels, claims,
and fee changes. Its invariants jointly check:

- exact equality between the engine's ETH balance and outstanding native maker liabilities throughout
  the model's protocol-mediated histories;
- exact equality between ERC20 collateral and outstanding quote claims;
- per-actor and fee-recipient balances, plus conservation of both assets; and
- agreement among model quantities, radix leaves, book-scoped owners, order sides, and fee config.

`make invariant-deep-shards` partitions the configured 2,048-run, depth-64 campaign into deterministic
shards. Stateful invariant results are bounded exploration, not universal proofs over arbitrary-length
histories.

## Native Solvency Theorem

Native solvency does not rely on the bounded stateful campaign. `make formal-halmos` symbolically
executes the production native fill, rest, fee, cancel, claim, and payout transitions across their
control-flow relations. `make formal-smt` proves the complete-width transition equations for native
bid fills, ask fills, resting asks, native fee splitting, both cancel/claim cases, direct settlement,
route composition, minimum `msg.value`, exact excess refunds, and unsolicited credits. The source-binding gate also
enumerates every native-capable production outflow site and fails if another site is introduced
without extending the proof.

`INDUCTIVE_PROOFS.md` supplies the empty-state base and lifts those local equations over every finite
reachable history. If `L_ETH` is the sum of remaining native asks and filled native bids across all
books, the resulting universal safety theorem is

`address(engine).balance >= L_ETH`.

Protocol transitions preserve the difference exactly. ETH forced into the engine can only increase
that difference, so it cannot create insolvency. The stronger equality
`address(engine).balance == L_ETH` holds for the complete class of protocol-mediated histories with
no unsolicited native credits. This distinction is necessary because no Solidity contract can stop
ETH from being forced into its address.

## Tick And Quote Oracles

`script/check_tick_math.py` parses the production factor tables rather than importing generated test
answers. It checks every table constant with directed high-precision `Decimal` evaluation. Each
constant under-approximates its exact negative fractional power by fewer than five Q128 ulps. An
interval composition proof covers the at-most-six Q128 multiplications and reciprocal branch, yielding
a full-domain factor-error envelope. The independently computed minimum adjacent-tick gap exceeds the
worst aligned error by more than the required margin, which proves strict monotonicity for all
`2**32` ticks conditional on the directed transcendental reference. Deterministic boundary,
exponent-boundary, nibble-boundary, and seeded random ticks then serve as an additional implementation
cross-check. For each sampled tick the script also verifies:

- the independently calculated exponent shift;
- normalized Q128 factor bounds;
- the tighter sampled error threshold, within the certified global Q128-ulp envelope; and
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

No “no forced ETH” assumption is needed for native solvency. It is needed only for exact
balance-to-liability equality; arbitrary forced credits are included in the `>=` theorem.

## Proof Scope And Residual Boundaries

`script/prove_protocol.py` discharges the complete numeric, packing, transient-namespace, guarded
epoch, local tree-transition, priority, route, fee, hook-state, and termination measures used by the
inductive proof. It first checks that each theorem's assumptions are satisfiable, preventing vacuous
success. The model is fail-closed against the critical production expressions it represents.

Halmos intentionally proves smaller production-bytecode transition kernels rather than attempting an
unbounded symbolic history in one query. The explicit induction in `INDUCTIVE_PROOFS.md` lifts those
kernels and the complete-domain local lemmas to arbitrary finite valid histories. Stateful fuzzing
does not supply that universal proof; it remains an independent attempt to falsify the theorem with
long concrete histories and a separate accounting model.

The following stronger claims remain intentionally outside the theorem:

- collision-free Keccak over an input domain larger than 256 bits;
- correct balance accounting for a token that lies, rebases, taxes transfers, or otherwise violates
  exact-transfer semantics;
- unconditional native balance equality in the presence of unsolicited ETH credits;
- successful delivery of a best-effort hook notification;
- Solidity compiler, EVM, SMT-solver, or directed-transcendental-library correctness; and
- successful execution under every possible chain block-gas limit.

Termination is proved for every finite input in the unmetered semantics. A mixed-price subtree or a
sufficiently large route can still require more gas than a particular block permits and therefore
revert atomically. These explicit trusted bases and environmental limits are why an independent audit
of the exact release commit remains a deployment requirement.

## Reproduction

Run the complete local security gate:

```sh
make verify-security
```

Run the principal assurance layers separately:

```sh
make formal-halmos
make formal-smt
make tick-reference
make invariant-deep-shards
make coverage-check
make slither
```
