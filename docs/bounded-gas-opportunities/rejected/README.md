# Rejected Experiments

These patches are retained only to reproduce historical measurements. They are not selected
implementation candidates and must not be applied with the selected E patch.

- `zero-delta.patch` adds the excluded internal quote-cache guard.
- `dead-code-removed.patch` was a bytecode-identity experiment built on that excluded variant.
  It is not a cleanup patch for the selected implementation.

The guard concerned an internal rounded quote delta, not the incoming order quantity. Existing
input validation is unchanged; no additional validation is introduced by retaining this evidence.

The [complete archived gas table](ZERO_DELTA_GAS.md) records every case, including the overhead
on nonzero-delta operations. The source patches, raw observations, and original checksums are
preserved so the rejected experiment remains auditable.
