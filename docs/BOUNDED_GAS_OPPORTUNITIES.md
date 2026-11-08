# Bounded Gas Optimization Opportunities

These are measured **scratch prototypes**, not changes to the working contract or a deployment.
The history investigation is on the working branch in local commit `3676a54`; this follow-up keeps
the candidate patches separate so they can be reviewed before promotion. Nothing is pushed.

## Controls

The comparison baseline is the bounded implementation `096eab2`, not master or the pre-bound fix.
All primary comparisons use solc 0.8.28, via-IR, optimizer 200, Cancun, and the same pinned Forge
`d3167db` executor and frozen comparison fixture as [the full workup](FULL_GAS_WORKUP.md).
Only the engine runtime is replaced, before any books are populated.

Each of seven cumulative solc prototypes executes all 188 release gas rows and 12 insertion probes.
The fully validated E prototype is additionally measured under experimental Solar 0.3.0 / Solidity 0.8.38,
against the existing Solar bounded baseline, with the same Forge executor and fixtures. Solar's
metadata does not report a via-IR pipeline; it is not treated as the solc compiler pipeline.

That is **1,600 passing benchmark test executions**. Summaries use 157 independent completed
operations per dataset, excluding 42 inherited repeats and the capped-gas functional check.
The [complete CSV](BOUNDED_GAS_OPPORTUNITIES.csv) retains all 200 rows per dataset, including those
exclusions. Both baseline and candidates succeed in the capped-gas check.

Medians and case counts are unweighted. They are not estimates of a production-wide gas saving.
No new tests, source changes, or fixture adjustments are applied to the frozen gas-measurement
harness. Its previously documented large-book setup offset remains unchanged.

## Tested Candidates

Each row includes the preceding candidates; the patch files are cumulative against `096eab2`.
Do not sum their percentages or apply the patches sequentially.

| Stage | Candidate | Cases saving >=1,000 gas | Cases adding >=1,000 gas | Median change |
|---|---|---:|---:|---:|
| A | Mixed-match quote deltas | 17 | 0 | -0.02% |
| B | A + shared cancellation factor and quote delta | 25 | 0 | -0.03% |
| C | B + early price-prefix insertion | 35 | 10 | -0.02% |
| C2 | C with a same-price guard | 35 | 6 | -0.02% |
| D | C2 + lazy insertion quote/factor sharing | 41 | 0 | -0.03% |
| E | D + uniform matching notional differences | 62 | 0 | -0.05% |

The additional F prototype guards exact-zero quote-cache deltas. Its incremental tradeoff and
storage-access measurements are reported separately below; its 200 gas rows are also in the CSV.

The early-split shortcut alone is not an unconditional improvement: although different-price
comb insertion gets much cheaper, the original C version adds 21,350 gas to a deep native rest.
Gating the prefix check reduces, but does not eliminate, that regression. Combining it with
shared insertion quotes in D removes all >=1,000-gas regressions in this measured matrix.

### A. Update A Mixed Cache By Its Known Removed Quote

Matching already computes the exact removed quote, including leaf rounding. For an existing
mixed branch that survives a partial fill, use:

```text
new cached quote = old cached quote - removed quote
```

This avoids repricing the two children, while retaining an exact cache at every ancestor. A
surviving Patricia branch keeps its split class: nonempty children separated by a price bit cannot
become the same price. Collapsed branches promote their surviving child before any cache update.

No descendant walk, lazy summary, or extra callback is introduced.

### B. Share Cancellation Pricing Through The Path

Decode the removed live leaf's price factor once. Carry its exact remaining quote in a call-local
memory context and reuse it for ancestor updates and maker payout. For uniform ancestors, update
the correction from the difference between old and new aggregate notionals instead of repricing
both children. Mixed ancestors subtract the same exact removed quote from their cache.

There is still one cancellation path, with constant work per ancestor. No memory context is
shared across actions or persisted in storage, and fully filled claims do not decode an absent
leaf's factor.

### C/C2. Split On Price Before Searching For A Witness Nonce

The exact representative tick and cached split depth can prove that a new tick diverges above
the current subtree. In that case, create the new parent immediately. Only the high 32 tick bits
are used for this shortcut; a branch serial is never treated as a valid order nonce.

When the price prefix cannot establish the split, retain the existing single witness descent.
There is no second search or fallback that enumerates descendants. The C2 guard avoids doing
unnecessary prefix calculations through same-price ancestors.

