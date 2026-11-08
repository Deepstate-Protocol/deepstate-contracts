# Pre-Merge Checks

All five measured stages are retained. This change is for review, not a merge or deployment.
The source fingerprint remains
`ce755182dd007c3c578b860782ef3c9e45de2aae3287a3a4ef03fede6138b0c7`.

Completed functional, fuzz, invariant, traversal-bound, snapshot, SMT, ABI, and persistent-layout
checks are recorded in `raw/validation-manifest.json`. Formatting and evidence regeneration were
checked again before commit.

Additional pre-push checks found unresolved merge blockers:

- Slither reports default-initialized locals in matching, cancellation, insertion, and branch
  creation. The previous remote revision already failed on two local-initialization findings;
  the current implementation must receive its own review and a passing static-analysis result.
- `make coverage-check` fails during minimal-IR compilation with a Yul stack-depth error in
  matching. Coverage thresholds have not been lowered, findings have not been suppressed, and
  stale line-based exclusions have not been silently refreshed.

The failed command output is retained in `raw/prepush-slither-pinned.log`
and `raw/prepush-coverage.log`. These failures are not gas savings
or passing security checks. A fresh Halmos run and the full remote CI result remain outstanding.
