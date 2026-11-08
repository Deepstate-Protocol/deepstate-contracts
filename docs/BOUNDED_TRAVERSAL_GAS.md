# Bounded Traversal Gas Comparison

The [full 200-test workup](FULL_GAS_WORKUP.md) supersedes this selected-case report and includes
the large-book cases, complete Solar matrices, and access-list studies. This earlier report uses a
different frozen harness; do not mix its absolute gas columns with the full workup. The capped-gas
row in the companion CSV is a failure/success check, so its percentage deltas are now left blank.

## Method

- Master: `bf18c54b13123de5ecc3e05dcff6822436e0cd27`.
- Immediately before this fix: `fb144e9e7dc7c9e452efc2b22ced86b811124e13`.
- After: exact mixed-quote caches, exact branch summaries, single-boundary matching, and single-descent witness insertion in this commit.
- All primary columns: solc 0.8.28, via-IR, optimizer 200, Cancun, Forge executor `d3167db683c001c196126c912027437a9cb0bfb9`.
- Identical benchmark contracts, mock tokens, public order sequences, and `--isolate` settings. Only the engine runtime is replaced, before populating books.
- 178 tests pass per runtime. [The CSV](BOUNDED_TRAVERSAL_GAS.csv) removes 66 inherited duplicates, leaving 112 distinct cases. The existing 5,000-order benchmarks are separate release snapshots, not part of this controlled comparison.
- The optional Solar CSV column uses experimental 0.3.0 (`e7a91fc7`, Solidity 0.8.38) with the same pinned executor, not a different Forge gas model.

These controlled numbers are separate from release `.gas-snapshot.runtime` and
`.gas-snapshot.solar` numbers. Changing test-contract dispatchers, helpers, mock bytecode, or the
executor can otherwise contaminate an implementation/compiler delta.

## Results

| Scenario | Master | Before Fix | After Fix | vs Master | vs Before |
|---|---:|---:|---:|---:|---:|
| Single-maker full match | 77,374 | 77,216 | 75,086 | -2.96% | -2.76% |
| Single-maker partial match | 97,288 | 97,130 | 95,000 | -2.35% | -2.19% |
| Empty-book bid rest | 152,549 | 152,672 | 152,563 | 0.01% | -0.07% |
| Single bid cancel | 39,819 | 39,861 | 39,845 | 0.07% | -0.04% |
| 1,024-price sweep | 8,962,127 | 9,255,830 | 99,031 | -98.90% | -98.93% |
| 4,096-price sweep | 35,572,680 | 36,748,047 | 98,975 | -99.72% | -99.73% |
| 1,024-price sweep and rest | 9,014,046 | 9,307,810 | 150,919 | -98.33% | -98.38% |
| 4,096 sweep, rest, fees, two exhausted hooks | 36,063,805 | 37,239,303 | 616,585 | -98.29% | -98.34% |
| 64-level rest after prior fills | 3,929,483 | 806,897 | 874,932 | -77.73% | 8.43% |
| Deep off-spine partial fill | 3,255,484 | 646,402 | 876,708 | -73.07% | 35.63% |
| 64-level native partial fill | 394,285 | 369,342 | 772,697 | 95.97% | 109.21% |
| 64-level native cancel after fills | 356,559 | 337,437 | 770,624 | 116.13% | 128.38% |
| 64-level bid cancellation | 423,159 | 399,374 | 887,409 | 109.71% | 122.20% |

Full sweeps no longer scale with the number of distinct prices. Small variations between widths
come from settlement/control flow, not descendant quote walks.

Exact summaries are a tradeoff, not a universal gas reduction. Deep partial fills and cancellations
write surviving ancestor summaries and mixed quote caches, making several such cases substantially
more expensive than before this fix. Sweep and repair-heavy insertion cases become much cheaper.
The highest measured controlled case is **911,124 gas**, full-depth bid cancellation with the suite's
ordinary hook. That is not a certified maximum for every transaction, token, hook, epoch, or route.

## Bound

The key is 32 price bits plus 32 nonce bits, so a path has at most 64 expanded branches.
Every branch quantity and worst tick is exact; mixed branches cache the sum of leaf-rounded quotes.

A whole crossing subtree that fits the quantity budget is consumed without expansion. Otherwise
only one boundary child can expand. A surviving right child exhausts quantity or reaches the price
limit; the left child is visited only after the right disappears. A fully consumed sibling was
therefore handled in O(1).

Insertion descends once to a witness leaf and places its first differing bit on unwind. Cancellation
follows one path and rebuilds summaries on unwind. There are no repeated descendant-key searches,
dirty recovery probes, or materialization walks.

`BoundedTraversal.t.sol` counts expansions in a test-only subclass. It exercises a complete 64-level
path with globally unique live nonces, quantity/price boundaries, a 4,096-leaf sweep with zero expanded
branches, exact cached quotes, maker claims, and zero residual collateral. Another regression gives
a 1,024-price sweep a one-million-gas call budget.

This is **not 64 total SLOADs**. Pointer fields, sibling summaries, and optional top-order lookups
add bounded storage work. Routes add work per leg. The existing hook ABI is unchanged: matching
one side and resting on the other can invoke two separately capped callbacks for the same book.

## Deployment And Compatibility

`Branch` gains a quote-cache word. Use fresh books; do not substitute this runtime into populated
legacy storage without rebuilding mixed summaries.

Public actions and hook signatures are unchanged. Full mixed sweeps emit the existing
`AskSubtreeMatched` / `BidSubtreeMatched` summaries more frequently. Consumers must handle those
events rather than assume one event per maker.

Fresh-history differential tests build empty books independently under each runtime and compare
payouts, token transfers, fees, and hook notifications. Only intentional engine event grouping and
retired dirty flags are normalized. Stateful reference-model invariants independently check
priority, remaining quantities, collateral, and exact branch summaries.

## Local Validation

- 573 behavioral tests pass with solc and 573 with Solar; the updated unique-nonce 64-level fixture also passes separately with each compiler.
- 188 release gas cases pass with each compiler; both checked-in snapshots are refreshed.
- 256 fresh-history differential runs pass per compiler, plus three storage-read/hook audits.
- All 32 single-book invariant properties pass at 32 runs, depth 64, with 2,048 handler calls and no unexpected reverts. Native and multi-pool models pass at 64 runs, depth 128. A larger single-book depth-128 local campaign was interrupted in favor of the standard-depth pass.
- 1,258 source-bound SMT obligations and 26 production-bytecode symbolic tests pass.
- Adjusted coverage gates pass at 100%; raw engine coverage is 85.34% of lines. Exclusions cover executed assembly/source-mapping artifacts and the optimized-away empty observer, not an omitted matcher branch.
- Formatting and whitespace checks pass. The full 2,048-run sharded campaign and Slither remain CI checks, not completed local checks in this report.