### D. Share Insertion Pricing And Add The Exact Quote Delta

Every surviving ancestor receives the same incoming leaf quantity and quote. Lazily decode the
factor on the first ancestor that actually needs rebuilding, reuse it through uniform ancestors,
and add the incoming quote directly to mixed caches. A new parent placed above a subtree does
not need this context initialized.

This is the insertion counterpart of cancellation delta propagation. New branch creation still
uses exact child summaries, and the original quantity-overflow checks remain enforced.

### E. Replace Two Uniform Notionals With One Difference

Uniform matching already carries the price factor. Use the existing exact notional-difference
helper to update the correction instead of independently computing the old and new notionals.
The quote helper's rounding direction and event correction behavior are unchanged.

## Combined Prototype Results

All values below are solc gas, compared with the current bounded implementation.

| Operation | Bounded `096eab2` | Prototype E | Change |
|---|---:|---:|---:|
| Match one bid in a 10,000-order book | 187,864 | 166,308 | -11.47% |
| Match one ask in a 10,000-order book | 238,777 | 207,474 | -13.11% |
| Partially fill ask in that book | 250,884 | 216,781 | -13.59% |
| Partially fill bid in that book | 200,385 | 175,601 | -12.37% |
| Rest ask in that book | 256,729 | 203,791 | -20.62% |
| Rest bid in that book | 253,558 | 220,687 | -12.96% |
| Full-depth bid cancellation | 887,530 | 775,156 | -12.66% |
| Full-depth bid cancellation with hook | 911,245 | 798,870 | -12.33% |
| Native deep cancellation after prior fills | 770,624 | 675,740 | -12.31% |
| Native deep partial fill | 772,698 | 702,104 | -9.14% |
| Native rest after full-depth prior fills | 874,932 | 791,805 | -9.50% |
| Hooked pathological off-spine partial fill | 903,202 | 833,615 | -7.70% |
| Different-tick ask insertion above a nonce comb | 291,723 | 166,107 | -43.06% |
| Different-tick bid insertion above a nonce comb | 293,539 | 167,923 | -42.79% |
| Same-tick ask insertion through a nonce comb | 434,309 | 385,751 | -11.18% |
| Sweep 4,096 mixed prices | 100,207 | 100,178 | -0.03% |

The largest solc increase is **546 gas** in a 64-order insertion probe. Some simple cancellations
add roughly 120-323 gas. These smaller costs are retained in the CSV rather than classified as
zero. The final Solar dataset has 59 cases saving at least 1,000 gas, none adding that much, and a
largest increase of 365 gas.

The highest measured final solc operation is **833,615 gas**, a hooked off-spine partial fill.
The highest final Solar operation is **810,225 gas**, the fee-profile off-spine partial fill.
These are dataset peaks, not proofs of universal maxima or estimates for arbitrary external
hook/token implementations. The optimization objective is less redundant work while retaining
bounded computation, not returning to the costs of the former unbounded design.

## Direct Storage And Unused-Code Checks

The focused probe records ordered engine storage accesses around the target operation using
Foundry's state-diff recorder. These are recorded reads/writes, not unique access-list keys or
canonical gas measurements. Token storage accesses and fixture construction are excluded.

| Operation | Baseline reads | E reads | Baseline writes | E writes |
|---|---:|---:|---:|---:|
| Full-depth bid cancellation | 258 | 164 | 97 | 97 |
| Full-depth ask cancellation | 258 | 164 | 97 | 97 |
| Deep best-bid fill | 257 | 195 | 96 | 96 |
| Populated-book ask match | 70 | 43 | 19 | 19 |
| Small zero-quote ask cancellation | 17 | 12 | 6 | 6 |

Thus E removes actual reads, not only arithmetic. It preserves the writes required to keep the
reachable ancestor summaries exact.

### F. Do Not Write A Cache When Its Exact Delta Is Zero

Some mixed-price ask subtrees have leaf-rounded quote deltas of zero. E still reads and writes
their cache with `quoteTotal -= 0` or `quoteTotal += 0`. Guarding those operations preserves the
exact cache without touching storage.

- In the deep zero-quote ask cancellation, recorded reads fall from 164 to 132 and writes from
  97 to 65. All 32 unchanged cache writes disappear.
