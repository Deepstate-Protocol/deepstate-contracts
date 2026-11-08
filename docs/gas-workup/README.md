# Gas Workup Evidence

The [full report](../FULL_GAS_WORKUP.md) and CSVs are generated from the frozen observations in `raw/`.
Contract source remains unchanged by this documentation update.

Raw logs and fixture patches retain their original whitespace so fingerprints and patch context
remain verifiable. Whitespace checks are disabled only for those captured evidence files.

## Regenerate The Report

From the repository root, using Node.js 18 or later:

```sh
node script/build_gas_workup.mjs docs/gas-workup/raw docs
```

The generator checks snapshot fingerprints, matching case sets, version references, cardinalities,
the large-fixture control offset, duplicate exclusions, and access-list accounting before writing
the report. It does not run Forge or query a chain.

## Reproduce The Measurements

1. Use the implementation and test sources at `096eab28d87debdd472b4e22e65820e2b1b8d523` as the common harness, with its locked Solady/forge-std dependencies.
2. Apply `raw/fixture.patch` to a disposable copy, and add `raw/OpportunityGasProbe.t.sol` to its `test/` directory. These changes belong only to the comparison harness, not the production contract tests.
3. Compile the engine at each of the three references listed in `raw/manifest.json`, once with solc 0.8.28 and once with Solar 0.3.0 (`e7a91fc7`, Solidity 0.8.38). Solc settings are via-IR, optimizer 200, Cancun. Source hashes and actual compiler metadata are in `raw/source-verification.json`.
4. Before seeding a book, set `VARIANT_BYTECODE` to the selected engine's deployed runtime. Set `EXACT_SUMMARIES=true` for the bounded implementation and `false` for master/the preceding implementation. The harness uses this flag only for legacy-summary assertions and the expected outcome of the capped-gas functional test.
5. Execute the commands recorded in `raw/manifest.json` with Forge `d3167db683c001c196126c912027437a9cb0bfb9`. The `forge@d3167db` command name is a descriptive placeholder for that installed binary. Output snapshot paths in the manifest are relative filenames.

All compared engines start with empty books. Do not replace runtime over a populated legacy tree:
the bounded implementation has an additional mixed-quote storage word.

The unmetered large-book seed wrapper avoids repeated expensive isolation during population. Each
measured operation is still a subsequent isolated call. Its six after-fix control observations differ
from the original release snapshots by a constant -2,463 gas. Both raw controls are retained; no
normalization or cross-harness substitution is used in the comparison.

For access-list studies, use the separate unbatched harness adjustment in `raw/access-fixture.patch`
and the commands in `raw/access-manifest.json`. Its six `testBenchmark_` functions perform their own
cold/warm preparation. Their internal execution measurements are deliberately not mixed with Forge
snapshot totals.

## Interpretation

- There are 200 rows per build: 188 release benchmarks and 12 insertion diagnostics.
- Forty-two inherited repeat rows remain available but do not influence summaries.
- The capped-gas failure/success check has no percentage saving; it is not a completed-operation comparison.
- Profiles with a configured fee can still have zero actual fees when small raw-unit quantities round down.
- The data do not establish a production-weighted average, live-chain fee quote, or universal maximum transaction cost.
