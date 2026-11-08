# Full Gas Workup

This supersedes the earlier selected-case comparison. It covers every current release benchmark scenario using one fixed comparison harness for all contract versions. **Negative deltas mean cheaper; positive deltas mean more expensive.**

## Scope And Controls

- Master: `bf18c54b13123de5ecc3e05dcff6822436e0cd27`.
- Before the bounded-traversal fix: `fb144e9e7dc7c9e452efc2b22ced86b811124e13`.
- After the fix: `096eab28d87debdd472b4e22e65820e2b1b8d523`. No contract implementation is changed by this workup.
- Six builds: all three versions under solc 0.8.28 and experimental Solar 0.3.0 / Solidity 0.8.38. All execute under Forge `d3167db683c001c196126c912027437a9cb0bfb9`, Cancun. Solc uses via-IR and optimizer 200.
- Same compiled fixtures, mock tokens, calldata, funding, isolated-call settings, and order sequences across all builds. The engine runtime is replaced before any book is populated.
- **200 test rows per build:** all 188 release benchmark rows plus 12 insertion diagnostics. The 14 dirty-matching probes from the earlier report are now covered by the release suite under base, hook, and fee profiles.
- **157 completed-operation scenarios** enter summaries: 42 inherited repeats and one capped-gas check are retained in the full tables but excluded from summary statistics.
- Six access-list studies per build are reported separately: their internally cooled/warmed execution measurements are not the same metric as a Forge snapshot.
- Large random books contain **5,000 bids and 5,000 asks**, not 5,000 orders total. Setup is unmetered. Each row measures its target operation, not the entire order lifecycle.
- Large-book population is grouped inside one unmetered outer harness call to avoid repeating expensive EVM isolation during setup. The target operation remains an isolated call. This changes harness overhead: the six solc after-fix controls differ from the existing release snapshot by a constant -2,463 gas. No normalization is applied; all versions below use the same batched harness, and its source patch and control snapshot are included with the raw data.
- Names containing `Dirty` describe the prior-fill history; the new implementation maintains exact summaries. Full-depth combs are synthetic key-depth fixtures.

Raw snapshots and access logs, source/runtime fingerprints, and build metadata are in [gas-workup/raw](gas-workup/raw). The [complete CSV](FULL_GAS_WORKUP.csv) contains absolute and percentage deltas for all three pairwise comparisons. [Compiler-only comparisons](GAS_COMPILER_COMPARISON.csv) hold both implementation and executor fixed. Regenerate this report with `node script/build_gas_workup.mjs docs/gas-workup/raw docs`.

Earlier headline numbers can differ slightly because that comparison used an older test dispatcher/helper harness. All columns below are newly measured using one fixed current harness; do not mix columns between reports.

## Profile Summary

Medians are unweighted across benchmark scenarios, not production-volume-weighted costs. Counts classify changes of at least 1,000 gas; smaller changes remain visible in every individual row. There is no defensible single production savings percentage without an operation-frequency distribution.

| Profile | Cases | Median vs Master | Median vs Before Fix | Saves >=1k vs Before | Changes <1k | Adds >=1k vs Before |
|---|---:|---:|---:|---:|---:|---:|
| Integrator fees / routing | 5 | -2.21% | -1.89% | 4 | 1 | 0 |
| Insertion diagnostics | 12 | +13.50% | +6.48% | 4 | 0 | 8 |
| ERC20 / 100 bps protocol fee | 42 | -11.32% | -0.08% | 20 | 7 | 15 |
| ERC20 / no hooks | 42 | -11.38% | -0.08% | 20 | 7 | 15 |
| Native ETH / prior-fill histories | 6 | +53.62% | +54.72% | 0 | 0 | 6 |
| Mixed-price sweep stress | 8 | -97.23% | -97.31% | 8 | 0 | 0 |
| ERC20 / top-order hooks | 42 | -8.35% | +0.14% | 14 | 8 | 20 |
| All independent completed operations | 157 | -3.59% | -0.04% | 70 | 23 | 64 |

## Assessment

**This is a work-bound/correctness fix with substantial steady-state gas regressions, not a blanket gas optimization.** All 18 large-book operations regress against the pre-fix branch: +41.47% to +83.30%. Those ordinary fills and rests matter more to an active book than the sweep headline alone suggests.

The report does not justify a production-wide savings claim or treating the new version as universally cheaper. The 64-level expansion bound and width-independent sweeps are real improvements; normal-book cost deserves another optimization pass before presenting this as a general gas win.

### Next Optimization Targets

