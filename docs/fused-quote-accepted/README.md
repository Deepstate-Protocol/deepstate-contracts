# Fused Partial-Fill Quote Arithmetic

The baseline is parent commit `83ce527995e1e44932de281d5d732ed1afa80204`.
This commit includes only the fused partial-fill quote/event arithmetic, not the
separate experimental `cancelAndFill` API. No external ABI or persistent storage
layout changes are required.

Partial fills previously calculated both full-order notionals and the standalone
fill notional. The new helper shares the fill product between the telescoping
quote delta and the event correction bit. An exact remainder/carry calculation
preserves independent floor and ceiling rounding, including limb-boundary cases.
The existing plain quote-difference helper is unchanged. This does not change
tree traversal, summary maintenance, callback dispatch or input validation.

`GAS_TABLES.md` and `GAS_DELTAS.csv` contain every one of the 223 release,
insertion-diagnostic and production-shaped benchmark cases. All use Solar and
the same frozen executor and fixtures as the parent. Baseline results come from
the parent's validated workup; every candidate case is rerun. Unchanged cases,
regressions, inherited repetitions and the functional gas-budget check remain
in the report.

The production-shaped fixture has 222 indexed NVDA/USDG orders plus two test
quotes. It uses mock tokens, a counting hook and a 10-bps protocol fee, not the
full Rewarder V3 or historical transaction replay. Economic fingerprints cover
all 23 production-shaped cases; they are not a complete state-equivalence proof.

Raw sources, logs, snapshots, patches and source/compiler/executor/fixture hashes
are under `raw/` and in `manifest.json`. Validation includes focused fuzzing,
behavioral tests, bounded-walk tests, stateful invariants, the release snapshot,
source-bound SMT obligations, formatting, and ABI/storage compatibility checks.
The focused tests compare against an independent full-notional oracle and check
balances, events, claims and repeated partial fills.

The driver is `script/fused_quote_commit_workup.mjs`, with `measure`, `validate`,
`report` and `all` modes. Run from an isolated export of this commit with its
normal libraries installed. Set `WORKUP_ROOT`, `SOLAR_FORGE`, `GAS_FORGE`,
`GAS_FIXTURE`, `BASELINE_ARTIFACT` and `VIEM_PACKAGE_JSON` for local tool paths.
The frozen fixture fingerprints and exact compiler settings are enforced before
measurement. The parent's source and validated baseline evidence remain in
`docs/common-path-gas-workup/raw/`.

This gas optimization does not resolve the pre-existing default-build Yul
stack-depth failure recorded by the parent, nor claim new coverage, Slither or
Halmos passes. Solar validation and benchmark results are reported separately
from those outstanding release concerns.
