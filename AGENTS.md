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
- Link the complete tables in the response; a selected-case excerpt is not a complete gas report.
- Preserve bounded traversal, exact summaries, rounding, and callback semantics.
- Do not include the optional zero-delta quote-cache guard from the exploratory workup in the
  selected implementation. This does not remove existing zero-input validation or add new validation.