1. **Recover early price-prefix divergence in insertion.** [The witness insertion](../src/DeepstateV1.sol#L714) currently descends to a leaf before discovering a new split belongs above an existing branch. Price-only divergence can potentially be detected from the exact cached representative tick, without a descendant-key walk. The different/worse-tick insertion and populated-book rest regressions make this the clearest candidate to test. No savings are assumed here.
2. **Update mixed quote totals by known deltas.** [Ancestor rebuilding](../src/DeepstateV1.sol#L772) currently recomputes child quote sums after every mutation. Matching already computes the removed quote. Carrying that delta could avoid sibling pricing and some repeated reads, while preserving exact cached quotes. Persistent summary writes would still have a cost.
3. **Reduce redundant top-order lookups for partial fills.** The matched leaf is already encountered during traversal; carrying its identity could avoid some extra hook lookup work. Keep callback behavior and rounding unchanged.

These are source-based optimization hypotheses, not implemented changes or measured savings. Reintroducing the old mixed-descendant scan would undo the bound fix.

## Largest Regressions From The Previous Branch

| Profile / Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| ERC20 / 100 bps protocol fee / `testGas_CancelFullDepthBidCombRightmost()` | 423,280 | 399,495 | 887,530 | +464,250 (+109.68%) | +488,035 (+122.16%) |
| ERC20 / no hooks / `testGas_CancelFullDepthBidCombRightmost()` | 423,280 | 399,495 | 887,530 | +464,250 (+109.68%) | +488,035 (+122.16%) |
| ERC20 / top-order hooks / `testGas_CancelFullDepthBidCombRightmost()` | 446,599 | 423,210 | 911,245 | +464,646 (+104.04%) | +488,035 (+115.32%) |
| Native ETH / prior-fill histories / `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 356,559 | 337,437 | 770,624 | +414,065 (+116.13%) | +433,187 (+128.38%) |
| Native ETH / prior-fill histories / `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 394,285 | 369,342 | 772,698 | +378,413 (+95.97%) | +403,356 (+109.21%) |
| ERC20 / 100 bps protocol fee / `testGas_CancelMaxValidDepthAskCombRightmost()` | 424,852 | 399,129 | 796,462 | +371,610 (+87.47%) | +397,333 (+99.55%) |
| ERC20 / no hooks / `testGas_CancelMaxValidDepthAskCombRightmost()` | 424,852 | 399,129 | 796,462 | +371,610 (+87.47%) | +397,333 (+99.55%) |
| ERC20 / top-order hooks / `testGas_CancelMaxValidDepthAskCombRightmost()` | 447,312 | 421,985 | 819,318 | +372,006 (+83.16%) | +397,333 (+94.16%) |
| ERC20 / top-order hooks / `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,279,514 | 670,824 | 903,202 | -2,376,312 (-72.46%) | +232,378 (+34.64%) |
| ERC20 / 100 bps protocol fee / `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,281,273 | 672,191 | 902,497 | -2,378,776 (-72.50%) | +230,306 (+34.26%) |
| ERC20 / no hooks / `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,255,583 | 646,501 | 876,807 | -2,378,776 (-73.07%) | +230,306 (+35.62%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookPartialFillsAsk()` | 144,719 | 145,851 | 264,837 | +120,118 (+83.00%) | +118,986 (+81.58%) |

## Largest Savings From The Previous Branch

| Profile / Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| Mixed-price sweep stress / `testGas_MixedSweep4096()` | 35,573,912 | 36,749,279 | 100,207 | -35,473,705 (-99.72%) | -36,649,072 (-99.73%) |
| Mixed-price sweep stress / `testGas_MixedSweep4096RestBurningHooksAndFees()` | 36,064,561 | 37,240,059 | 617,341 | -35,447,220 (-98.29%) | -36,622,718 (-98.34%) |
| Mixed-price sweep stress / `testGas_MixedSweep1024AndRest()` | 9,015,058 | 9,308,822 | 151,931 | -8,863,127 (-98.31%) | -9,156,891 (-98.37%) |
| Mixed-price sweep stress / `testGas_MixedSweep1024()` | 8,962,743 | 9,256,446 | 99,647 | -8,863,096 (-98.89%) | -9,156,799 (-98.92%) |
| Mixed-price sweep stress / `testGas_MixedSweep1024BurningHookAndFees()` | 9,197,908 | 9,491,674 | 353,017 | -8,844,891 (-96.16%) | -9,138,657 (-96.28%) |
| Mixed-price sweep stress / `testGas_MixedSweep1024RestBurningHooksAndFees()` | 9,453,240 | 9,747,056 | 610,611 | -8,842,629 (-93.54%) | -9,136,445 (-93.74%) |
| Mixed-price sweep stress / `testGas_MixedSweep256()` | 2,313,793 | 2,387,080 | 99,331 | -2,214,462 (-95.71%) | -2,287,749 (-95.84%) |
| Mixed-price sweep stress / `testGas_MixedSweep64()` | 648,416 | 666,599 | 98,631 | -549,785 (-84.79%) | -567,968 (-85.20%) |
| ERC20 / 100 bps protocol fee / `testGas_DirtyBidHalfNonceComb()` | 1,338,098 | 666,921 | 261,100 | -1,076,998 (-80.49%) | -405,821 (-60.85%) |
| ERC20 / no hooks / `testGas_DirtyBidHalfNonceComb()` | 1,312,408 | 641,231 | 235,410 | -1,076,998 (-82.06%) | -405,821 (-63.29%) |
| ERC20 / 100 bps protocol fee / `testGas_DirtyAskHalfNonceComb()` | 1,332,984 | 667,133 | 261,424 | -1,071,560 (-80.39%) | -405,709 (-60.81%) |
| ERC20 / no hooks / `testGas_DirtyAskHalfNonceComb()` | 1,307,308 | 641,457 | 235,748 | -1,071,560 (-81.97%) | -405,709 (-63.25%) |

## Large Random Books

All 18 nonduplicate large-book rows are included here. These are target operations against 10,000 resting orders.

| Profile / Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookAskMatchesOneBid()` | 119,898 | 120,595 | 188,468 | +68,570 (+57.19%) | +67,873 (+56.28%) |
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookBidMatchesOneAsk()` | 135,132 | 136,255 | 239,371 | +104,239 (+77.14%) | +103,116 (+75.68%) |
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookPartialFillsAsk()` | 136,336 | 137,465 | 251,478 | +115,142 (+84.45%) | +114,013 (+82.94%) |
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookPartialFillsBid()` | 121,088 | 121,791 | 200,989 | +79,901 (+65.99%) | +79,198 (+65.03%) |
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookRestsAsk()` | 161,633 | 161,863 | 256,955 | +95,322 (+58.97%) | +95,092 (+58.75%) |
| ERC20 / 100 bps protocol fee / `testGas_LargeRandomBookRestsBid()` | 171,017 | 171,368 | 253,777 | +82,760 (+48.39%) | +82,409 (+48.09%) |
| ERC20 / no hooks / `testGas_LargeRandomBookAskMatchesOneBid()` | 119,294 | 119,991 | 187,864 | +68,570 (+57.48%) | +67,873 (+56.57%) |
| ERC20 / no hooks / `testGas_LargeRandomBookBidMatchesOneAsk()` | 134,538 | 135,661 | 238,777 | +104,239 (+77.48%) | +103,116 (+76.01%) |
| ERC20 / no hooks / `testGas_LargeRandomBookPartialFillsAsk()` | 135,742 | 136,871 | 250,884 | +115,142 (+84.82%) | +114,013 (+83.30%) |
| ERC20 / no hooks / `testGas_LargeRandomBookPartialFillsBid()` | 120,484 | 121,187 | 200,385 | +79,901 (+66.32%) | +79,198 (+65.35%) |
| ERC20 / no hooks / `testGas_LargeRandomBookRestsAsk()` | 161,407 | 161,637 | 256,729 | +95,322 (+59.06%) | +95,092 (+58.83%) |
| ERC20 / no hooks / `testGas_LargeRandomBookRestsBid()` | 170,798 | 171,149 | 253,558 | +82,760 (+48.45%) | +82,409 (+48.15%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookAskMatchesOneBid()` | 136,722 | 137,439 | 206,746 | +70,024 (+51.22%) | +69,307 (+50.43%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookBidMatchesOneAsk()` | 152,568 | 153,717 | 258,948 | +106,380 (+69.73%) | +105,231 (+68.46%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookPartialFillsAsk()` | 144,719 | 145,851 | 264,837 | +120,118 (+83.00%) | +118,986 (+81.58%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookPartialFillsBid()` | 131,071 | 131,777 | 215,267 | +84,196 (+64.24%) | +83,490 (+63.36%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookRestsAsk()` | 191,340 | 191,627 | 293,234 | +101,894 (+53.25%) | +101,607 (+53.02%) |
| ERC20 / top-order hooks / `testGas_LargeRandomBookRestsBid()` | 196,333 | 196,723 | 278,301 | +81,968 (+41.75%) | +81,578 (+41.47%) |

## Cost Interpretation

- Cached mixed quotes remove descendant scans from full sweeps. This is a structural width-independence improvement, not a reason to expect every operation to get cheaper.
- Maintaining exact ancestor quantities and quotes adds writes to partial fills and cancellations. Small best-order fills in populated books can therefore regress even when a whole-book sweep becomes dramatically cheaper.
- Witness insertion removes repeated key-representative walks, but creating/updating mixed quote-cache words has a cost. Same-price comb insertion and divergent-price insertion must be assessed separately.
- The hook profile uses a no-op notification hook. Stress rows additionally exhaust the 200,000-gas callback allowance. Neither is a measurement of a particular live rewarder contract.
- Protocol-fee tests configure 100 bps, but many inherited fixtures trade only 1-10 raw token units, so their fee rounds to zero. Those rows do not all pay for a fee-recipient transfer. Dedicated 10,000-unit integrator/protocol cases and larger sweep cases force nonzero fees. Cancellation remains fee-free.
- Unmetered setup means these rows cannot establish total lifetime cost or a network-wide weighted average. They do not include a live-chain USD fee estimate, calldata compression fees, or RPC costs.

The highest measured independent solc operation here is **911,245 gas**, `RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost()`. This is not a proof of the maximum gas of every possible route, hook, token, or state.

## Solar Compiler Delta

Same implementation and same Forge executor; negative means Solar uses less gas. The following includes only the 157 independent completed-operation scenarios.

| Implementation | Median compiler delta | Lowest delta | Highest delta | Cheaper under Solar | More expensive under Solar | Unchanged |
|---|---:|---:|---:|---:|---:|---:|
| master | -2.36% | -14.77% | -0.77% | 157 | 0 | 0 |
| before | -2.59% | -12.45% | -0.97% | 157 | 0 | 0 |
| after | -2.34% | -7.36% | -0.45% | 157 | 0 | 0 |

Solar remains experimental; its integer-gas savings are separate from the algorithm change and do not by themselves establish production compiler safety.

## Capped-Gas Functional Check

The 1,024-price sweep is also submitted with a one-million-gas call allowance. Master and the pre-fix branch exhaust that allowance and roll back; the fixed branch succeeds. Legacy numbers are therefore censored failure-path measurements, **not** completed-operation costs. No savings percentage is calculated for this row.

| Compiler | Master (failure) | Before Fix (failure) | After Fix (success) |
|---|---:|---:|---:|
| solc | 1,009,760 | 1,009,760 | 98,919 |
| solar | 1,009,760 | 1,009,760 | 97,550 |

## Access Lists

These are the existing predictive access-list studies, run in a separate fixed harness with explicit cold/warm slot preparation. All touched engine/token keys are warmed; the harness charges 2,400 gas per address and 1,900 per storage key. This is a comparison of that complete predicted list, not an optimized minimal list. **Positive net saving means the list helps; negative means it costs more than it saves.**

### solc

| Test | Master Net Saving | Before Net Saving | After Net Saving | After Cold Execution | After Warm + Intrinsic | After Keys |
|---|---:|---:|---:|---:|---:|---:|
| `testBenchmark_FillAskConsumesDirtySamePriceBidSubtree()` | -5,387 | -5,388 | -6,388 | 31,177 | 37,565 | 8 |
| `testBenchmark_FillAskConsumesFullDepthBidComb()` | -62,676 | -52,777 | -8,280 | 53,403 | 61,683 | 9 |
| `testBenchmark_FillBidConsumesAskAndRestsRemainder()` | -17,590 | -17,589 | -15,689 | 109,904 | 125,593 | 10 |
| `testBenchmark_FillBidConsumesDirtySamePriceAskSubtree()` | -5,387 | -5,388 | -6,388 | 31,334 | 37,722 | 8 |
| `testBenchmark_FillBidConsumesMaxValidDepthAskComb()` | -62,676 | -52,777 | -8,280 | 53,571 | 61,851 | 9 |
| `testBenchmark_FillBidConsumesSamePriceAskSubtree()` | -11,788 | -11,789 | -11,889 | 59,333 | 71,222 | 8 |

### solar

| Test | Master Net Saving | Before Net Saving | After Net Saving | After Cold Execution | After Warm + Intrinsic | After Keys |
|---|---:|---:|---:|---:|---:|---:|
| `testBenchmark_FillAskConsumesDirtySamePriceBidSubtree()` | -5,387 | -5,388 | -6,388 | 29,629 | 36,017 | 8 |
| `testBenchmark_FillAskConsumesFullDepthBidComb()` | -62,676 | -52,777 | -8,280 | 52,025 | 60,305 | 9 |
| `testBenchmark_FillBidConsumesAskAndRestsRemainder()` | -17,589 | -17,589 | -15,689 | 107,547 | 123,236 | 10 |
| `testBenchmark_FillBidConsumesDirtySamePriceAskSubtree()` | -5,387 | -5,388 | -6,388 | 29,767 | 36,155 | 8 |
| `testBenchmark_FillBidConsumesMaxValidDepthAskComb()` | -62,676 | -52,777 | -8,280 | 52,167 | 60,447 | 9 |
| `testBenchmark_FillBidConsumesSamePriceAskSubtree()` | -11,788 | -11,789 | -11,889 | 57,766 | 69,655 | 8 |

All 36 cold/warm/key/intrinsic measurements are in [GAS_ACCESS_LIST_WORKUP.csv](GAS_ACCESS_LIST_WORKUP.csv). Do not compare the internal gas-left measurements directly with snapshot totals above.

## Every Test Row

The following tables retain every one of the 200 rows under both compilers. All repeated rows are labeled and excluded from the summary. Raw function identity, profile, category, outcomes, and all deltas are in the CSV.

### solc / Full Matrix

#### Integrator fees / routing

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_IntegratorAndProtocolFeeFill()` | 129,349 | 129,184 | 127,054 | -2,295 (-1.77%) | -2,130 (-1.65%) |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 103,760 | 103,589 | 101,418 | -2,342 (-2.26%) | -2,171 (-2.10%) |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 103,869 | 103,704 | 101,574 | -2,295 (-2.21%) | -2,130 (-2.05%) |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,812 | 151,935 | 151,826 | +14 (+0.01%) | -109 (-0.07%) |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 122,488 | 120,158 | 117,892 | -4,596 (-3.75%) | -2,266 (-1.89%) |

#### Insertion diagnostics

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testOpportunity_RestAsk16Orders()` | 145,909 | 153,172 | 160,825 | +14,916 (+10.22%) | +7,653 (+5.00%) |
| `testOpportunity_RestAsk64Orders()` | 145,260 | 157,305 | 170,012 | +24,752 (+17.04%) | +12,707 (+8.08%) |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 140,812 | 203,011 | 291,723 | +150,911 (+107.17%) | +88,712 (+43.70%) |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 1,625,262 | 581,793 | 434,616 | -1,190,646 (-73.26%) | -147,177 (-25.30%) |
| `testOpportunity_RestAskLeftNonceComb()` | 1,575,943 | 578,999 | 434,309 | -1,141,634 (-72.44%) | -144,690 (-24.99%) |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 141,762 | 203,949 | 292,666 | +150,904 (+106.45%) | +88,717 (+43.50%) |
| `testOpportunity_RestBid16Orders()` | 147,843 | 155,123 | 162,793 | +14,950 (+10.11%) | +7,670 (+4.94%) |
| `testOpportunity_RestBid64Orders()` | 147,678 | 159,740 | 172,464 | +24,786 (+16.78%) | +12,724 (+7.97%) |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 142,579 | 204,780 | 293,539 | +150,960 (+105.88%) | +88,759 (+43.34%) |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 1,627,069 | 584,171 | 437,141 | -1,189,928 (-73.13%) | -147,030 (-25.17%) |
| `testOpportunity_RestBidLeftNonceComb()` | 1,578,007 | 581,663 | 437,120 | -1,140,887 (-72.30%) | -144,543 (-24.85%) |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 143,066 | 205,285 | 294,039 | +150,973 (+105.53%) | +88,754 (+43.23%) |

#### ERC20 / 100 bps protocol fee

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,014 | 40,046 | 40,044 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelFilledBidClaim()` | 37,050 | 37,058 | 37,072 | +22 (+0.06%) | +14 (+0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 423,280 | 399,495 | 887,530 | +464,250 (+109.68%) | +488,035 (+122.16%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 424,852 | 399,129 | 796,462 | +371,610 (+87.47%) | +397,333 (+99.55%) |
| `testGas_CancelPartialBid()` | 49,108 | 49,152 | 49,134 | +26 (+0.05%) | -18 (-0.04%) |
| `testGas_CancelUnfilledAsk()` | 40,253 | 40,285 | 40,283 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelUnfilledBid()` | 40,028 | 40,070 | 40,054 | +26 (+0.06%) | -16 (-0.04%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,592,472 | 400,159 | 368,305 | -1,224,167 (-76.87%) | -31,854 (-7.96%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,332,984 | 667,133 | 261,424 | -1,071,560 (-80.39%) | -405,709 (-60.81%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 458,702 | 400,096 | 118,992 | -339,710 (-74.06%) | -281,104 (-70.26%) |
| `testGas_DirtyAskSmallFill16Orders()` | 151,802 | 115,327 | 122,834 | -28,968 (-19.08%) | +7,507 (+6.51%) |
| `testGas_DirtyAskSmallFill64Orders()` | 195,970 | 127,415 | 139,750 | -56,220 (-28.69%) | +12,335 (+9.68%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,589,262 | 294,851 | 369,950 | -1,219,312 (-76.72%) | +75,099 (+25.47%) |
| `testGas_DirtyAskWholeNonceComb()` | 362,157 | 341,650 | 92,516 | -269,641 (-74.45%) | -249,134 (-72.92%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,600,621 | 401,407 | 369,809 | -1,230,812 (-76.90%) | -31,598 (-7.87%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,338,098 | 666,921 | 261,100 | -1,076,998 (-80.49%) | -405,821 (-60.85%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 459,734 | 400,705 | 119,116 | -340,618 (-74.09%) | -281,589 (-70.27%) |
| `testGas_DirtyBidSmallFill16Orders()` | 151,436 | 114,828 | 122,328 | -29,108 (-19.22%) | +7,500 (+6.53%) |
| `testGas_DirtyBidSmallFill64Orders()` | 196,940 | 128,116 | 140,464 | -56,476 (-28.68%) | +12,348 (+9.64%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,596,346 | 295,034 | 370,406 | -1,225,940 (-76.80%) | +75,372 (+25.55%) |
| `testGas_DirtyBidWholeNonceComb()` | 361,692 | 341,179 | 91,556 | -270,136 (-74.69%) | -249,623 (-73.16%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 88,084 | 86,096 | 58,300 | -29,784 (-33.81%) | -27,796 (-32.28%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 353,189 | 359,899 | 102,654 | -250,535 (-70.94%) | -257,245 (-71.48%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 78,589 | 78,425 | 76,254 | -2,335 (-2.97%) | -2,171 (-2.77%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 160,599 | 115,699 | 111,292 | -49,307 (-30.70%) | -4,407 (-3.81%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 98,240 | 98,076 | 95,905 | -2,335 (-2.38%) | -2,171 (-2.21%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 130,955 | 130,826 | 128,604 | -2,351 (-1.80%) | -2,222 (-1.70%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 88,241 | 86,259 | 58,572 | -29,669 (-33.62%) | -27,687 (-32.10%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 324,367 | 331,083 | 78,063 | -246,304 (-75.93%) | -253,020 (-76.42%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 78,101 | 78,065 | 75,315 | -2,786 (-3.57%) | -2,750 (-3.52%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 78,133 | 77,975 | 75,845 | -2,288 (-2.93%) | -2,130 (-2.73%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 160,381 | 115,494 | 111,146 | -49,235 (-30.70%) | -4,348 (-3.76%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 98,091 | 97,933 | 95,803 | -2,288 (-2.33%) | -2,130 (-2.17%) |
| `testGas_FillRestAskEmptyBook()` | 151,132 | 151,285 | 151,137 | +5 (+0.00%) | -148 (-0.10%) |
| `testGas_FillRestBidEmptyBook()` | 152,999 | 153,122 | 153,013 | +14 (+0.01%) | -109 (-0.07%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 119,898 | 120,595 | 188,468 | +68,570 (+57.19%) | +67,873 (+56.28%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 135,132 | 136,255 | 239,371 | +104,239 (+77.14%) | +103,116 (+75.68%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 136,336 | 137,465 | 251,478 | +115,142 (+84.45%) | +114,013 (+82.94%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 121,088 | 121,791 | 200,989 | +79,901 (+65.99%) | +79,198 (+65.03%) |
| `testGas_LargeRandomBookRestsAsk()` | 161,633 | 161,863 | 256,955 | +95,322 (+58.97%) | +95,092 (+58.75%) |
| `testGas_LargeRandomBookRestsBid()` | 171,017 | 171,368 | 253,777 | +82,760 (+48.39%) | +82,409 (+48.09%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,281,273 | 672,191 | 902,497 | -2,378,776 (-72.50%) | +230,306 (+34.26%) |

#### ERC20 / no hooks

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,014 | 40,046 | 40,044 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelFilledBidClaim()` | 37,050 | 37,058 | 37,072 | +22 (+0.06%) | +14 (+0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 423,280 | 399,495 | 887,530 | +464,250 (+109.68%) | +488,035 (+122.16%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 424,852 | 399,129 | 796,462 | +371,610 (+87.47%) | +397,333 (+99.55%) |
| `testGas_CancelPartialBid()` | 49,108 | 49,152 | 49,134 | +26 (+0.05%) | -18 (-0.04%) |
| `testGas_CancelUnfilledAsk()` | 40,253 | 40,285 | 40,283 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelUnfilledBid()` | 40,028 | 40,070 | 40,054 | +26 (+0.06%) | -16 (-0.04%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,591,878 | 399,565 | 367,711 | -1,224,167 (-76.90%) | -31,854 (-7.97%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,307,308 | 641,457 | 235,748 | -1,071,560 (-81.97%) | -405,709 (-63.25%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 433,026 | 374,420 | 93,316 | -339,710 (-78.45%) | -281,104 (-75.08%) |
| `testGas_DirtyAskSmallFill16Orders()` | 151,208 | 114,733 | 122,240 | -28,968 (-19.16%) | +7,507 (+6.54%) |
| `testGas_DirtyAskSmallFill64Orders()` | 195,376 | 126,821 | 139,156 | -56,220 (-28.78%) | +12,335 (+9.73%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,588,668 | 294,257 | 369,356 | -1,219,312 (-76.75%) | +75,099 (+25.52%) |
| `testGas_DirtyAskWholeNonceComb()` | 336,481 | 315,974 | 66,840 | -269,641 (-80.14%) | -249,134 (-78.85%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,600,017 | 400,803 | 369,205 | -1,230,812 (-76.92%) | -31,598 (-7.88%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,312,408 | 641,231 | 235,410 | -1,076,998 (-82.06%) | -405,821 (-63.29%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 434,044 | 375,015 | 93,426 | -340,618 (-78.48%) | -281,589 (-75.09%) |
| `testGas_DirtyBidSmallFill16Orders()` | 150,832 | 114,224 | 121,724 | -29,108 (-19.30%) | +7,500 (+6.57%) |
| `testGas_DirtyBidSmallFill64Orders()` | 196,336 | 127,512 | 139,860 | -56,476 (-28.76%) | +12,348 (+9.68%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,595,742 | 294,430 | 369,802 | -1,225,940 (-76.83%) | +75,372 (+25.60%) |
| `testGas_DirtyBidWholeNonceComb()` | 336,002 | 315,489 | 65,866 | -270,136 (-80.40%) | -249,623 (-79.12%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 87,480 | 85,492 | 57,696 | -29,784 (-34.05%) | -27,796 (-32.51%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 327,499 | 334,209 | 76,964 | -250,535 (-76.50%) | -257,245 (-76.97%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 77,985 | 77,821 | 75,650 | -2,335 (-2.99%) | -2,171 (-2.79%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 159,995 | 115,095 | 110,688 | -49,307 (-30.82%) | -4,407 (-3.83%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 97,636 | 97,472 | 95,301 | -2,335 (-2.39%) | -2,171 (-2.23%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 130,361 | 130,232 | 128,010 | -2,351 (-1.80%) | -2,222 (-1.71%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 87,647 | 85,665 | 57,978 | -29,669 (-33.85%) | -27,687 (-32.32%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 323,773 | 330,489 | 77,469 | -246,304 (-76.07%) | -253,020 (-76.56%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 77,507 | 77,471 | 74,721 | -2,786 (-3.59%) | -2,750 (-3.55%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 77,539 | 77,381 | 75,251 | -2,288 (-2.95%) | -2,130 (-2.75%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 159,787 | 114,900 | 110,552 | -49,235 (-30.81%) | -4,348 (-3.78%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 97,497 | 97,339 | 95,209 | -2,288 (-2.35%) | -2,130 (-2.19%) |
| `testGas_FillRestAskEmptyBook()` | 150,906 | 151,059 | 150,911 | +5 (+0.00%) | -148 (-0.10%) |
| `testGas_FillRestBidEmptyBook()` | 152,780 | 152,903 | 152,794 | +14 (+0.01%) | -109 (-0.07%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 119,294 | 119,991 | 187,864 | +68,570 (+57.48%) | +67,873 (+56.57%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 134,538 | 135,661 | 238,777 | +104,239 (+77.48%) | +103,116 (+76.01%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 135,742 | 136,871 | 250,884 | +115,142 (+84.82%) | +114,013 (+83.30%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 120,484 | 121,187 | 200,385 | +79,901 (+66.32%) | +79,198 (+65.35%) |
| `testGas_LargeRandomBookRestsAsk()` | 161,407 | 161,637 | 256,729 | +95,322 (+59.06%) | +95,092 (+58.83%) |
| `testGas_LargeRandomBookRestsBid()` | 170,798 | 171,149 | 253,558 | +82,760 (+48.45%) | +82,409 (+48.15%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,255,583 | 646,501 | 876,807 | -2,378,776 (-73.07%) | +230,306 (+35.62%) |

#### Native ETH / prior-fill histories

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 88,512 | 86,868 | 133,612 | +45,100 (+50.95%) | +46,744 (+53.81%) |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 98,481 | 98,897 | 153,910 | +55,429 (+56.28%) | +55,013 (+55.63%) |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 526,171 | 177,928 | 236,641 | -289,530 (-55.03%) | +58,713 (+33.00%) |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 356,559 | 337,437 | 770,624 | +414,065 (+116.13%) | +433,187 (+128.38%) |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 394,285 | 369,342 | 772,698 | +378,413 (+95.97%) | +403,356 (+109.21%) |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 3,929,483 | 806,897 | 874,932 | -3,054,551 (-77.73%) | +68,035 (+8.43%) |

#### Mixed-price sweep stress

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_MixedSweep1024()` | 8,962,743 | 9,256,446 | 99,647 | -8,863,096 (-98.89%) | -9,156,799 (-98.92%) |
| `testGas_MixedSweep1024AndRest()` | 9,015,058 | 9,308,822 | 151,931 | -8,863,127 (-98.31%) | -9,156,891 (-98.37%) |
| `testGas_MixedSweep1024BurningHookAndFees()` | 9,197,908 | 9,491,674 | 353,017 | -8,844,891 (-96.16%) | -9,138,657 (-96.28%) |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 1,009,760 | 1,009,760 | 98,919 | N/A (outcome changed) | N/A (outcome changed) |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 9,453,240 | 9,747,056 | 610,611 | -8,842,629 (-93.54%) | -9,136,445 (-93.74%) |
| `testGas_MixedSweep256()` | 2,313,793 | 2,387,080 | 99,331 | -2,214,462 (-95.71%) | -2,287,749 (-95.84%) |
| `testGas_MixedSweep4096()` | 35,573,912 | 36,749,279 | 100,207 | -35,473,705 (-99.72%) | -36,649,072 (-99.73%) |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 36,064,561 | 37,240,059 | 617,341 | -35,447,220 (-98.29%) | -36,622,718 (-98.34%) |
| `testGas_MixedSweep64()` | 648,416 | 666,599 | 98,631 | -549,785 (-84.79%) | -567,968 (-85.20%) |

#### ERC20 / top-order hooks

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,017 | 44,051 | 44,051 | +34 (+0.08%) | 0 (0.00%) |
| `testGas_CancelFilledBidClaim()` | 37,761 | 37,775 | 37,789 | +28 (+0.07%) | +14 (+0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 446,599 | 423,210 | 911,245 | +464,646 (+104.04%) | +488,035 (+115.32%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 447,312 | 421,985 | 819,318 | +372,006 (+83.16%) | +397,333 (+94.16%) |
| `testGas_CancelPartialBid()` | 53,862 | 53,906 | 53,890 | +28 (+0.05%) | -16 (-0.03%) |
| `testGas_CancelUnfilledAsk()` | 44,256 | 44,290 | 44,290 | +34 (+0.08%) | 0 (0.00%) |
| `testGas_CancelUnfilledBid()` | 44,780 | 44,826 | 44,810 | +30 (+0.07%) | -16 (-0.04%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,607,833 | 413,525 | 393,029 | -1,214,804 (-75.56%) | -20,496 (-4.96%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,320,068 | 652,222 | 287,796 | -1,032,272 (-78.20%) | -364,426 (-55.87%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 442,442 | 381,841 | 173,627 | -268,815 (-60.76%) | -208,214 (-54.53%) |
| `testGas_DirtyAskSmallFill16Orders()` | 158,931 | 122,459 | 133,577 | -25,354 (-15.95%) | +11,118 (+9.08%) |
| `testGas_DirtyAskSmallFill64Orders()` | 203,517 | 134,965 | 151,365 | -52,152 (-25.63%) | +16,400 (+12.15%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,602,243 | 307,835 | 392,901 | -1,209,342 (-75.48%) | +85,066 (+27.63%) |
| `testGas_DirtyAskWholeNonceComb()` | 343,300 | 322,796 | 146,964 | -196,336 (-57.19%) | -175,832 (-54.47%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,617,115 | 415,906 | 395,666 | -1,221,449 (-75.53%) | -20,240 (-4.87%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,326,311 | 653,139 | 288,601 | -1,037,710 (-78.24%) | -364,538 (-55.81%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 444,603 | 383,579 | 174,880 | -269,723 (-60.67%) | -208,699 (-54.41%) |
| `testGas_DirtyBidSmallFill16Orders()` | 159,698 | 123,093 | 134,204 | -25,494 (-15.96%) | +11,111 (+9.03%) |
| `testGas_DirtyBidSmallFill64Orders()` | 205,620 | 136,799 | 153,212 | -52,408 (-25.49%) | +16,413 (+12.00%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,610,460 | 309,151 | 394,490 | -1,215,970 (-75.50%) | +85,339 (+27.60%) |
| `testGas_DirtyBidWholeNonceComb()` | 343,964 | 323,454 | 147,133 | -196,831 (-57.22%) | -176,321 (-54.51%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 95,442 | 93,457 | 74,641 | -20,801 (-21.79%) | -18,816 (-20.13%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 414,926 | 422,029 | 228,926 | -186,000 (-44.83%) | -193,103 (-45.76%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,113 | 85,952 | 86,047 | -66 (-0.08%) | +95 (+0.11%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 174,172 | 128,615 | 126,069 | -48,103 (-27.62%) | -2,546 (-1.98%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 105,772 | 105,611 | 107,894 | +2,122 (+2.01%) | +2,283 (+2.16%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 139,287 | 139,150 | 141,498 | +2,211 (+1.59%) | +2,348 (+1.69%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 94,466 | 92,487 | 73,780 | -20,686 (-21.90%) | -18,707 (-20.23%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 410,341 | 417,450 | 228,572 | -181,769 (-44.30%) | -188,878 (-45.25%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 93,439 | 93,436 | 92,741 | -698 (-0.75%) | -695 (-0.74%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,418 | 84,263 | 84,399 | -19 (-0.02%) | +136 (+0.16%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 172,821 | 127,277 | 124,790 | -48,031 (-27.79%) | -2,487 (-1.95%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 104,384 | 104,229 | 106,553 | +2,169 (+2.08%) | +2,324 (+2.23%) |
| `testGas_FillRestAskEmptyBook()` | 140,547 | 140,689 | 142,840 | +2,293 (+1.63%) | +2,151 (+1.53%) |
| `testGas_FillRestBidEmptyBook()` | 142,418 | 142,530 | 144,720 | +2,302 (+1.62%) | +2,190 (+1.54%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 136,722 | 137,439 | 206,746 | +70,024 (+51.22%) | +69,307 (+50.43%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 152,568 | 153,717 | 258,948 | +106,380 (+69.73%) | +105,231 (+68.46%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 144,719 | 145,851 | 264,837 | +120,118 (+83.00%) | +118,986 (+81.58%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 131,071 | 131,777 | 215,267 | +84,196 (+64.24%) | +83,490 (+63.36%) |
| `testGas_LargeRandomBookRestsAsk()` | 191,340 | 191,627 | 293,234 | +101,894 (+53.25%) | +101,607 (+53.02%) |
| `testGas_LargeRandomBookRestsBid()` | 196,333 | 196,723 | 278,301 | +81,968 (+41.75%) | +81,578 (+41.47%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,279,514 | 670,824 | 903,202 | -2,376,312 (-72.46%) | +232,378 (+34.64%) |

<details>
<summary>solc: 42 inherited repeat rows, excluded from summary</summary>

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,080 | 40,112 | 40,110 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelFilledBidClaim()` | 37,116 | 37,124 | 37,138 | +22 (+0.06%) | +14 (+0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 423,302 | 399,517 | 887,552 | +464,250 (+109.67%) | +488,035 (+122.16%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 424,852 | 399,129 | 796,462 | +371,610 (+87.47%) | +397,333 (+99.55%) |
| `testGas_CancelPartialBid()` | 49,174 | 49,218 | 49,200 | +26 (+0.05%) | -18 (-0.04%) |
| `testGas_CancelUnfilledAsk()` | 40,363 | 40,395 | 40,393 | +30 (+0.07%) | -2 (-0.00%) |
| `testGas_CancelUnfilledBid()` | 40,094 | 40,136 | 40,120 | +26 (+0.06%) | -16 (-0.04%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,591,935 | 399,622 | 367,768 | -1,224,167 (-76.90%) | -31,854 (-7.97%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,307,431 | 641,580 | 235,871 | -1,071,560 (-81.96%) | -405,709 (-63.24%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 433,105 | 374,499 | 93,395 | -339,710 (-78.44%) | -281,104 (-75.06%) |
| `testGas_DirtyAskSmallFill16Orders()` | 151,441 | 114,966 | 122,473 | -28,968 (-19.13%) | +7,507 (+6.53%) |
| `testGas_DirtyAskSmallFill64Orders()` | 195,455 | 126,900 | 139,235 | -56,220 (-28.76%) | +12,335 (+9.72%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,588,725 | 294,314 | 369,413 | -1,219,312 (-76.75%) | +75,099 (+25.52%) |
| `testGas_DirtyAskWholeNonceComb()` | 336,604 | 316,097 | 66,963 | -269,641 (-80.11%) | -249,134 (-78.82%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,600,272 | 401,058 | 369,460 | -1,230,812 (-76.91%) | -31,598 (-7.88%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,312,487 | 641,310 | 235,489 | -1,076,998 (-82.06%) | -405,821 (-63.28%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 434,145 | 375,116 | 93,527 | -340,618 (-78.46%) | -281,589 (-75.07%) |
| `testGas_DirtyBidSmallFill16Orders()` | 150,955 | 114,347 | 121,847 | -29,108 (-19.28%) | +7,500 (+6.56%) |
| `testGas_DirtyBidSmallFill64Orders()` | 196,503 | 127,679 | 140,027 | -56,476 (-28.74%) | +12,348 (+9.67%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,595,799 | 294,487 | 369,859 | -1,225,940 (-76.82%) | +75,372 (+25.59%) |
| `testGas_DirtyBidWholeNonceComb()` | 336,059 | 315,546 | 65,923 | -270,136 (-80.38%) | -249,623 (-79.11%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 87,574 | 85,586 | 57,790 | -29,784 (-34.01%) | -27,796 (-32.48%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 327,593 | 334,303 | 77,058 | -250,535 (-76.48%) | -257,245 (-76.95%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 78,167 | 78,003 | 75,832 | -2,335 (-2.99%) | -2,171 (-2.78%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 160,089 | 115,189 | 110,782 | -49,307 (-30.80%) | -4,407 (-3.83%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 97,774 | 97,610 | 95,439 | -2,335 (-2.39%) | -2,171 (-2.22%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 130,430 | 130,301 | 128,079 | -2,351 (-1.80%) | -2,222 (-1.71%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 87,760 | 85,778 | 58,091 | -29,669 (-33.81%) | -27,687 (-32.28%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 323,886 | 330,602 | 77,582 | -246,304 (-76.05%) | -253,020 (-76.53%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 77,576 | 77,540 | 74,790 | -2,786 (-3.59%) | -2,750 (-3.55%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 77,652 | 77,494 | 75,364 | -2,288 (-2.95%) | -2,130 (-2.75%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 159,856 | 114,969 | 110,621 | -49,235 (-30.80%) | -4,348 (-3.78%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 97,632 | 97,474 | 95,344 | -2,288 (-2.34%) | -2,130 (-2.19%) |
| `testGas_FillRestAskEmptyBook()` | 151,000 | 151,153 | 151,005 | +5 (+0.00%) | -148 (-0.10%) |
| `testGas_FillRestBidEmptyBook()` | 152,915 | 153,038 | 152,929 | +14 (+0.01%) | -109 (-0.07%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 119,410 | 120,107 | 187,980 | +68,570 (+57.42%) | +67,873 (+56.51%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 134,673 | 135,796 | 238,912 | +104,239 (+77.40%) | +103,116 (+75.93%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 135,943 | 137,072 | 251,085 | +115,142 (+84.70%) | +114,013 (+83.18%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 120,622 | 121,325 | 200,523 | +79,901 (+66.24%) | +79,198 (+65.28%) |
| `testGas_LargeRandomBookRestsAsk()` | 161,479 | 161,709 | 256,801 | +95,322 (+59.03%) | +95,092 (+58.80%) |
| `testGas_LargeRandomBookRestsBid()` | 170,889 | 171,240 | 253,649 | +82,760 (+48.43%) | +82,409 (+48.12%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,255,677 | 646,595 | 876,901 | -2,378,776 (-73.07%) | +230,306 (+35.62%) |

</details>

### solar / Full Matrix

#### Integrator fees / routing

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,227 | 127,076 | 124,801 | -2,426 (-1.91%) | -2,275 (-1.79%) |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,726 | 101,587 | 99,290 | -2,436 (-2.39%) | -2,297 (-2.26%) |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,936 | 101,785 | 99,510 | -2,426 (-2.38%) | -2,275 (-2.24%) |
| `testGas_IntegratorFillRestBidEmptyBook()` | 149,820 | 150,116 | 150,108 | +288 (+0.19%) | -8 (-0.01%) |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 116,911 | 114,609 | 112,058 | -4,853 (-4.15%) | -2,551 (-2.23%) |

#### Insertion diagnostics

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testOpportunity_RestAsk16Orders()` | 143,408 | 150,434 | 157,655 | +14,247 (+9.93%) | +7,221 (+4.80%) |
| `testOpportunity_RestAsk64Orders()` | 142,759 | 154,443 | 166,494 | +23,735 (+16.63%) | +12,051 (+7.80%) |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 138,520 | 199,192 | 284,067 | +145,547 (+105.07%) | +84,875 (+42.61%) |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 1,601,303 | 536,374 | 409,802 | -1,191,501 (-74.41%) | -126,572 (-23.60%) |
| `testOpportunity_RestAskLeftNonceComb()` | 1,552,757 | 533,719 | 409,495 | -1,143,262 (-73.63%) | -124,224 (-23.28%) |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 139,434 | 200,109 | 284,960 | +145,526 (+104.37%) | +84,851 (+42.40%) |
| `testOpportunity_RestBid16Orders()` | 145,228 | 152,290 | 159,544 | +14,316 (+9.86%) | +7,254 (+4.76%) |
| `testOpportunity_RestBid64Orders()` | 145,063 | 156,783 | 168,867 | +23,804 (+16.41%) | +12,084 (+7.71%) |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 139,980 | 200,688 | 285,605 | +145,625 (+104.03%) | +84,917 (+42.31%) |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 1,602,866 | 538,053 | 411,800 | -1,191,066 (-74.31%) | -126,253 (-23.46%) |
| `testOpportunity_RestBidLeftNonceComb()` | 1,554,553 | 535,694 | 411,779 | -1,142,774 (-73.51%) | -123,915 (-23.13%) |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 140,476 | 201,187 | 286,080 | +145,604 (+103.65%) | +84,893 (+42.20%) |

#### ERC20 / 100 bps protocol fee

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,615 | 39,659 | 39,639 | +24 (+0.06%) | -20 (-0.05%) |
| `testGas_CancelFilledBidClaim()` | 36,610 | 36,638 | 36,624 | +14 (+0.04%) | -14 (-0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 409,827 | 391,654 | 852,147 | +442,320 (+107.93%) | +460,493 (+117.58%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 410,075 | 391,123 | 760,287 | +350,212 (+85.40%) | +369,164 (+94.39%) |
| `testGas_CancelPartialBid()` | 48,572 | 48,616 | 48,585 | +13 (+0.03%) | -31 (-0.06%) |
| `testGas_CancelUnfilledAsk()` | 39,676 | 39,722 | 39,700 | +24 (+0.06%) | -22 (-0.06%) |
| `testGas_CancelUnfilledBid()` | 39,493 | 39,537 | 39,506 | +13 (+0.03%) | -31 (-0.08%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,363,009 | 378,385 | 358,972 | -1,004,037 (-73.66%) | -19,413 (-5.13%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,151,061 | 587,494 | 255,333 | -895,728 (-77.82%) | -332,161 (-56.54%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 430,156 | 376,907 | 116,613 | -313,543 (-72.89%) | -260,294 (-69.06%) |
| `testGas_DirtyAskSmallFill16Orders()` | 144,483 | 112,300 | 120,169 | -24,314 (-16.83%) | +7,869 (+7.01%) |
| `testGas_DirtyAskSmallFill64Orders()` | 182,834 | 123,660 | 136,621 | -46,213 (-25.28%) | +12,961 (+10.48%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,360,205 | 281,632 | 360,789 | -999,416 (-73.48%) | +79,157 (+28.11%) |
| `testGas_DirtyAskWholeNonceComb()` | 347,288 | 326,929 | 90,743 | -256,545 (-73.87%) | -236,186 (-72.24%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,364,922 | 379,925 | 360,392 | -1,004,530 (-73.60%) | -19,533 (-5.14%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,150,975 | 587,215 | 254,949 | -896,026 (-77.85%) | -332,266 (-56.58%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 430,310 | 377,061 | 116,677 | -313,633 (-72.89%) | -260,384 (-69.06%) |
| `testGas_DirtyBidSmallFill16Orders()` | 143,992 | 111,748 | 119,592 | -24,400 (-16.95%) | +7,844 (+7.02%) |
| `testGas_DirtyBidSmallFill64Orders()` | 183,627 | 124,332 | 137,264 | -46,363 (-25.25%) | +12,932 (+10.40%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,361,044 | 282,098 | 361,174 | -999,870 (-73.46%) | +79,076 (+28.03%) |
| `testGas_DirtyBidWholeNonceComb()` | 346,344 | 325,997 | 89,773 | -256,571 (-74.08%) | -236,224 (-72.46%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 84,927 | 82,935 | 56,567 | -28,360 (-33.39%) | -26,368 (-31.79%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 342,967 | 348,732 | 101,041 | -241,926 (-70.54%) | -247,691 (-71.03%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,905 | 76,766 | 74,469 | -2,436 (-3.17%) | -2,297 (-2.99%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 157,453 | 112,805 | 108,671 | -48,782 (-30.98%) | -4,134 (-3.66%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 96,355 | 96,216 | 93,947 | -2,408 (-2.50%) | -2,269 (-2.36%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,390 | 128,399 | 126,087 | -2,303 (-1.79%) | -2,312 (-1.80%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 85,167 | 83,160 | 56,845 | -28,322 (-33.25%) | -26,315 (-31.64%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 316,687 | 322,428 | 76,499 | -240,188 (-75.84%) | -245,929 (-76.27%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 76,534 | 76,422 | 73,588 | -2,946 (-3.85%) | -2,834 (-3.71%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 76,716 | 76,565 | 74,290 | -2,426 (-3.16%) | -2,275 (-2.97%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 157,311 | 112,684 | 108,581 | -48,730 (-30.98%) | -4,103 (-3.64%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 96,501 | 96,350 | 94,103 | -2,398 (-2.48%) | -2,247 (-2.33%) |
| `testGas_FillRestAskEmptyBook()` | 149,363 | 149,647 | 149,617 | +254 (+0.17%) | -30 (-0.02%) |
| `testGas_FillRestBidEmptyBook()` | 150,954 | 151,250 | 151,242 | +288 (+0.19%) | -8 (-0.01%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 117,098 | 117,305 | 181,809 | +64,711 (+55.26%) | +64,504 (+54.99%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 132,795 | 133,222 | 231,434 | +98,639 (+74.28%) | +98,212 (+73.72%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 133,777 | 134,210 | 242,628 | +108,851 (+81.37%) | +108,418 (+80.78%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 118,038 | 118,251 | 192,809 | +74,771 (+63.34%) | +74,558 (+63.05%) |
| `testGas_LargeRandomBookRestsAsk()` | 158,823 | 158,821 | 250,670 | +91,847 (+57.83%) | +91,849 (+57.83%) |
| `testGas_LargeRandomBookRestsBid()` | 167,712 | 167,755 | 247,022 | +79,310 (+47.29%) | +79,267 (+47.25%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,255,942 | 657,507 | 869,999 | -2,385,943 (-73.28%) | +212,492 (+32.32%) |

#### ERC20 / no hooks

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,615 | 39,659 | 39,639 | +24 (+0.06%) | -20 (-0.05%) |
| `testGas_CancelFilledBidClaim()` | 36,610 | 36,638 | 36,624 | +14 (+0.04%) | -14 (-0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 409,827 | 391,654 | 852,147 | +442,320 (+107.93%) | +460,493 (+117.58%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 410,075 | 391,123 | 760,287 | +350,212 (+85.40%) | +369,164 (+94.39%) |
| `testGas_CancelPartialBid()` | 48,572 | 48,616 | 48,585 | +13 (+0.03%) | -31 (-0.06%) |
| `testGas_CancelUnfilledAsk()` | 39,676 | 39,722 | 39,700 | +24 (+0.06%) | -22 (-0.06%) |
| `testGas_CancelUnfilledBid()` | 39,493 | 39,537 | 39,506 | +13 (+0.03%) | -31 (-0.08%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,362,575 | 377,951 | 358,538 | -1,004,037 (-73.69%) | -19,413 (-5.14%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,125,591 | 562,024 | 229,863 | -895,728 (-79.58%) | -332,161 (-59.10%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 404,686 | 351,437 | 91,143 | -313,543 (-77.48%) | -260,294 (-74.07%) |
| `testGas_DirtyAskSmallFill16Orders()` | 144,049 | 111,866 | 119,735 | -24,314 (-16.88%) | +7,869 (+7.03%) |
| `testGas_DirtyAskSmallFill64Orders()` | 182,400 | 123,226 | 136,187 | -46,213 (-25.34%) | +12,961 (+10.52%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,359,771 | 281,198 | 360,355 | -999,416 (-73.50%) | +79,157 (+28.15%) |
| `testGas_DirtyAskWholeNonceComb()` | 321,818 | 301,459 | 65,273 | -256,545 (-79.72%) | -236,186 (-78.35%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,364,503 | 379,506 | 359,973 | -1,004,530 (-73.62%) | -19,533 (-5.15%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,125,520 | 561,760 | 229,494 | -896,026 (-79.61%) | -332,266 (-59.15%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 404,855 | 351,606 | 91,222 | -313,633 (-77.47%) | -260,384 (-74.06%) |
| `testGas_DirtyBidSmallFill16Orders()` | 143,573 | 111,329 | 119,173 | -24,400 (-16.99%) | +7,844 (+7.05%) |
| `testGas_DirtyBidSmallFill64Orders()` | 183,208 | 123,913 | 136,845 | -46,363 (-25.31%) | +12,932 (+10.44%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,360,625 | 281,679 | 360,755 | -999,870 (-73.49%) | +79,076 (+28.07%) |
| `testGas_DirtyBidWholeNonceComb()` | 320,889 | 300,542 | 64,318 | -256,571 (-79.96%) | -236,224 (-78.60%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 84,508 | 82,516 | 56,148 | -28,360 (-33.56%) | -26,368 (-31.96%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 317,512 | 323,277 | 75,586 | -241,926 (-76.19%) | -247,691 (-76.62%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,486 | 76,347 | 74,050 | -2,436 (-3.18%) | -2,297 (-3.01%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 157,034 | 112,386 | 108,252 | -48,782 (-31.06%) | -4,134 (-3.68%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,936 | 95,797 | 93,528 | -2,408 (-2.51%) | -2,269 (-2.37%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 127,956 | 127,965 | 125,653 | -2,303 (-1.80%) | -2,312 (-1.81%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 84,733 | 82,726 | 56,411 | -28,322 (-33.42%) | -26,315 (-31.81%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 316,253 | 321,994 | 76,065 | -240,188 (-75.95%) | -245,929 (-76.38%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 76,100 | 75,988 | 73,154 | -2,946 (-3.87%) | -2,834 (-3.73%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 76,282 | 76,131 | 73,856 | -2,426 (-3.18%) | -2,275 (-2.99%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 156,877 | 112,250 | 108,147 | -48,730 (-31.06%) | -4,103 (-3.66%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 96,067 | 95,916 | 93,669 | -2,398 (-2.50%) | -2,247 (-2.34%) |
| `testGas_FillRestAskEmptyBook()` | 149,201 | 149,485 | 149,455 | +254 (+0.17%) | -30 (-0.02%) |
| `testGas_FillRestBidEmptyBook()` | 150,791 | 151,087 | 151,079 | +288 (+0.19%) | -8 (-0.01%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 116,679 | 116,886 | 181,390 | +64,711 (+55.46%) | +64,504 (+55.19%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 132,361 | 132,788 | 231,000 | +98,639 (+74.52%) | +98,212 (+73.96%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 133,343 | 133,776 | 242,194 | +108,851 (+81.63%) | +108,418 (+81.04%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 117,619 | 117,832 | 192,390 | +74,771 (+63.57%) | +74,558 (+63.27%) |
| `testGas_LargeRandomBookRestsAsk()` | 158,661 | 158,659 | 250,508 | +91,847 (+57.89%) | +91,849 (+57.89%) |
| `testGas_LargeRandomBookRestsBid()` | 167,549 | 167,592 | 246,859 | +79,310 (+47.34%) | +79,267 (+47.30%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,230,487 | 632,052 | 844,544 | -2,385,943 (-73.86%) | +212,492 (+33.62%) |

#### Native ETH / prior-fill histories

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 85,913 | 84,793 | 125,494 | +39,581 (+46.07%) | +40,701 (+48.00%) |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 95,887 | 95,946 | 142,580 | +46,693 (+48.70%) | +46,634 (+48.60%) |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 519,255 | 173,122 | 225,442 | -293,813 (-56.58%) | +52,320 (+30.22%) |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 345,309 | 330,980 | 741,028 | +395,719 (+114.60%) | +410,048 (+123.89%) |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 386,863 | 358,826 | 741,490 | +354,627 (+91.67%) | +382,664 (+106.64%) |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 3,876,191 | 781,012 | 844,794 | -3,031,397 (-78.21%) | +63,782 (+8.17%) |

#### Mixed-price sweep stress

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_MixedSweep1024()` | 8,088,886 | 8,348,842 | 98,278 | -7,990,608 (-98.79%) | -8,250,564 (-98.82%) |
| `testGas_MixedSweep1024AndRest()` | 8,140,715 | 8,400,858 | 150,257 | -7,990,458 (-98.15%) | -8,250,601 (-98.21%) |
| `testGas_MixedSweep1024BurningHookAndFees()` | 8,323,290 | 8,583,306 | 350,807 | -7,972,483 (-95.79%) | -8,232,499 (-95.91%) |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 1,009,760 | 1,009,760 | 97,550 | N/A (outcome changed) | N/A (outcome changed) |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 8,577,913 | 8,838,116 | 607,873 | -7,970,040 (-92.91%) | -8,230,243 (-93.12%) |
| `testGas_MixedSweep256()` | 2,089,456 | 2,154,340 | 97,962 | -1,991,494 (-95.31%) | -2,056,378 (-95.45%) |
| `testGas_MixedSweep4096()` | 32,082,720 | 33,122,964 | 98,838 | -31,983,882 (-99.69%) | -33,024,126 (-99.70%) |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 32,571,839 | 33,612,348 | 614,543 | -31,957,296 (-98.11%) | -32,997,805 (-98.17%) |
| `testGas_MixedSweep64()` | 589,127 | 605,243 | 97,262 | -491,865 (-83.49%) | -507,981 (-83.93%) |

#### ERC20 / top-order hooks

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 43,396 | 43,440 | 43,428 | +32 (+0.07%) | -12 (-0.03%) |
| `testGas_CancelFilledBidClaim()` | 37,107 | 37,135 | 37,121 | +14 (+0.04%) | -14 (-0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 431,492 | 413,725 | 874,219 | +442,727 (+102.60%) | +460,494 (+111.30%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 430,883 | 412,326 | 781,502 | +350,619 (+81.37%) | +369,176 (+89.53%) |
| `testGas_CancelPartialBid()` | 52,892 | 52,943 | 52,911 | +19 (+0.04%) | -32 (-0.06%) |
| `testGas_CancelUnfilledAsk()` | 43,457 | 43,501 | 43,489 | +32 (+0.07%) | -12 (-0.03%) |
| `testGas_CancelUnfilledBid()` | 43,813 | 43,864 | 43,832 | +19 (+0.04%) | -32 (-0.07%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,375,869 | 389,247 | 382,016 | -993,853 (-72.23%) | -7,231 (-1.86%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,136,684 | 571,119 | 280,371 | -856,313 (-75.33%) | -290,748 (-50.91%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 413,475 | 358,228 | 170,248 | -243,227 (-58.83%) | -187,980 (-52.47%) |
| `testGas_DirtyAskSmallFill16Orders()` | 150,959 | 118,776 | 130,339 | -20,620 (-13.66%) | +11,563 (+9.74%) |
| `testGas_DirtyAskSmallFill64Orders()` | 189,598 | 130,424 | 147,583 | -42,015 (-22.16%) | +17,159 (+13.16%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,370,713 | 292,140 | 382,047 | -988,666 (-72.13%) | +89,907 (+30.78%) |
| `testGas_DirtyAskWholeNonceComb()` | 328,111 | 307,752 | 144,201 | -183,910 (-56.05%) | -163,551 (-53.14%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,378,775 | 391,780 | 384,429 | -994,346 (-72.12%) | -7,351 (-1.88%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,137,591 | 571,833 | 280,980 | -856,611 (-75.30%) | -290,853 (-50.86%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 414,622 | 359,375 | 171,305 | -243,317 (-58.68%) | -188,070 (-52.33%) |
| `testGas_DirtyBidSmallFill16Orders()` | 151,461 | 119,217 | 130,755 | -20,706 (-13.67%) | +11,538 (+9.68%) |
| `testGas_DirtyBidSmallFill64Orders()` | 191,384 | 132,089 | 149,219 | -42,165 (-22.03%) | +17,130 (+12.97%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,372,545 | 293,599 | 383,425 | -989,120 (-72.06%) | +89,826 (+30.59%) |
| `testGas_DirtyBidWholeNonceComb()` | 328,160 | 307,813 | 144,224 | -183,936 (-56.05%) | -163,589 (-53.15%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 91,779 | 89,787 | 72,312 | -19,467 (-21.21%) | -17,475 (-19.46%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 403,175 | 409,330 | 225,704 | -177,471 (-44.02%) | -183,626 (-44.86%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 83,719 | 83,580 | 83,541 | -178 (-0.21%) | -39 (-0.05%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 170,225 | 125,010 | 122,828 | -47,397 (-27.84%) | -2,182 (-1.75%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 103,169 | 103,030 | 105,212 | +2,043 (+1.98%) | +2,182 (+2.12%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 136,001 | 136,010 | 138,249 | +2,248 (+1.65%) | +2,239 (+1.65%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 91,026 | 89,019 | 71,597 | -19,429 (-21.34%) | -17,422 (-19.57%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 401,059 | 407,190 | 225,326 | -175,733 (-43.82%) | -181,864 (-44.66%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 91,379 | 91,297 | 90,538 | -841 (-0.92%) | -759 (-0.83%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 82,616 | 82,465 | 82,448 | -168 (-0.20%) | -17 (-0.02%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 169,090 | 123,896 | 121,745 | -47,345 (-28.00%) | -2,151 (-1.74%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 102,401 | 102,250 | 104,454 | +2,053 (+2.00%) | +2,204 (+2.16%) |
| `testGas_FillRestAskEmptyBook()` | 138,409 | 138,686 | 140,950 | +2,541 (+1.84%) | +2,264 (+1.63%) |
| `testGas_FillRestBidEmptyBook()` | 139,999 | 140,288 | 142,574 | +2,575 (+1.84%) | +2,286 (+1.63%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 131,945 | 132,175 | 198,327 | +66,382 (+50.31%) | +66,152 (+50.05%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 149,106 | 149,562 | 250,178 | +101,072 (+67.79%) | +100,616 (+67.27%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 141,117 | 141,550 | 255,174 | +114,057 (+80.82%) | +113,624 (+80.27%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 126,106 | 126,319 | 205,327 | +79,221 (+62.82%) | +79,008 (+62.55%) |
| `testGas_LargeRandomBookRestsAsk()` | 187,648 | 187,720 | 285,882 | +98,234 (+52.35%) | +98,162 (+52.29%) |
| `testGas_LargeRandomBookRestsBid()` | 191,105 | 191,192 | 269,378 | +78,273 (+40.96%) | +78,186 (+40.89%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,252,490 | 654,450 | 869,077 | -2,383,413 (-73.28%) | +214,627 (+32.80%) |

<details>
<summary>solar: 42 inherited repeat rows, excluded from summary</summary>

| Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |
|---|---:|---:|---:|---:|---:|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,681 | 39,725 | 39,705 | +24 (+0.06%) | -20 (-0.05%) |
| `testGas_CancelFilledBidClaim()` | 36,676 | 36,704 | 36,690 | +14 (+0.04%) | -14 (-0.04%) |
| `testGas_CancelFullDepthBidCombRightmost()` | 409,849 | 391,676 | 852,169 | +442,320 (+107.92%) | +460,493 (+117.57%) |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 410,075 | 391,123 | 760,287 | +350,212 (+85.40%) | +369,164 (+94.39%) |
| `testGas_CancelPartialBid()` | 48,638 | 48,682 | 48,651 | +13 (+0.03%) | -31 (-0.06%) |
| `testGas_CancelUnfilledAsk()` | 39,786 | 39,832 | 39,810 | +24 (+0.06%) | -22 (-0.06%) |
| `testGas_CancelUnfilledBid()` | 39,559 | 39,603 | 39,572 | +13 (+0.03%) | -31 (-0.08%) |
| `testGas_DirtyAskCrossLeafNonceComb()` | 1,362,632 | 378,008 | 358,595 | -1,004,037 (-73.68%) | -19,413 (-5.14%) |
| `testGas_DirtyAskHalfNonceComb()` | 1,125,714 | 562,147 | 229,986 | -895,728 (-79.57%) | -332,161 (-59.09%) |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 404,765 | 351,516 | 91,222 | -313,543 (-77.46%) | -260,294 (-74.05%) |
| `testGas_DirtyAskSmallFill16Orders()` | 144,282 | 112,099 | 119,968 | -24,314 (-16.85%) | +7,869 (+7.02%) |
| `testGas_DirtyAskSmallFill64Orders()` | 182,479 | 123,305 | 136,266 | -46,213 (-25.33%) | +12,961 (+10.51%) |
| `testGas_DirtyAskSmallFillNonceComb()` | 1,359,828 | 281,255 | 360,412 | -999,416 (-73.50%) | +79,157 (+28.14%) |
| `testGas_DirtyAskWholeNonceComb()` | 321,941 | 301,582 | 65,396 | -256,545 (-79.69%) | -236,186 (-78.32%) |
| `testGas_DirtyBidCrossLeafNonceComb()` | 1,364,758 | 379,761 | 360,228 | -1,004,530 (-73.60%) | -19,533 (-5.14%) |
| `testGas_DirtyBidHalfNonceComb()` | 1,125,599 | 561,839 | 229,573 | -896,026 (-79.60%) | -332,266 (-59.14%) |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 404,956 | 351,707 | 91,323 | -313,633 (-77.45%) | -260,384 (-74.03%) |
| `testGas_DirtyBidSmallFill16Orders()` | 143,696 | 111,452 | 119,296 | -24,400 (-16.98%) | +7,844 (+7.04%) |
| `testGas_DirtyBidSmallFill64Orders()` | 183,375 | 124,080 | 137,012 | -46,363 (-25.28%) | +12,932 (+10.42%) |
| `testGas_DirtyBidSmallFillNonceComb()` | 1,360,682 | 281,736 | 360,812 | -999,870 (-73.48%) | +79,076 (+28.07%) |
| `testGas_DirtyBidWholeNonceComb()` | 320,946 | 300,599 | 64,375 | -256,571 (-79.94%) | -236,224 (-78.58%) |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 84,602 | 82,610 | 56,242 | -28,360 (-33.52%) | -26,368 (-31.92%) |
| `testGas_FillAskConsumesFullDepthBidComb()` | 317,606 | 323,371 | 75,680 | -241,926 (-76.17%) | -247,691 (-76.60%) |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,668 | 76,529 | 74,232 | -2,436 (-3.18%) | -2,297 (-3.00%) |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 157,128 | 112,480 | 108,346 | -48,782 (-31.05%) | -4,134 (-3.68%) |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 96,074 | 95,935 | 93,666 | -2,408 (-2.51%) | -2,269 (-2.37%) |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,025 | 128,034 | 125,722 | -2,303 (-1.80%) | -2,312 (-1.81%) |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 84,846 | 82,839 | 56,524 | -28,322 (-33.38%) | -26,315 (-31.77%) |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 316,366 | 322,107 | 76,178 | -240,188 (-75.92%) | -245,929 (-76.35%) |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 76,169 | 76,057 | 73,223 | -2,946 (-3.87%) | -2,834 (-3.73%) |
| `testGas_FillBidFullyMatchesSingleAsk()` | 76,395 | 76,244 | 73,969 | -2,426 (-3.18%) | -2,275 (-2.98%) |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 156,946 | 112,319 | 108,216 | -48,730 (-31.05%) | -4,103 (-3.65%) |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 96,202 | 96,051 | 93,804 | -2,398 (-2.49%) | -2,247 (-2.34%) |
| `testGas_FillRestAskEmptyBook()` | 149,295 | 149,579 | 149,549 | +254 (+0.17%) | -30 (-0.02%) |
| `testGas_FillRestBidEmptyBook()` | 150,926 | 151,222 | 151,214 | +288 (+0.19%) | -8 (-0.01%) |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 116,795 | 117,002 | 181,506 | +64,711 (+55.41%) | +64,504 (+55.13%) |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 132,496 | 132,923 | 231,135 | +98,639 (+74.45%) | +98,212 (+73.89%) |
| `testGas_LargeRandomBookPartialFillsAsk()` | 133,544 | 133,977 | 242,395 | +108,851 (+81.51%) | +108,418 (+80.92%) |
| `testGas_LargeRandomBookPartialFillsBid()` | 117,757 | 117,970 | 192,528 | +74,771 (+63.50%) | +74,558 (+63.20%) |
| `testGas_LargeRandomBookRestsAsk()` | 158,733 | 158,731 | 250,580 | +91,847 (+57.86%) | +91,849 (+57.86%) |
| `testGas_LargeRandomBookRestsBid()` | 167,640 | 167,683 | 246,950 | +79,310 (+47.31%) | +79,267 (+47.27%) |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 3,230,581 | 632,146 | 844,638 | -2,385,943 (-73.85%) | +212,492 (+33.61%) |

</details>
