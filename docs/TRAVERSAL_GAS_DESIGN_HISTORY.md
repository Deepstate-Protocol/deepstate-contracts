# Why Mixed-Price Sweeps Became Width-Dependent

Investigation date: 2026-11-07. Historical baseline: master `bf18c54`.
This is a retrospective investigation, not another contract change or deployment.

## Conclusion

The large mixed-price sweep cost was not introduced by Solar, the recent nonce-addressed
branch changes, or one recent arithmetic bug. Width-dependent matching exists in the first
implementation, `55fdca7` (June 27). The June 29 aggregate-consumption optimization retained
a recursive quote calculation for mixed-price subtrees rather than adding a stored value sum.

The clearest recorded rationale is **compact quantity-only branch summaries instead of
maintaining both subtree quantity and subtree quote value**. That made some state updates
cheaper, but exact mixed-price settlement still needed descendant reads. Later right-spine
optimizations separately saved immediate branch-rewrite costs by deferring repair work.

This was an explicit limitation in the earliest whitepaper, not something the history lets us
attribute solely to an accidental new regression. Relative to the intended requirement that a
single-book sweep have work independent of book width, it is a design/requirements failure.
Documenting a weaker bound does not satisfy the stronger requirement.

## Evidence Versus Inference

- **Verified:** the initial matcher can execute both children and visit every consumed leaf.
- **Verified:** the June 29 mixed-subtree consumer recursively visits both children.
- **Verified:** the first whitepaper calls quantity-only exact settlement a storage tradeoff
  and explicitly identifies a second value aggregate as the way to obtain the stronger bound.
- **Verified:** the June 30 right-spine PR deliberately keeps stale branch summaries to avoid
  rewriting ancestors, with repair before insertion.
- **Verified:** the July 10 code says that mixed quote calculation still visits every mixed child.
- **Verified:** the merged proof registry explicitly allows mixed-subtree work proportional to
  descendants and an out-of-gas revert on sufficiently large books.
- **Assessment:** storage compactness, local gas reductions, and functional accounting correctness
  were maintained without enforcing the desired end-to-end, width-independent work invariant.
- **Not established:** who approved sacrificing that invariant, whether the original prompt
  required it explicitly, or the private reasoning behind each implementation choice. Git authorship
  and merged PRs do not establish those facts. No such approval record was found in the sources
  and PR discussions reviewed here.

## What The Representation Could And Could Not Answer

An exact sweep needs both:

```text
Q(subtree) = sum(remaining maker base quantities)
V(subtree) = sum(exact remaining maker quote liabilities/proceeds)
```

The old packed summary stored `Q`, a price/path component, and eventually a same-tick rounding
correction. It did not store `V` for a mixed-price subtree. Its `Branch` storage held the two
child pointers, not an additional mixed quote total.

`Q` says whether the taker has enough quantity to consume a subtree. It does not say how much
quote must change hands across different prices. Even before logarithmic ticks and rounding,
two units at prices 1 and 3 have a different value from two units at prices 2 and 3.

For a uniform-price subtree, quantity and one price suffice before rounding; after tick pricing,
the correction code preserves the sum of leaf-rounded quotes. For a mixed-price subtree, a
single price and that same-tick correction do not encode the needed weighted sum. The old
implementation therefore recovered value by walking children until reaching leaves or uniform
subtrees.

The packed `bytes32` summary should not be confused with the whole storage footprint: the old
branch already had two storage words for pointers. Keeping the external packed word does not
mathematically prohibit a separate quote-cache word. Omitting that word was the representation
choice, not a fundamental limitation of radix trees.