- In the small zero-quote example, reads fall from 12 to 10 and writes from 6 to 4, eliminating
  the two unchanged writes.
- In the canonical deep ask benchmark, gas falls from **685,595 to 611,387**, an additional
  **74,208 gas** saved compared with E.
- The guard has a cost when the delta is nonzero: up to **1,440 extra gas** in the tested matrix
  compared with E. Three independent cases save at least 1,000 gas versus E, while nine add at
  least 1,000. This is not assumed to be an improvement for every production workload.
- Compared with the original bounded baseline, F still has 62 cases saving at least 1,000 gas,
  none adding that much, and a maximum increase of 546 gas. F's highest measured case is 835,007
  gas. Its 200 gas cases and five storage probes pass; the full E behavioral/invariant campaign
  is not relabeled as an F campaign.

The guards add no traversal, deferred calculation, or changed quote rounding. F remains a
separate candidate so its branch overhead can be judged against actual workload frequency.

### Removing An Unreferenced Helper

After the prototypes replace their call sites, `_replaceBranchAfterSingleChildChange` is unused.
Deleting it from a scratch F build produces **identical executable bytecode**, 20,798 bytes before
and after, when Solidity's length-delimited CBOR metadata is excluded. The optimizer already
removed it. Source cleanup is possible, but no runtime gas saving is attributed to that deletion.

The raw storage logs, 15-case storage-access CSV, dead-code bytecode comparison, and optional
patch are included with the evidence. An initial storage-probe attempt exhausted the test call's
gas during large-book construction; setup is now unmetered, and that discarded attempt is kept
separate from the five successful target-operation measurements per runtime.

## Validation And Promotion Boundary

- All 200 benchmark rows pass for each of seven solc stages and the E Solar stage.
- The final prototype passes five instrumented bound tests, including 256 randomized boundary
  runs, a genuine 64-level match/cancel path, a 4,096-price cached sweep with maker claims, and
  bid/ask early-split tests that require exactly one insertion expansion.
- The final prototype passes 290 behavioral tests, including native settlement, routing, arithmetic,
  event, priority, and boundary checks. Foundry executions of formal-test functions are ordinary
  concrete/fuzz test evidence here, not a fresh Halmos proof.
- E passes all 38 stateful invariant properties across the single-book, multi-pool, and native
  campaigns at 256 runs and depth 64, with handler-revert failure enabled. Exact results and
  settings are recorded in the accompanying validation manifest and logs.
- Public ABI and canonical storage layout are unchanged from the bounded baseline. The new
  structs are call-local memory contexts, not persistent fields.
- No source-bound SMT registry, Halmos campaign, full coverage gate, Slither gate, or CI rollout
  is claimed for these prototypes. The new delta identities and unchecked-width casts need their
  production proof bindings reviewed before promotion.

Solc 0.8.28 initially hit `Tag too large for reserved space` while compiling the large instrumented
test harness. The comparison-only validation patch loads the observer runtime from its compiled
artifact and uses forge-std artifact deployment for the three gas-fixture constructors, avoiding
embedding duplicate creation bytecode in the inherited test contract. Constructor execution is
preserved. No assertions are removed, and this patch does not affect the frozen gas measurements.
The original compiler-failure log is retained with the evidence.

Before merging an implementation, apply the chosen candidate and its test-harness adaptation,
add the new arithmetic/source bindings, and rerun the complete release verification gates. The
current working contract intentionally remains unchanged while these options are investigated.

## Further Candidates Not Yet Measured

1. Carry the matched leaf and known successor nonce into hook tracking, avoiding redundant
   rightmost-leaf searches for partial fills. Callback amounts, ordering, and both-side match/rest
   behavior must remain identical. Existing callbacks are not to be removed to obtain savings.
2. Hoist the branch-serial classification threshold into the per-operation context rather than
   repeatedly reading the same packed book state. This targets bounded repeated warm reads,
   not descendant enumeration, and the extra argument/memory cost must be checked.

None of these suggestions assumes a saving or relaxes exact summaries, rounding, nonce identity,
or the 64-level expansion bound. Returning to dirty summaries would recreate the deferred-work
problem rather than improve this bounded design.

See [the evidence directory](bounded-gas-opportunities/README.md) for cumulative source patches,
the validation-harness patch, per-test observations, compiler fingerprints, and reproduction notes.
