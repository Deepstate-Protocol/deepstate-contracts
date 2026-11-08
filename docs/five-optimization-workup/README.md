# Five Bounded Optimizations

The working engine implements all five cumulative stages on top of candidate E. No optional
zero-delta quote-cache guard is included. There are no public ABI or persistent storage additions.

1. Share the resting factor and exact quote between domain validation, insertion, branch creation,
   and bid collateral settlement. Domain validation is retained.
2. Carry an insertion's known displaced top and a partial match's known surviving nonce. A successor
   not visited by matching still receives a bounded lookup; hook amounts and ordering are unchanged.
3. Cache the branch-classification front per operation. Refresh it after allocation and avoid leaf
   sentinel storage probes. There is no cross-operation or cross-book classification cache.
4. Carry loaded branch slots and split depths through unwinding, retaining checked quote-cache
   arithmetic and writing only the changed child pointer.
5. Keep the growable match buffer pointer in the per-leg memory context, preserving match records,
   flush order, and route-leg isolation without transient buffer-pointer reads and writes.

## Measurements

The baseline is the approved E source, SHA-256
`45d978cb4e482bb2ad0d0a76e5e82eac26da8739b86e65f09fae1d6ba10d1f70`, not master or the pre-E source.
All 200 baseline values reproduce the earlier measurements exactly. Each of five stages is compared
with that baseline and the preceding stage: 1,000 comparisons from 1,200 benchmark executions.
These are cumulative stages, not independent isolated implementations of each idea.

All engine runtimes are compiled with Solar 0.3.0 / Solidity 0.8.38, Cancun, optimizer 200. Every
gas run uses the same frozen fixtures, mocked tokens, setup, calldata, and Forge executor
`d3167db683c001c196126c912027437a9cb0bfb9`. Only the engine runtime is replaced, before seeding.
The inherited repetitions and functional capped-gas check are retained and labeled, not filtered.
Counts and case averages are not production-volume-weighted savings.

- `GAS_TABLES.md`: every test, before/after gas, absolute/percentage deltas against E and the prior stage.
- `CHAT_TABLE.md`: every test with baseline first and one column per cumulative change.
- `GAS_DELTAS.csv`: the same 1,000 comparisons in structured form.
- `summary.json`: all-case change counts and extrema, without a threshold filter.
- `manifest.json`: source/runtime fingerprints and raw-output hashes.
- `raw/`: source captures, incremental patches, run manifests, logs, and snapshots.

The release snapshots in the repository use their native release harness and are not mixed into
this frozen-fixture comparison. The artifact-based test deployment adaptation avoids duplicated
creation bytecode in inherited harnesses; no assertion or constructor is removed.

## Reproduce

Use the frozen fixture documented in `../gas-workup/README.md`. Build each captured source with
the same Solar version and settings. Set `GAS_OPPORTUNITY_ROOT` to a directory containing the
captured `variants/<name>.sol` sources and an empty `results/` directory. For each stage, run:

```sh
GAS_OPPORTUNITY_ROOT=/path/to/study \
GAS_COMPARISON_BASELINE=candidate-E:45d978cb4e482bb2ad0d0a76e5e82eac26da8739b86e65f09fae1d6ba10d1f70 \
node docs/bounded-gas-opportunities/measure.mjs STAGE /path/to/artifact.json solar
node script/build_five_optimization_workup.mjs /path/to/study docs/five-optimization-workup
```

`script/validate_five_optimizations.mjs` records behavioral/fuzz tests, instrumented bounds,
stateful invariants, release snapshots, source-bound SMT checks, formatting, and ABI/layout checks.
Its validation manifest records the exact working source hash. These checks do not constitute a
fresh Halmos or full CI result. The additional pre-push Slither and coverage attempts failed;
see `PRE_MERGE_CHECKS.md`. The successful functional checks do not override those blockers.
