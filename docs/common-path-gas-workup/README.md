# Common-Path Optimizations

## Scope

The baseline is branch commit `b4164fe`, after the previously accepted bounded-tree
optimizations. It is not the deployed Robinhood bytecode or a new master baseline.
All gas comparisons use Solar and the same frozen fixture and executor.
Both common-path optimizations are included in the selected implementation.

The production-shaped cases reuse the preceding study's snapshot of 222 indexed
NVDA/USDG orders, plus two test quotes. They use mock tokens and a counting hook,
not the full Rewarder V3. These are controlled source comparisons, not historical
transaction replays. Category frequencies do not establish the distribution of
individual bid/ask variants or an overall weighted savings percentage.

## Change 1: Reject Non-Crossing Hooked Matches

Hook accounting already looks up the best opposite-side leaf before matching.
Its exact tick is sufficient to reject a non-crossing order: every bid is at most
the best bid, and every ask is at least the best ask. The shortcut therefore
avoids a second boundary walk and match-buffer allocation without another lookup.
Incoming-order validation still occurs first. Equality remains matchable. Empty
opposite sides also skip the unused match buffer.

The route regression test follows a rejected non-crossing leg immediately with
an exact-best partial match and checks hook accounting and token balances. The
walk-observer test checks that the rejected leg performs no matching-boundary
expansions. Two source-bound SMT lemmas check the price implications.

## Change 2: Capture The Cancellation Successor While Unwinding

For a removed best leaf, the first parent that loses its right child exposes the
untouched left sibling containing the new best leaf. Capture that sibling's best
nonce at this point, instead of looking it up again from the resulting book root.
Higher ancestors have a surviving right child, so they cannot repeat the lookup.
A root leaf has no successor and retains the initialized zero nonce.

Only hook-enabled cancellation requests track this successor. Unhooked books do
not perform the lookup; a storage-read regression test checks that the sibling
subtree's child slots remain unread. The extra bookkeeping still has a measured
cost on unhooked cancellation, including up to 3,483 gas in the full-depth cases.

The randomized cancellation test independently scans remaining orders to check
every successor, FIFO ties, callback count, sold token and outgoing amount on both
sides. This changes call-local memory only, not persistent storage or the ABI.

## Bounds And Evidence

Neither change introduces an order-count sweep. Tree descents remain bounded by
strictly increasing split positions in the 64-bit price/nonce key. The successor
walk is within one untouched sibling, not a fresh traversal for every ancestor.
Exact summaries, token rounding and hook dispatch remain on their existing paths.

`FINAL_GAS_TABLES.md` and `FINAL_GAS_DELTAS.csv` contain all 223 baseline-versus-combined
results. `GAS_TABLES.md` retains the baseline and both cumulative stages, including
unchanged cases and regressions. Forty-two Wide Sweep rows
repeat inherited cases; the gas-budget check is functional rather than a separate
workload. `STAGE_DELTAS.md` also gives each change's incremental delta.
All 23 production-shaped economic-state fingerprints agree across all stages;
these fingerprints are not a proof of complete state equivalence.

Raw sources, patches, logs, snapshots and hashed manifests are under `raw/`.
The report generator is `script/build_common_path_gas_workup.mjs`; its manifest
requires matching source, fixture and executor hashes and a reproduced baseline.
`raw/baseline-control.json` retains all 223 baseline control values from the
preceding comparison, so regenerating this report does not require that separate
report to be present.
The final validation manifest records behavioral/fuzz tests, bounded-walk tests,
stateful invariants, release snapshots, compositional SMT checks, formatting, ABI
and persistent storage-layout checks.

The existing default-build Yul stack-depth failure is separately captured in
`raw/prepush-formal-build.log`. This work does not claim fresh coverage, Slither
or Halmos passes, or resolve that pre-existing release blocker.
