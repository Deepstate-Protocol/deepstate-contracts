# Bounded Gas Opportunity Evidence

The [report](../BOUNDED_GAS_OPPORTUNITIES.md) preserves the original exploratory prototypes, not a
deployment. Candidate E is the baseline for the subsequent working-source implementation in
[Five Bounded Optimizations](../five-optimization-workup/README.md).

## Contents

- `selection.json`: the selected E patch and source fingerprint. The zero-delta guard is excluded.
- `raw/*.patch`: six cumulative A-E source stages, each based on `096eab2`. Choose one; do not
  apply them sequentially. `uniform-difference.patch` contains the selected combined prototype,
  with no zero-delta quote-cache guard.
- `rejected/*.patch`: historical experiments, not implementation candidates. The zero-delta
  variant and the dependent dead-code identity experiment must not be applied with E.
- `raw/validation-harness.patch`: artifact-based test deployments plus two focused early-split
  counter tests. This is only for validation, not the common gas comparison fixture.
- `raw/*-manifest.json`: source/runtime fingerprints, compiler metadata, executor revision,
  log/snapshot hashes, and test counts.
- `raw/*.snapshot` and `raw/*.log`: all benchmark observations and final validation output.
- `raw/compatibility.json`: raw before/after storage layouts and ABI/layout equality results.
- `STORAGE_ACCESSES.csv` and `raw/storage-*.log`: 15 successful ordered storage-access observations
  across baseline, E, and the zero-delta candidate. These logs' test gas totals are not canonical
  isolated gas measurements and are not used in the gas comparison CSV.
- `raw/dead-code-check.json`: executable-bytecode identity after removing an unused helper,
  with Solidity's length-delimited CBOR metadata excluded from the comparison.
- `summary.json`: historical independent-case summaries, counts, peaks, and validation results.
  It retains the rejected F experiment; `selection.json` defines the actual candidate selection.
- `delta-table-manifest.json`: rendered-table row counts and output fingerprints.
- `evidence-sha256.json`: checksums for every raw evidence file.
- `measure.mjs`, `validate.mjs`, `compatibility.mjs`: scripts used for the measurements and checks.

Original whitespace is preserved in logs and patches so fingerprints and patch context remain
verifiable. Whitespace checks are disabled only for those captured files.

## Reproduce

Use a disposable project with the source, tests, configuration, and locked dependencies at
`096eab28d87debdd472b4e22e65820e2b1b8d523`.

For behavioral/bound validation, apply `uniform-difference.patch` and the validation-harness patch.
Run the filters/settings recorded in `raw/validation-manifest.json`. These include the five bound
tests, behavioral tests, and invariant campaigns with 256 runs, depth 64, and handler-revert failure
enabled. The historical compiler failure relates to the unadapted instrumented test harness, not
a failure in the successfully compiled and benchmarked engine runtime.

For gas comparisons, build each source candidate with solc 0.8.28, via-IR, optimizer 200, Cancun.
Build the final Solar candidate with the opt-in Solar profile and the same Solar revision listed
in its manifest. Solar 0.3.0 reports Solidity 0.8.38 and warns about the exact 0.8.28 pragmas; it
remains an experimental comparison, not a compiler-migration recommendation.

Use the original frozen gas fixture described in [the full workup evidence](../gas-workup/README.md),
not the newly adapted validation fixture. All candidate runtime replacements occur before seeding.
The original batched large-book setup, isolation flags, mock code, and benchmark dispatcher stay
fixed. Use Forge `d3167db683c001c196126c912027437a9cb0bfb9` for every gas execution, including
Solar runtimes.

`measure.mjs` accepts a variant name, its engine artifact path, and optional `solar` argument.
It verifies source Keccak, compiler settings, frozen fixture hashes, 188+12 passing rows, and raw
snapshot/log hashes. Place the selected source in `variants/<name>.sol` under the experiment root.
The script supports `GAS_OPPORTUNITY_ROOT`, `GAS_FIXTURE_ROOT`, `GAS_BASELINE_RAW`, `GAS_FORGE`,
and `GAS_CAST` to point at reproduced directories and pinned binaries. The validation/compatibility
scripts retain the local experiment paths as provenance; adjust those roots when reproducing.

The complete CSV includes eight datasets of 200 rows. Exclude `included_in_summary=false` when
calculating independent-case statistics. A negative delta means less gas than the bounded baseline
under the same compiler. Case counts and medians are not production-frequency-weighted savings.
The `status` column identifies selected, intermediate, and rejected datasets. Every row also has
preceding-stage deltas and the controlled master comparison; failed master budget checks have no
successful-operation percentage.

## Complete Tables

The [full rendered report](../BOUNDED_GAS_DELTA_TABLES.md) includes 400 selected E rows across
solc and Solar, plus all 1,000 intermediate-stage rows. All 200 rejected F rows are retained in
the separate [archived table](rejected/ZERO_DELTA_GAS.md). No gas threshold filters these tables.

Regenerate the complete Markdown tables, CSV, and table manifest from committed evidence:

```sh
node script/build_bounded_gas_delta_tables.mjs
```

This verifies the raw snapshot/log hashes, matching 200-case sets, compiler settings, selection
fingerprint, and the absence of the rejected guard in E. It does not run new benchmarks or edit
the contract.

For the storage study, add `raw/StorageAccessProbe.t.sol` to the original frozen fixture and use
`run-storage.mjs` with the corresponding engine runtime artifacts. The probe pauses gas metering
during setup and records only the target operation's engine storage accesses. The initial unpaused
setup failure is retained separately and is not one of the 15 observations.