The original paper states this directly in its
[quantity-only settlement discussion](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/6f0977368084ae845f725e2b99a814f494878f32/paper/radix_matching_whitepaper.tex#L517-L557):

> This corollary is not a defect in the mathematical model; it is a storage-design tradeoff.

The same passage distinguishes quantity-only `O(h + z)` settlement from a fully aggregated
quantity-and-value design, where whole subtrees can be settled without examining their leaves.
That is the strongest contemporaneous evidence of the reason for the tradeoff.

## Timeline

Dates below are original author dates, not later rebase dates.

| Date | Change | Relevance |
|---|---|---|
| June 27 | [`55fdca7`, initial implementation](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/55fdca72e3c4ef4d680ef02dae19bf4207e4a21e) | `_matchBranch` matches the right child, then the left if liquidity remains to consume. The original matcher already has filled-order-dependent work. |
| June 29 | [`ff02b8d`, same-price aggregates](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/ff02b8d764f966f47e0c5bdc3d1bc74ad764c8dd) | Adds a shortcut for uniform-price subtrees. It does not supply a mixed-price value aggregate. Uniformity detection itself initially walks boundary paths. |
| June 29 | [`945de70`, one-traversal consumption](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/945de700b06116895dc592dce52d873119b6dfd1) | Replaces repeated best-order matching with a recursive subtree matcher. Its new `_consumeSubtree` still descends both children for mixed prices. This improves traversal organization without establishing a width-independent bound. |
| June 30 | [`6f09773`, first whitepaper](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/6f0977368084ae845f725e2b99a814f494878f32) | Explicitly contrasts quantity-only compact storage with double-sum bounded matching and describes the missing value aggregate. This predates the dirty-spine optimization. |
| June 30 | [`944b31b`, right-spine optimization](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/944b31bd4e5adaf51a6063f8d9d1f37eaf3e32df) | Keeps existing branch anchors when only the right child changes. Summaries become stale; same-side insertion repairs them first. This is a separate deferred-cost tradeoff. |
| June 30 | [`f113698`, dirty aggregate recovery](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/f11369861313d6160e5741010f0e8231ae6a8710) | Initially recovers dirty quantities by recursively visiting both children. Its comment says recursion is simpler despite exact left summaries being available. This creates an additional, avoidable width-dependent recovery path. |
| July 9 | [`7275498`, logarithmic ticks](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/7275498ac9d776fadd1b3f832f64a41f263bce14) | Adds exact same-tick quote corrections and leaf-level rounding rules. Replaces the full dirty quantity scan with `_dirtyRightSpineData`, which uses exact left summaries and recurses only right. Mixed-price quote sums still recurse across descendants. Tick arithmetic is not the origin of that traversal. |
| July 10 | [`67bb9d3`, compact reporting](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/67bb9d337cd8740034e8b4fed0c2ca18e60adb4e) | Separates `_subtreeQuote` from event reporting. One summary event replaces many logs, but quote calculation still recursively reads mixed descendants. Fewer events is not fewer quote reads. |
| July 12-13 | [`1305756`, updated paper](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/1305756f441b2343fe794c20bb11eac4572e0c90), and [`f205589`, proof registry](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/f2055891f586d336b47e1ec67eb62146b9ae75a5) | Continue to state the mixed-descendant complexity explicitly. Proofs establish accounting and termination under their stated assumptions, not a constant-cost sweep theorem. |
| August 14 | [PR #31, dirty-spine regressions](https://github.com/Deepstate-Protocol/deepstate-contracts/pull/31) | Records the observed native rest at 528,120 gas and a pathological dirty-spine rest at 3,931,430 gas in that historical harness. The deferred-repair problem was known separately from mixed sweep width. |
| September 15, rebased November 7 | [`fca5afb`, stable branch identities](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/fca5afb0fa7798e3a67f1fc1773799673927cbb4) | Avoids relocating child-pointer slots on summary changes. Initially adds descendant-key recovery for routing. The mixed quote recursion already exists and is retained, not originated here. |
| November 7 | [`096eab2`, bounded traversal](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/096eab28d87debdd472b4e22e65820e2b1b8d523) | Adds exact mixed quote caching and exact summaries, removes dirty repair, and replaces repeated routing-key searches. This changes where value-computation work is paid, with the routine-operation regressions recorded in the full workup. |

An earlier July 8 experiment, [`948988b`](https://github.com/Deepstate-Protocol/deepstate-contracts/commit/948988b2bdf2282c917b6acc639a096dba95a797),
also replaced the full dirty quantity scan with a right-only recovery helper. It is **not an
ancestor of master `bf18c54`** and is not counted as the merged fix. The actual merged transition
is visible by comparing `7275498^` with `7275498`. This distinction was checked explicitly rather
than inferred from chronological `git log --all` output.

## Three Different Costs Must Not Be Conflated

### 1. Mixed-Price Quote Enumeration

This is the source of the wide-sweep blowup. The initial aggregate consumer does:

```text
if leaf: return leaf quote
if uniform-price subtree: return aggregate quote
otherwise: return consume(right) + consume(left)
```

Both recursive calls are visible in
[`945de70`, lines 539-558](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/945de700b06116895dc592dce52d873119b6dfd1/src/RadixMatchingEngine.sol#L539-L558).
The same structure survives in master's
[`_subtreeQuote`, lines 1702-1724](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/src/DeepstateV1.sol#L1702-L1724).

A depth-first traversal can have at most 64 active branch levels while still visiting thousands
of nodes in total. A small call stack, or structurally unlinking a subtree through one pointer,
does not make its recursive value calculation constant work.

### 2. Dirty Right-Spine Repair

The old branch mapping was keyed by the packed summary itself. Changing quantity could change
that key and require rewriting pointer storage and ancestors. [PR #3](https://github.com/Deepstate-Protocol/deepstate-contracts/pull/3)
explicitly saves those writes by retaining stale anchors and repairing them before a subsequent
same-side insertion.

That can move costs from a fill or cancellation onto a later insertion. Its historical headline
gas savings are not a lifecycle cost guarantee. Mixed dirty branches cannot safely use stale
quantities as exact aggregates, so matching falls back to child pointers.

Important qualification: master's dirty same-tick recovery already follows only the right spine
and trusts exact left summaries. It is depth-bounded. The original full dirty-quantity scan was
removed in July. It would be inaccurate to blame every remaining wide sweep on that old helper
or to say that every dirty operation is width-dependent.

### 3. Repeated Descendant-Key Discovery

Stable nonce-addressed branches stopped using a descendant's nonce as the branch identity.
The first version recovered real routing keys by finding descendant leaves. Repeating a bounded
helper at successive levels can multiply traversal work even though each individual walk ends
within the key width. This is a separate nested-work problem, not the `O(m)` mixed-quote scan.

Later depth caching, branch rewrite optimizations, and repair/insertion fusion reduced these
costs. They did not add the missing mixed-price value cache. Solar likewise changes compiled
instruction cost, not which descendants the algorithm needs to inspect.

## The Strongest Direct Acknowledgements

The July 10 comment preserved in master says:

> Quote calculation still visits every mixed child

See [master, lines 1680-1682](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/src/DeepstateV1.sol#L1680-L1682).
The same PR's purpose was to reduce log costs; [PR #13](https://github.com/Deepstate-Protocol/deepstate-contracts/pull/13)
explicitly describes replacing direct per-maker enumeration with mixed-subtree summaries.

The proof registry is even more explicit. Its E4 section says exact mixed-price quote calculation
is proportional to mixed descendants, and that sufficiently large trees can exceed block gas
and revert. See [master, lines 267-278](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/docs/PROOF_OBLIGATIONS.md#L267-L278).

The SMT termination checks distinguish decreasing depth from decreasing subtree size. Proving
both terminate does not prove a limit of 64 total visits. See
[`prove_termination_measures`](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/script/prove_protocol.py#L1300).

Consequently, passing the documented formal checks was not evidence that an end-to-end constant
work bound held. The stated theorem already allowed a weaker property.

## Why The Existing Gas Tests Did Not Establish The Desired Bound

- The old large random books contained 5,000 orders per side, but the match benchmarks consume
  only the best maker or part of it. They do not sweep thousands of distinct prices.
  See [master gas tests, lines 181-236](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/test/RadixMatchingEngineGas.t.sol#L181-L236).
- The full-depth comb fixtures contain one target and one sibling per level, roughly 65 leaves.
  They exercise maximum depth, not maximum work at a given depth.
  See [fixture construction, lines 607-646](https://github.com/Deepstate-Protocol/deepstate-contracts/blob/bf18c54b13123de5ecc3e05dcff6822436e0cd27/test/RadixMatchingEngineGas.t.sol#L607-L646).
- Same-price aggregate tests exercise the very case for which a compact quote summary exists.
- Accounting, priority, conservation, and rollback checks can all pass for an exact but expensive
  algorithm. Coverage and finite termination do not establish width-independent cost.
- The canonical suite did not have the new 64/256/1,024/4,096-price scaling series. Those cases
  and explicit traversal instrumentation were added in `096eab2`.

These observations identify an assurance gap; they do not prove that no one had ever measured a
large mixed sweep outside the repository. The documented limitation itself was already known.

## Connection To The Measured Gas Results

The previous [full workup](FULL_GAS_WORKUP.md) already measures this behavior using one controlled
harness. These are existing solc observations, not new runs performed for this investigation:

| Distinct prices swept | Master `bf18c54` | Pre-fix `fb144e9` | Cached `096eab2` |
|---|---:|---:|---:|
| 64 | 648,416 | 666,599 | 98,631 |
| 256 | 2,313,793 | 2,387,080 | 99,331 |
| 1,024 | 8,962,743 | 9,256,446 | 99,647 |
| 4,096 | 35,573,912 | 36,749,279 | 100,207 |

The old implementation's near-linear growth is consistent with the documented descendant scan.
The new value cache removes that sweep-time enumeration, but pays for exact summaries during
mutations. The routine-operation regressions in the full workup are therefore important evidence
of the other side of the tradeoff, not something to omit from the design decision.

## Classification And Remaining Questions

**Classification:** a longstanding storage/representation tradeoff that fails the desired
width-independent liveness requirement, compounded by separate deferred-maintenance and routing
costs. Not a newly introduced Solar issue, not inherently a multi-book hop, and not evidence by
itself of incorrect asset accounting.

"Unbounded" here means not bounded by a small constant number of radix levels. The nonce space,
finite state, and transaction gas limit are finite. A failed sweep reverts atomically; those facts
do not provide a useful, book-width-independent execution guarantee.

What remains unknown is whether the weaker settlement bound was ever explicitly accepted as a
product requirement. The available history documents the compromise, but does not establish that
acceptance. It also does not establish an actual production denial-of-service incident or identify
deployed bytecode; this investigation is about source history, not a deployment audit.

Future design review should require a stated per-book work invariant covering every helper,
increasing-width mixed-price tests, instrumented visit counts, and routine-operation plus lifecycle
gas comparisons. A depth-only theorem or a cheaper selected benchmark is not a substitute.

## Reproduction Notes

This investigation used read-only Git history, source inspection, and GitHub PR reads. Relevant
commands include:

```sh
git log --follow -- src/DeepstateV1.sol
git show 55fdca7:src/RadixMatchingEngine.sol
git show 945de70 -- src/RadixMatchingEngine.sol
git show 944b31b -- src/RadixMatchingEngine.sol
git show f113698 -- src/RadixMatchingEngine.sol
git show 948988b -- src/RadixMatchingEngine.sol
git show 6f09773:paper/radix_matching_whitepaper.tex
git blame bf18c54 -L 1677,1724 -- src/DeepstateV1.sol
git blame bf18c54 -L 267,278 -- docs/PROOF_OBLIGATIONS.md
git log bf18c54 -S 'function _subtreeQuote' -- '*.sol'
gh pr view 3 --repo Deepstate-Protocol/deepstate-contracts
gh pr view 13 --repo Deepstate-Protocol/deepstate-contracts
gh pr view 21 --repo Deepstate-Protocol/deepstate-contracts
gh pr view 31 --repo Deepstate-Protocol/deepstate-contracts
```

No production source, tests, snapshots, service configuration, or deployed contracts are changed
by this investigation. No additional benchmark results are claimed.
