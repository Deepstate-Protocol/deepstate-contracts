# Gas Changes

- Every gas-changing commit must include a complete per-test gas table and machine-readable CSV.
- Run the full release benchmark suite across its configured profiles, plus existing diagnostic
  cases. Measuring a selected subset does not satisfy the complete-table requirement.
- Show baseline gas, candidate gas, absolute delta, and percentage delta for every measured case.
  When changes are staged, also show the delta against the immediately preceding stage.
- Include unchanged cases, small changes, and regressions. Summary thresholds must never filter
  rows out of the complete tables. Mark inherited duplicates and functional budget checks.
- Identify source revisions or fingerprints, compiler settings, executor revision, and fixtures.
  Compare like-for-like workloads under the same compiler and harness; keep compiler results separate.
- Do not report failed or gas-capped operations as successful-operation savings. Keep all raw evidence.
- Display complete gas differentials directly in chat, not only as links to external reports.
  Keep the full tables and CSV in the repository as reproducible evidence.
- Use one test per row, with baseline first and a separate column for each cumulative change.
  Show each change's gas and delta versus baseline; never pack multiple stages into one cell.
- Use Solar-compiled results for user-facing gas tables; do not add a compiler-comparison breakdown.
- Preserve bounded traversal, exact summaries, rounding, and callback semantics.
- Do not include the optional zero-delta quote-cache guard from the exploratory workup in the
  selected implementation. This does not remove existing zero-input validation or add new validation.
