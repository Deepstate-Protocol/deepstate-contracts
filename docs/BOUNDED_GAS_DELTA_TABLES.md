# Complete Bounded Gas Delta Tables

Every measured row is included, without a savings threshold or selected-case filter. Each table contains 188 release rows and 12 insertion diagnostics. Inherited repeats and the capped-gas functional check remain visible and are labeled.

The selected prototype is **E / `uniform-difference`**, with no zero-delta quote-cache guard. It remains an investigative patch, not the deployed or working contract source. See [selection metadata](bounded-gas-opportunities/selection.json).

Controls: bounded baseline `096eab28d87debdd472b4e22e65820e2b1b8d523`; solc 0.8.28, via-IR, optimizer 200, Cancun; separate experimental Solar 0.3.0 / Solidity 0.8.38 comparison; Forge executor `d3167db683c001c196126c912027437a9cb0bfb9`. The original frozen harness and runtime-only substitution are unchanged. These are verified existing measurements, not new benchmark runs.

Percentages are displayed to four decimal places; the [complete CSV](BOUNDED_GAS_OPPORTUNITIES.csv) retains full precision and also includes the same-harness master `bf18c54` comparison. Failed master capped-gas outcomes have no successful-operation delta. No production-weighted savings percentage is inferred.

## Contents

- [Selected E: solc, all 200 cases](#selected-solc)
- [Selected E: Solar, all 200 cases](#selected-solar)
- [Stage A: all 200 cases](#stage-a)
- [Stage B: all 200 cases](#stage-b)
- [Stage C: all 200 cases](#stage-c)
- [Stage C2: all 200 cases](#stage-c2)
- [Stage D: all 200 cases](#stage-d)
- [Rejected zero-delta experiment: all 200 cases](bounded-gas-opportunities/rejected/ZERO_DELTA_GAS.md)

<a id="selected-solc"></a>

## solc / E / uniform-difference

Status: **selected prototype; no zero-delta guard**. Previous stage: `insert-delta`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,022 | 127,022 | 0 | 0.0000% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,386 | 101,386 | 0 | 0.0000% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,542 | 101,542 | 0 | 0.0000% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,828 | 117,828 | 0 | 0.0000% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 161,247 | 161,247 | 0 | 0.0000% | +422 | +0.2624% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 170,558 | 170,558 | 0 | 0.0000% | +546 | +0.3212% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 166,107 | 166,107 | 0 | 0.0000% | -125,616 | -43.0600% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 386,058 | 386,058 | 0 | 0.0000% | -48,558 | -11.1726% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 385,751 | 385,751 | 0 | 0.0000% | -48,558 | -11.1805% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 167,049 | 167,049 | 0 | 0.0000% | -125,617 | -42.9216% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 163,215 | 163,215 | 0 | 0.0000% | +422 | +0.2592% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 173,010 | 173,010 | 0 | 0.0000% | +546 | +0.3166% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 167,923 | 167,923 | 0 | 0.0000% | -125,616 | -42.7936% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 388,388 | 388,388 | 0 | 0.0000% | -48,753 | -11.1527% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 388,367 | 388,367 | 0 | 0.0000% | -48,753 | -11.1532% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 168,422 | 168,422 | 0 | 0.0000% | -125,617 | -42.7212% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,276 | 363,099 | -5,177 | -1.4057% | -5,206 | -1.4135% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,395 | 258,723 | -2,672 | -1.0222% | -2,701 | -1.0332% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,805 | 122,137 | -668 | -0.5440% | -697 | -0.5674% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,721 | 138,719 | -1,002 | -0.7171% | -1,031 | -0.7377% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,921 | 364,577 | -5,344 | -1.4446% | -5,373 | -1.4524% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,780 | 365,006 | -4,774 | -1.2910% | -4,803 | -1.2988% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,071 | 258,607 | -2,464 | -0.9438% | -2,493 | -0.9548% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,299 | 121,683 | -616 | -0.5037% | -645 | -0.5273% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,435 | 139,511 | -924 | -0.6580% | -953 | -0.6785% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,377 | 365,449 | -4,928 | -1.3305% | -4,957 | -1.3383% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,263 | 111,109 | -154 | -0.1384% | -183 | -0.1644% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,117 | 110,950 | -167 | -0.1503% | -196 | -0.1763% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,912 | 166,912 | 0 | 0.0000% | -21,556 | -11.4375% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 208,068 | 208,068 | 0 | 0.0000% | -31,303 | -13.0772% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,375 | 217,375 | 0 | 0.0000% | -34,103 | -13.5610% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,205 | 176,205 | 0 | 0.0000% | -24,784 | -12.3310% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 204,017 | 204,017 | 0 | 0.0000% | -52,938 | -20.6021% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 220,906 | 220,906 | 0 | 0.0000% | -32,871 | -12.9527% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 835,182 | 832,910 | -2,272 | -0.2720% | -69,587 | -7.7105% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,682 | 362,505 | -5,177 | -1.4080% | -5,206 | -1.4158% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,719 | 233,047 | -2,672 | -1.1336% | -2,701 | -1.1457% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,211 | 121,543 | -668 | -0.5466% | -697 | -0.5702% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,127 | 138,125 | -1,002 | -0.7202% | -1,031 | -0.7409% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,327 | 363,983 | -5,344 | -1.4470% | -5,373 | -1.4547% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,176 | 364,402 | -4,774 | -1.2932% | -4,803 | -1.3009% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,381 | 232,917 | -2,464 | -1.0468% | -2,493 | -1.0590% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,695 | 121,079 | -616 | -0.5062% | -645 | -0.5299% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,831 | 138,907 | -924 | -0.6608% | -953 | -0.6814% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,773 | 364,845 | -4,928 | -1.3327% | -4,957 | -1.3404% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,659 | 110,505 | -154 | -0.1392% | -183 | -0.1653% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,523 | 110,356 | -167 | -0.1511% | -196 | -0.1773% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,308 | 166,308 | 0 | 0.0000% | -21,556 | -11.4743% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,474 | 207,474 | 0 | 0.0000% | -31,303 | -13.1097% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,781 | 216,781 | 0 | 0.0000% | -34,103 | -13.5931% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,601 | 175,601 | 0 | 0.0000% | -24,784 | -12.3682% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 203,791 | 203,791 | 0 | 0.0000% | -52,938 | -20.6202% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 220,687 | 220,687 | 0 | 0.0000% | -32,871 | -12.9639% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 809,492 | 807,220 | -2,272 | -0.2807% | -69,587 | -7.9364% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 120,203 | 120,203 | 0 | 0.0000% | -13,409 | -10.0358% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,337 | 136,337 | 0 | 0.0000% | -17,573 | -11.4177% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 228,965 | 228,965 | 0 | 0.0000% | -7,676 | -3.2437% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 675,740 | 675,740 | 0 | 0.0000% | -94,884 | -12.3126% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 703,595 | 702,104 | -1,491 | -0.2119% | -70,594 | -9.1360% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 791,805 | 791,805 | 0 | 0.0000% | -83,127 | -9.5010% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,433 | 40,433 | 0 | 0.0000% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,258 | 37,258 | 0 | 0.0000% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 775,178 | 775,178 | 0 | 0.0000% | -112,374 | -12.6611% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,328 | 49,328 | 0 | 0.0000% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,716 | 40,716 | 0 | 0.0000% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,248 | 40,248 | 0 | 0.0000% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,739 | 362,562 | -5,177 | -1.4078% | -5,206 | -1.4156% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,842 | 233,170 | -2,672 | -1.1330% | -2,701 | -1.1451% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,444 | 121,776 | -668 | -0.5456% | -697 | -0.5691% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,206 | 138,204 | -1,002 | -0.7198% | -1,031 | -0.7405% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,384 | 364,040 | -5,344 | -1.4467% | -5,373 | -1.4545% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,431 | 364,657 | -4,774 | -1.2923% | -4,803 | -1.3000% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,460 | 232,996 | -2,464 | -1.0465% | -2,493 | -1.0586% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,818 | 121,202 | -616 | -0.5057% | -645 | -0.5294% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,998 | 139,074 | -924 | -0.6600% | -953 | -0.6806% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,830 | 364,902 | -4,928 | -1.3325% | -4,957 | -1.3402% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,753 | 110,599 | -154 | -0.1390% | -183 | -0.1652% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,592 | 110,425 | -167 | -0.1510% | -196 | -0.1772% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,424 | 166,424 | 0 | 0.0000% | -21,556 | -11.4672% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,609 | 207,609 | 0 | 0.0000% | -31,303 | -13.1023% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,982 | 216,982 | 0 | 0.0000% | -34,103 | -13.5823% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,739 | 175,739 | 0 | 0.0000% | -24,784 | -12.3597% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 203,863 | 203,863 | 0 | 0.0000% | -52,938 | -20.6144% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 220,778 | 220,778 | 0 | 0.0000% | -32,871 | -12.9592% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,618 | 99,618 | 0 | 0.0000% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,902 | 151,902 | 0 | 0.0000% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 352,988 | 352,988 | 0 | 0.0000% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,890 | 98,890 | 0 | 0.0000% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,582 | 610,582 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,302 | 99,302 | 0 | 0.0000% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,178 | 100,178 | 0 | 0.0000% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,312 | 617,312 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,602 | 98,602 | 0 | 0.0000% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 809,586 | 807,314 | -2,272 | -0.2806% | -69,587 | -7.9356% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,373 | 44,373 | 0 | 0.0000% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,909 | 37,909 | 0 | 0.0000% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 798,870 | 798,870 | 0 | 0.0000% | -112,375 | -12.3320% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 708,450 | 708,450 | 0 | 0.0000% | -110,868 | -13.5317% | - |
| `testGas_CancelPartialBid()` | 53,890 | 54,017 | 54,017 | 0 | 0.0000% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,612 | 44,612 | 0 | 0.0000% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,937 | 44,937 | 0 | 0.0000% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,000 | 387,823 | -5,177 | -1.3173% | -5,206 | -1.3246% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,767 | 285,095 | -2,672 | -0.9285% | -2,701 | -0.9385% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,548 | 132,880 | -668 | -0.5002% | -697 | -0.5218% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,336 | 150,334 | -1,002 | -0.6621% | -1,031 | -0.6811% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,872 | 387,528 | -5,344 | -1.3602% | -5,373 | -1.3675% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,637 | 390,863 | -4,774 | -1.2067% | -4,803 | -1.2139% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,572 | 286,108 | -2,464 | -0.8539% | -2,493 | -0.8638% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,175 | 133,559 | -616 | -0.4591% | -645 | -0.4806% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,183 | 152,259 | -924 | -0.6032% | -953 | -0.6220% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,461 | 389,533 | -4,928 | -1.2493% | -4,957 | -1.2566% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,040 | 125,886 | -154 | -0.1222% | -183 | -0.1452% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,761 | 124,594 | -167 | -0.1339% | -196 | -0.1571% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,190 | 185,190 | 0 | 0.0000% | -21,556 | -10.4263% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,645 | 227,645 | 0 | 0.0000% | -31,303 | -12.0885% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,734 | 230,734 | 0 | 0.0000% | -34,103 | -12.8770% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,483 | 190,483 | 0 | 0.0000% | -24,784 | -11.5131% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 240,296 | 240,296 | 0 | 0.0000% | -52,938 | -18.0532% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 253,430 | 253,430 | 0 | 0.0000% | -24,871 | -8.9367% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 835,887 | 833,615 | -2,272 | -0.2718% | -69,587 | -7.7045% | - |

<a id="selected-solar"></a>

## solar / E / uniform-difference

Status: **selected prototype; separate compiler comparison**. Previous stage: `096eab2 (bounded baseline)`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 124,801 | 124,801 | 124,804 | +3 | +0.0024% | +3 | +0.0024% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 99,290 | 99,290 | 99,293 | +3 | +0.0030% | +3 | +0.0030% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 99,510 | 99,510 | 99,513 | +3 | +0.0030% | +3 | +0.0030% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 150,108 | 150,108 | 150,111 | +3 | +0.0020% | +3 | +0.0020% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 112,058 | 112,058 | 112,061 | +3 | +0.0027% | +3 | +0.0027% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 157,655 | 157,655 | 157,922 | +267 | +0.1694% | +267 | +0.1694% | - |
| `testOpportunity_RestAsk64Orders()` | 166,494 | 166,494 | 166,859 | +365 | +0.2192% | +365 | +0.2192% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 284,067 | 284,067 | 163,201 | -120,866 | -42.5484% | -120,866 | -42.5484% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 409,802 | 409,802 | 371,112 | -38,690 | -9.4411% | -38,690 | -9.4411% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 409,495 | 409,495 | 370,805 | -38,690 | -9.4482% | -38,690 | -9.4482% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 284,960 | 284,960 | 164,094 | -120,866 | -42.4151% | -120,866 | -42.4151% | - |
| `testOpportunity_RestBid16Orders()` | 159,544 | 159,544 | 159,811 | +267 | +0.1674% | +267 | +0.1674% | - |
| `testOpportunity_RestBid64Orders()` | 168,867 | 168,867 | 169,232 | +365 | +0.2161% | +365 | +0.2161% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 285,605 | 285,605 | 164,739 | -120,866 | -42.3193% | -120,866 | -42.3193% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 411,800 | 411,800 | 373,318 | -38,482 | -9.3448% | -38,482 | -9.3448% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 411,779 | 411,779 | 373,297 | -38,482 | -9.3453% | -38,482 | -9.3453% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 286,080 | 286,080 | 165,214 | -120,866 | -42.2490% | -120,866 | -42.2490% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,639 | 39,639 | 39,851 | +212 | +0.5348% | +212 | +0.5348% | - |
| `testGas_CancelFilledBidClaim()` | 36,624 | 36,624 | 36,570 | -54 | -0.1474% | -54 | -0.1474% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 852,147 | 852,147 | 754,176 | -97,971 | -11.4970% | -97,971 | -11.4970% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 760,287 | 760,287 | 664,641 | -95,646 | -12.5802% | -95,646 | -12.5802% | - |
| `testGas_CancelPartialBid()` | 48,585 | 48,585 | 48,640 | +55 | +0.1132% | +55 | +0.1132% | - |
| `testGas_CancelUnfilledAsk()` | 39,700 | 39,700 | 39,912 | +212 | +0.5340% | +212 | +0.5340% | - |
| `testGas_CancelUnfilledBid()` | 39,506 | 39,506 | 39,561 | +55 | +0.1392% | +55 | +0.1392% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 358,972 | 358,972 | 355,844 | -3,128 | -0.8714% | -3,128 | -0.8714% | - |
| `testGas_DirtyAskHalfNonceComb()` | 255,333 | 255,333 | 253,720 | -1,613 | -0.6317% | -1,613 | -0.6317% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 116,613 | 116,613 | 116,616 | +3 | +0.0026% | +3 | +0.0026% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 120,169 | 120,169 | 119,768 | -401 | -0.3337% | -401 | -0.3337% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 136,621 | 136,621 | 136,018 | -603 | -0.4414% | -603 | -0.4414% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 360,789 | 360,789 | 357,560 | -3,229 | -0.8950% | -3,229 | -0.8950% | - |
| `testGas_DirtyAskWholeNonceComb()` | 90,743 | 90,743 | 90,746 | +3 | +0.0033% | +3 | +0.0033% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 360,392 | 360,392 | 356,799 | -3,593 | -0.9970% | -3,593 | -0.9970% | - |
| `testGas_DirtyBidHalfNonceComb()` | 254,949 | 254,949 | 253,096 | -1,853 | -0.7268% | -1,853 | -0.7268% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 116,677 | 116,677 | 116,680 | +3 | +0.0026% | +3 | +0.0026% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 119,592 | 119,592 | 119,131 | -461 | -0.3855% | -461 | -0.3855% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 137,264 | 137,264 | 136,571 | -693 | -0.5049% | -693 | -0.5049% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 361,174 | 361,174 | 357,465 | -3,709 | -1.0269% | -3,709 | -1.0269% | - |
| `testGas_DirtyBidWholeNonceComb()` | 89,773 | 89,773 | 89,776 | +3 | +0.0033% | +3 | +0.0033% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 56,567 | 56,567 | 56,570 | +3 | +0.0053% | +3 | +0.0053% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 101,041 | 101,041 | 101,046 | +5 | +0.0049% | +5 | +0.0049% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 74,469 | 74,469 | 74,472 | +3 | +0.0040% | +3 | +0.0040% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 108,671 | 108,671 | 108,558 | -113 | -0.1040% | -113 | -0.1040% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 93,947 | 93,947 | 93,950 | +3 | +0.0032% | +3 | +0.0032% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 126,087 | 126,087 | 126,090 | +3 | +0.0024% | +3 | +0.0024% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 56,845 | 56,845 | 56,848 | +3 | +0.0053% | +3 | +0.0053% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 76,499 | 76,499 | 76,504 | +5 | +0.0065% | +5 | +0.0065% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 73,588 | 73,588 | 73,591 | +3 | +0.0041% | +3 | +0.0041% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 74,290 | 74,290 | 74,293 | +3 | +0.0040% | +3 | +0.0040% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 108,581 | 108,581 | 108,483 | -98 | -0.0903% | -98 | -0.0903% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 94,103 | 94,103 | 94,106 | +3 | +0.0032% | +3 | +0.0032% | - |
| `testGas_FillRestAskEmptyBook()` | 149,617 | 149,617 | 149,620 | +3 | +0.0020% | +3 | +0.0020% | - |
| `testGas_FillRestBidEmptyBook()` | 151,242 | 151,242 | 151,245 | +3 | +0.0020% | +3 | +0.0020% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 181,809 | 181,809 | 161,271 | -20,538 | -11.2965% | -20,538 | -11.2965% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 231,434 | 231,434 | 201,632 | -29,802 | -12.8771% | -29,802 | -12.8771% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 242,628 | 242,628 | 210,660 | -31,968 | -13.1757% | -31,968 | -13.1757% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 192,809 | 192,809 | 170,257 | -22,552 | -11.6965% | -22,552 | -11.6965% | - |
| `testGas_LargeRandomBookRestsAsk()` | 250,670 | 250,670 | 199,495 | -51,175 | -20.4153% | -51,175 | -20.4153% | - |
| `testGas_LargeRandomBookRestsBid()` | 247,022 | 247,022 | 215,387 | -31,635 | -12.8066% | -31,635 | -12.8066% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 869,999 | 869,999 | 810,225 | -59,774 | -6.8706% | -59,774 | -6.8706% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,639 | 39,639 | 39,851 | +212 | +0.5348% | +212 | +0.5348% | - |
| `testGas_CancelFilledBidClaim()` | 36,624 | 36,624 | 36,570 | -54 | -0.1474% | -54 | -0.1474% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 852,147 | 852,147 | 754,176 | -97,971 | -11.4970% | -97,971 | -11.4970% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 760,287 | 760,287 | 664,641 | -95,646 | -12.5802% | -95,646 | -12.5802% | - |
| `testGas_CancelPartialBid()` | 48,585 | 48,585 | 48,640 | +55 | +0.1132% | +55 | +0.1132% | - |
| `testGas_CancelUnfilledAsk()` | 39,700 | 39,700 | 39,912 | +212 | +0.5340% | +212 | +0.5340% | - |
| `testGas_CancelUnfilledBid()` | 39,506 | 39,506 | 39,561 | +55 | +0.1392% | +55 | +0.1392% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 358,538 | 358,538 | 355,410 | -3,128 | -0.8724% | -3,128 | -0.8724% | - |
| `testGas_DirtyAskHalfNonceComb()` | 229,863 | 229,863 | 228,250 | -1,613 | -0.7017% | -1,613 | -0.7017% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 91,143 | 91,143 | 91,146 | +3 | +0.0033% | +3 | +0.0033% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 119,735 | 119,735 | 119,334 | -401 | -0.3349% | -401 | -0.3349% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 136,187 | 136,187 | 135,584 | -603 | -0.4428% | -603 | -0.4428% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 360,355 | 360,355 | 357,126 | -3,229 | -0.8961% | -3,229 | -0.8961% | - |
| `testGas_DirtyAskWholeNonceComb()` | 65,273 | 65,273 | 65,276 | +3 | +0.0046% | +3 | +0.0046% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 359,973 | 359,973 | 356,380 | -3,593 | -0.9981% | -3,593 | -0.9981% | - |
| `testGas_DirtyBidHalfNonceComb()` | 229,494 | 229,494 | 227,641 | -1,853 | -0.8074% | -1,853 | -0.8074% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 91,222 | 91,222 | 91,225 | +3 | +0.0033% | +3 | +0.0033% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 119,173 | 119,173 | 118,712 | -461 | -0.3868% | -461 | -0.3868% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 136,845 | 136,845 | 136,152 | -693 | -0.5064% | -693 | -0.5064% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 360,755 | 360,755 | 357,046 | -3,709 | -1.0281% | -3,709 | -1.0281% | - |
| `testGas_DirtyBidWholeNonceComb()` | 64,318 | 64,318 | 64,321 | +3 | +0.0047% | +3 | +0.0047% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 56,148 | 56,148 | 56,151 | +3 | +0.0053% | +3 | +0.0053% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 75,586 | 75,586 | 75,591 | +5 | +0.0066% | +5 | +0.0066% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 74,050 | 74,050 | 74,053 | +3 | +0.0041% | +3 | +0.0041% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 108,252 | 108,252 | 108,139 | -113 | -0.1044% | -113 | -0.1044% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 93,528 | 93,528 | 93,531 | +3 | +0.0032% | +3 | +0.0032% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 125,653 | 125,653 | 125,656 | +3 | +0.0024% | +3 | +0.0024% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 56,411 | 56,411 | 56,414 | +3 | +0.0053% | +3 | +0.0053% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 76,065 | 76,065 | 76,070 | +5 | +0.0066% | +5 | +0.0066% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 73,154 | 73,154 | 73,157 | +3 | +0.0041% | +3 | +0.0041% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 73,856 | 73,856 | 73,859 | +3 | +0.0041% | +3 | +0.0041% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 108,147 | 108,147 | 108,049 | -98 | -0.0906% | -98 | -0.0906% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 93,669 | 93,669 | 93,672 | +3 | +0.0032% | +3 | +0.0032% | - |
| `testGas_FillRestAskEmptyBook()` | 149,455 | 149,455 | 149,458 | +3 | +0.0020% | +3 | +0.0020% | - |
| `testGas_FillRestBidEmptyBook()` | 151,079 | 151,079 | 151,082 | +3 | +0.0020% | +3 | +0.0020% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 181,390 | 181,390 | 160,852 | -20,538 | -11.3226% | -20,538 | -11.3226% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 231,000 | 231,000 | 201,198 | -29,802 | -12.9013% | -29,802 | -12.9013% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 242,194 | 242,194 | 210,226 | -31,968 | -13.1993% | -31,968 | -13.1993% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 192,390 | 192,390 | 169,838 | -22,552 | -11.7220% | -22,552 | -11.7220% | - |
| `testGas_LargeRandomBookRestsAsk()` | 250,508 | 250,508 | 199,333 | -51,175 | -20.4285% | -51,175 | -20.4285% | - |
| `testGas_LargeRandomBookRestsBid()` | 246,859 | 246,859 | 215,224 | -31,635 | -12.8150% | -31,635 | -12.8150% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 844,544 | 844,544 | 784,770 | -59,774 | -7.0777% | -59,774 | -7.0777% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 125,494 | 125,494 | 117,210 | -8,284 | -6.6011% | -8,284 | -6.6011% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 142,580 | 142,580 | 131,666 | -10,914 | -7.6547% | -10,914 | -7.6547% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 225,442 | 225,442 | 220,505 | -4,937 | -2.1899% | -4,937 | -2.1899% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 741,028 | 741,028 | 658,666 | -82,362 | -11.1146% | -82,362 | -11.1146% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 741,490 | 741,490 | 681,103 | -60,387 | -8.1440% | -60,387 | -8.1440% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 844,794 | 844,794 | 772,290 | -72,504 | -8.5824% | -72,504 | -8.5824% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 39,705 | 39,705 | 39,917 | +212 | +0.5339% | +212 | +0.5339% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 36,690 | 36,690 | 36,636 | -54 | -0.1472% | -54 | -0.1472% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 852,169 | 852,169 | 754,198 | -97,971 | -11.4967% | -97,971 | -11.4967% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 760,287 | 760,287 | 664,641 | -95,646 | -12.5802% | -95,646 | -12.5802% | Inherited repeat |
| `testGas_CancelPartialBid()` | 48,651 | 48,651 | 48,706 | +55 | +0.1131% | +55 | +0.1131% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 39,810 | 39,810 | 40,022 | +212 | +0.5325% | +212 | +0.5325% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 39,572 | 39,572 | 39,627 | +55 | +0.1390% | +55 | +0.1390% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 358,595 | 358,595 | 355,467 | -3,128 | -0.8723% | -3,128 | -0.8723% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 229,986 | 229,986 | 228,373 | -1,613 | -0.7013% | -1,613 | -0.7013% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 91,222 | 91,222 | 91,225 | +3 | +0.0033% | +3 | +0.0033% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 119,968 | 119,968 | 119,567 | -401 | -0.3343% | -401 | -0.3343% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 136,266 | 136,266 | 135,663 | -603 | -0.4425% | -603 | -0.4425% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 360,412 | 360,412 | 357,183 | -3,229 | -0.8959% | -3,229 | -0.8959% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 65,396 | 65,396 | 65,399 | +3 | +0.0046% | +3 | +0.0046% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 360,228 | 360,228 | 356,635 | -3,593 | -0.9974% | -3,593 | -0.9974% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 229,573 | 229,573 | 227,720 | -1,853 | -0.8072% | -1,853 | -0.8072% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 91,323 | 91,323 | 91,326 | +3 | +0.0033% | +3 | +0.0033% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 119,296 | 119,296 | 118,835 | -461 | -0.3864% | -461 | -0.3864% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 137,012 | 137,012 | 136,319 | -693 | -0.5058% | -693 | -0.5058% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 360,812 | 360,812 | 357,103 | -3,709 | -1.0280% | -3,709 | -1.0280% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 64,375 | 64,375 | 64,378 | +3 | +0.0047% | +3 | +0.0047% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 56,242 | 56,242 | 56,245 | +3 | +0.0053% | +3 | +0.0053% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 75,680 | 75,680 | 75,685 | +5 | +0.0066% | +5 | +0.0066% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 74,232 | 74,232 | 74,235 | +3 | +0.0040% | +3 | +0.0040% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 108,346 | 108,346 | 108,233 | -113 | -0.1043% | -113 | -0.1043% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 93,666 | 93,666 | 93,669 | +3 | +0.0032% | +3 | +0.0032% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 125,722 | 125,722 | 125,725 | +3 | +0.0024% | +3 | +0.0024% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 56,524 | 56,524 | 56,527 | +3 | +0.0053% | +3 | +0.0053% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 76,178 | 76,178 | 76,183 | +5 | +0.0066% | +5 | +0.0066% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 73,223 | 73,223 | 73,226 | +3 | +0.0041% | +3 | +0.0041% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 73,969 | 73,969 | 73,972 | +3 | +0.0041% | +3 | +0.0041% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 108,216 | 108,216 | 108,118 | -98 | -0.0906% | -98 | -0.0906% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 93,804 | 93,804 | 93,807 | +3 | +0.0032% | +3 | +0.0032% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 149,549 | 149,549 | 149,552 | +3 | +0.0020% | +3 | +0.0020% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 151,214 | 151,214 | 151,217 | +3 | +0.0020% | +3 | +0.0020% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 181,506 | 181,506 | 160,968 | -20,538 | -11.3153% | -20,538 | -11.3153% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 231,135 | 231,135 | 201,333 | -29,802 | -12.8938% | -29,802 | -12.8938% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 242,395 | 242,395 | 210,427 | -31,968 | -13.1884% | -31,968 | -13.1884% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 192,528 | 192,528 | 169,976 | -22,552 | -11.7136% | -22,552 | -11.7136% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 250,580 | 250,580 | 199,405 | -51,175 | -20.4226% | -51,175 | -20.4226% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 246,950 | 246,950 | 215,315 | -31,635 | -12.8103% | -31,635 | -12.8103% | Inherited repeat |
| `testGas_MixedSweep1024()` | 98,278 | 98,278 | 98,283 | +5 | +0.0051% | +5 | +0.0051% | - |
| `testGas_MixedSweep1024AndRest()` | 150,257 | 150,257 | 150,262 | +5 | +0.0033% | +5 | +0.0033% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 350,807 | 350,807 | 350,806 | -1 | -0.0003% | -1 | -0.0003% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 97,550 | 97,550 | 97,555 | +5 | +0.0051% | +5 | +0.0051% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 607,873 | 607,873 | 607,866 | -7 | -0.0012% | -7 | -0.0012% | - |
| `testGas_MixedSweep256()` | 97,962 | 97,962 | 97,967 | +5 | +0.0051% | +5 | +0.0051% | - |
| `testGas_MixedSweep4096()` | 98,838 | 98,838 | 98,843 | +5 | +0.0051% | +5 | +0.0051% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 614,543 | 614,543 | 614,536 | -7 | -0.0011% | -7 | -0.0011% | - |
| `testGas_MixedSweep64()` | 97,262 | 97,262 | 97,267 | +5 | +0.0051% | +5 | +0.0051% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 844,638 | 844,638 | 784,864 | -59,774 | -7.0769% | -59,774 | -7.0769% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 43,428 | 43,428 | 43,634 | +206 | +0.4743% | +206 | +0.4743% | - |
| `testGas_CancelFilledBidClaim()` | 37,121 | 37,121 | 37,073 | -48 | -0.1293% | -48 | -0.1293% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 874,219 | 874,219 | 776,242 | -97,977 | -11.2074% | -97,977 | -11.2074% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 781,502 | 781,502 | 685,850 | -95,652 | -12.2395% | -95,652 | -12.2395% | - |
| `testGas_CancelPartialBid()` | 52,911 | 52,911 | 52,964 | +53 | +0.1002% | +53 | +0.1002% | - |
| `testGas_CancelUnfilledAsk()` | 43,489 | 43,489 | 43,697 | +208 | +0.4783% | +208 | +0.4783% | - |
| `testGas_CancelUnfilledBid()` | 43,832 | 43,832 | 43,885 | +53 | +0.1209% | +53 | +0.1209% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 382,016 | 382,016 | 378,882 | -3,134 | -0.8204% | -3,134 | -0.8204% | - |
| `testGas_DirtyAskHalfNonceComb()` | 280,371 | 280,371 | 278,752 | -1,619 | -0.5774% | -1,619 | -0.5774% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 170,248 | 170,248 | 170,245 | -3 | -0.0018% | -3 | -0.0018% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 130,339 | 130,339 | 129,932 | -407 | -0.3123% | -407 | -0.3123% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 147,583 | 147,583 | 146,974 | -609 | -0.4126% | -609 | -0.4126% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 382,047 | 382,047 | 378,812 | -3,235 | -0.8468% | -3,235 | -0.8468% | - |
| `testGas_DirtyAskWholeNonceComb()` | 144,201 | 144,201 | 144,198 | -3 | -0.0021% | -3 | -0.0021% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 384,429 | 384,429 | 380,830 | -3,599 | -0.9362% | -3,599 | -0.9362% | - |
| `testGas_DirtyBidHalfNonceComb()` | 280,980 | 280,980 | 279,121 | -1,859 | -0.6616% | -1,859 | -0.6616% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 171,305 | 171,305 | 171,302 | -3 | -0.0018% | -3 | -0.0018% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 130,755 | 130,755 | 130,288 | -467 | -0.3572% | -467 | -0.3572% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 149,219 | 149,219 | 148,520 | -699 | -0.4684% | -699 | -0.4684% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 383,425 | 383,425 | 379,710 | -3,715 | -0.9689% | -3,715 | -0.9689% | - |
| `testGas_DirtyBidWholeNonceComb()` | 144,224 | 144,224 | 144,221 | -3 | -0.0021% | -3 | -0.0021% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 72,312 | 72,312 | 72,309 | -3 | -0.0041% | -3 | -0.0041% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 225,704 | 225,704 | 225,703 | -1 | -0.0004% | -1 | -0.0004% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 83,541 | 83,541 | 83,538 | -3 | -0.0036% | -3 | -0.0036% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 122,828 | 122,828 | 122,709 | -119 | -0.0969% | -119 | -0.0969% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 105,212 | 105,212 | 105,209 | -3 | -0.0029% | -3 | -0.0029% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 138,249 | 138,249 | 138,240 | -9 | -0.0065% | -9 | -0.0065% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 71,597 | 71,597 | 71,594 | -3 | -0.0042% | -3 | -0.0042% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 225,326 | 225,326 | 225,325 | -1 | -0.0004% | -1 | -0.0004% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 90,538 | 90,538 | 90,535 | -3 | -0.0033% | -3 | -0.0033% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 82,448 | 82,448 | 82,445 | -3 | -0.0036% | -3 | -0.0036% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 121,745 | 121,745 | 121,641 | -104 | -0.0854% | -104 | -0.0854% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 104,454 | 104,454 | 104,451 | -3 | -0.0029% | -3 | -0.0029% | - |
| `testGas_FillRestAskEmptyBook()` | 140,950 | 140,950 | 140,948 | -2 | -0.0014% | -2 | -0.0014% | - |
| `testGas_FillRestBidEmptyBook()` | 142,574 | 142,574 | 142,572 | -2 | -0.0014% | -2 | -0.0014% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 198,327 | 198,327 | 177,783 | -20,544 | -10.3587% | -20,544 | -10.3587% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 250,178 | 250,178 | 220,370 | -29,808 | -11.9147% | -29,808 | -11.9147% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 255,174 | 255,174 | 223,200 | -31,974 | -12.5303% | -31,974 | -12.5303% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 205,327 | 205,327 | 182,769 | -22,558 | -10.9864% | -22,558 | -10.9864% | - |
| `testGas_LargeRandomBookRestsAsk()` | 285,882 | 285,882 | 234,701 | -51,181 | -17.9028% | -51,181 | -17.9028% | - |
| `testGas_LargeRandomBookRestsBid()` | 269,378 | 269,378 | 245,737 | -23,641 | -8.7761% | -23,641 | -8.7761% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 869,077 | 869,077 | 809,297 | -59,780 | -6.8786% | -59,780 | -6.8786% | - |

<a id="stage-a"></a>

## solc / A / mixed-delta

Status: **intermediate experiment**. Previous stage: `096eab2 (bounded baseline)`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,054 | 127,022 | -32 | -0.0252% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,418 | 101,386 | -32 | -0.0316% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,574 | 101,542 | -32 | -0.0315% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,892 | 117,828 | -64 | -0.0543% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 160,825 | 160,825 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 170,012 | 170,012 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 291,723 | 291,723 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 434,616 | 434,616 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 434,309 | 434,309 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 292,666 | 292,666 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 162,793 | 162,793 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 172,464 | 172,464 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 293,539 | 293,539 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 437,141 | 437,141 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 437,120 | 437,120 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 294,039 | 294,039 | 0 | 0.0000% | 0 | 0.0000% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,044 | 40,044 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,072 | 37,072 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 887,530 | 887,530 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 796,462 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,134 | 49,134 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,283 | 40,283 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,054 | 40,054 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,305 | 368,276 | -29 | -0.0079% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,424 | 261,395 | -29 | -0.0111% | -29 | -0.0111% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,992 | 118,963 | -29 | -0.0244% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,834 | 122,805 | -29 | -0.0236% | -29 | -0.0236% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,750 | 139,721 | -29 | -0.0208% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,950 | 369,921 | -29 | -0.0078% | -29 | -0.0078% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,516 | 92,487 | -29 | -0.0313% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,809 | 369,780 | -29 | -0.0078% | -29 | -0.0078% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,100 | 261,071 | -29 | -0.0111% | -29 | -0.0111% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,116 | 119,087 | -29 | -0.0243% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,328 | 122,299 | -29 | -0.0237% | -29 | -0.0237% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,464 | 140,435 | -29 | -0.0206% | -29 | -0.0206% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,406 | 370,377 | -29 | -0.0078% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,556 | 91,527 | -29 | -0.0317% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,300 | 58,271 | -29 | -0.0497% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,654 | 102,625 | -29 | -0.0283% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,254 | 76,222 | -32 | -0.0420% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,292 | 111,263 | -29 | -0.0261% | -29 | -0.0261% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,905 | 95,873 | -32 | -0.0334% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,604 | 128,572 | -32 | -0.0249% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,572 | 58,543 | -29 | -0.0495% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,063 | 78,034 | -29 | -0.0371% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,315 | 75,286 | -29 | -0.0385% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,845 | 75,813 | -32 | -0.0422% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,146 | 111,117 | -29 | -0.0261% | -29 | -0.0261% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,803 | 95,771 | -32 | -0.0334% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 188,468 | 166,750 | -21,718 | -11.5234% | -21,718 | -11.5234% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 239,371 | 207,825 | -31,546 | -13.1787% | -31,546 | -13.1787% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 251,478 | 217,105 | -34,373 | -13.6684% | -34,373 | -13.6684% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 200,989 | 176,016 | -24,973 | -12.4251% | -24,973 | -12.4251% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 256,955 | 256,678 | -277 | -0.1078% | -277 | -0.1078% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 253,777 | 253,395 | -382 | -0.1505% | -382 | -0.1505% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 902,497 | 834,345 | -68,152 | -7.5515% | -68,152 | -7.5515% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,044 | 40,044 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,072 | 37,072 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 887,530 | 887,530 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 796,462 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,134 | 49,134 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,283 | 40,283 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,054 | 40,054 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,711 | 367,682 | -29 | -0.0079% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,748 | 235,719 | -29 | -0.0123% | -29 | -0.0123% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,316 | 93,287 | -29 | -0.0311% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,240 | 122,211 | -29 | -0.0237% | -29 | -0.0237% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,156 | 139,127 | -29 | -0.0208% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,356 | 369,327 | -29 | -0.0079% | -29 | -0.0079% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,840 | 66,811 | -29 | -0.0434% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,205 | 369,176 | -29 | -0.0079% | -29 | -0.0079% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,410 | 235,381 | -29 | -0.0123% | -29 | -0.0123% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,426 | 93,397 | -29 | -0.0310% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,724 | 121,695 | -29 | -0.0238% | -29 | -0.0238% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,860 | 139,831 | -29 | -0.0207% | -29 | -0.0207% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,802 | 369,773 | -29 | -0.0078% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,866 | 65,837 | -29 | -0.0440% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,696 | 57,667 | -29 | -0.0503% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,964 | 76,935 | -29 | -0.0377% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,650 | 75,618 | -32 | -0.0423% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,688 | 110,659 | -29 | -0.0262% | -29 | -0.0262% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,301 | 95,269 | -32 | -0.0336% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 128,010 | 127,978 | -32 | -0.0250% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,978 | 57,949 | -29 | -0.0500% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,469 | 77,440 | -29 | -0.0374% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,721 | 74,692 | -29 | -0.0388% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,251 | 75,219 | -32 | -0.0425% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,552 | 110,523 | -29 | -0.0262% | -29 | -0.0262% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,209 | 95,177 | -32 | -0.0336% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 187,864 | 166,146 | -21,718 | -11.5605% | -21,718 | -11.5605% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 238,777 | 207,231 | -31,546 | -13.2115% | -31,546 | -13.2115% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 250,884 | 216,511 | -34,373 | -13.7008% | -34,373 | -13.7008% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 200,385 | 175,412 | -24,973 | -12.4625% | -24,973 | -12.4625% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 256,729 | 256,452 | -277 | -0.1079% | -277 | -0.1079% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 253,558 | 253,176 | -382 | -0.1507% | -382 | -0.1507% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 876,807 | 808,655 | -68,152 | -7.7727% | -68,152 | -7.7727% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 133,612 | 133,612 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 153,910 | 136,202 | -17,708 | -11.5054% | -17,708 | -11.5054% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 236,641 | 236,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 770,624 | 770,624 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 772,698 | 702,731 | -69,967 | -9.0549% | -69,967 | -9.0549% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 874,932 | 874,932 | 0 | 0.0000% | 0 | 0.0000% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,110 | 40,110 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,138 | 37,138 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 887,552 | 887,552 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 796,462 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,200 | 49,200 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,393 | 40,393 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,120 | 40,120 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,768 | 367,739 | -29 | -0.0079% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,871 | 235,842 | -29 | -0.0123% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,395 | 93,366 | -29 | -0.0311% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,473 | 122,444 | -29 | -0.0237% | -29 | -0.0237% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,235 | 139,206 | -29 | -0.0208% | -29 | -0.0208% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,413 | 369,384 | -29 | -0.0079% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,963 | 66,934 | -29 | -0.0433% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,460 | 369,431 | -29 | -0.0078% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,489 | 235,460 | -29 | -0.0123% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,527 | 93,498 | -29 | -0.0310% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,847 | 121,818 | -29 | -0.0238% | -29 | -0.0238% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 140,027 | 139,998 | -29 | -0.0207% | -29 | -0.0207% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,859 | 369,830 | -29 | -0.0078% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,923 | 65,894 | -29 | -0.0440% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,790 | 57,761 | -29 | -0.0502% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,058 | 77,029 | -29 | -0.0376% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,832 | 75,800 | -32 | -0.0422% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,782 | 110,753 | -29 | -0.0262% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,439 | 95,407 | -32 | -0.0335% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,079 | 128,047 | -32 | -0.0250% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,091 | 58,062 | -29 | -0.0499% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,582 | 77,553 | -29 | -0.0374% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,790 | 74,761 | -29 | -0.0388% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,364 | 75,332 | -32 | -0.0425% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,621 | 110,592 | -29 | -0.0262% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,344 | 95,312 | -32 | -0.0336% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 187,980 | 166,262 | -21,718 | -11.5534% | -21,718 | -11.5534% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 238,912 | 207,366 | -31,546 | -13.2040% | -31,546 | -13.2040% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 251,085 | 216,712 | -34,373 | -13.6898% | -34,373 | -13.6898% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 200,523 | 175,550 | -24,973 | -12.4539% | -24,973 | -12.4539% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 256,801 | 256,524 | -277 | -0.1079% | -277 | -0.1079% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 253,649 | 253,267 | -382 | -0.1506% | -382 | -0.1506% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,647 | 99,618 | -29 | -0.0291% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,931 | 151,902 | -29 | -0.0191% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 353,017 | 352,988 | -29 | -0.0082% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,919 | 98,890 | -29 | -0.0293% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,611 | 610,582 | -29 | -0.0047% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,331 | 99,302 | -29 | -0.0292% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,207 | 100,178 | -29 | -0.0289% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,341 | 617,312 | -29 | -0.0047% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,631 | 98,602 | -29 | -0.0294% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 876,901 | 808,749 | -68,152 | -7.7719% | -68,152 | -7.7719% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,051 | 44,051 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,789 | 37,789 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 911,245 | 911,245 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 819,318 | 819,318 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelPartialBid()` | 53,890 | 53,890 | 53,890 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,290 | 44,290 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,810 | 44,810 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,029 | 393,000 | -29 | -0.0074% | -29 | -0.0074% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,796 | 287,767 | -29 | -0.0101% | -29 | -0.0101% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,627 | 173,598 | -29 | -0.0167% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,577 | 133,548 | -29 | -0.0217% | -29 | -0.0217% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,365 | 151,336 | -29 | -0.0192% | -29 | -0.0192% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,901 | 392,872 | -29 | -0.0074% | -29 | -0.0074% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,964 | 146,935 | -29 | -0.0197% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,666 | 395,637 | -29 | -0.0073% | -29 | -0.0073% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,601 | 288,572 | -29 | -0.0100% | -29 | -0.0100% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,880 | 174,851 | -29 | -0.0166% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,204 | 134,175 | -29 | -0.0216% | -29 | -0.0216% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,212 | 153,183 | -29 | -0.0189% | -29 | -0.0189% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,490 | 394,461 | -29 | -0.0074% | -29 | -0.0074% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,133 | 147,104 | -29 | -0.0197% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,641 | 74,612 | -29 | -0.0389% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,926 | 228,897 | -29 | -0.0127% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,047 | 86,015 | -32 | -0.0372% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,069 | 126,040 | -29 | -0.0230% | -29 | -0.0230% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,894 | 107,862 | -32 | -0.0297% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,498 | 141,466 | -32 | -0.0226% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,780 | 73,751 | -29 | -0.0393% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,572 | 228,543 | -29 | -0.0127% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,741 | 92,712 | -29 | -0.0313% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,399 | 84,367 | -32 | -0.0379% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,790 | 124,761 | -29 | -0.0232% | -29 | -0.0232% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,553 | 106,521 | -32 | -0.0300% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 206,746 | 185,028 | -21,718 | -10.5047% | -21,718 | -10.5047% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 258,948 | 227,402 | -31,546 | -12.1824% | -31,546 | -12.1824% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 264,837 | 230,464 | -34,373 | -12.9789% | -34,373 | -12.9789% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 215,267 | 190,294 | -24,973 | -11.6009% | -24,973 | -11.6009% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 293,234 | 292,957 | -277 | -0.0945% | -277 | -0.0945% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 278,301 | 277,919 | -382 | -0.1373% | -382 | -0.1373% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 903,202 | 835,050 | -68,152 | -7.5456% | -68,152 | -7.5456% | - |

<a id="stage-b"></a>

## solc / B / shared-cancel

Status: **intermediate experiment**. Previous stage: `mixed-delta`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,022 | 127,022 | 0 | 0.0000% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,386 | 101,386 | 0 | 0.0000% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,542 | 101,542 | 0 | 0.0000% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,828 | 117,828 | 0 | 0.0000% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 160,825 | 160,825 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 170,012 | 170,012 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 291,723 | 291,723 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 434,616 | 434,330 | -286 | -0.0658% | -286 | -0.0658% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 434,309 | 434,023 | -286 | -0.0659% | -286 | -0.0659% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 292,666 | 292,666 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 162,793 | 162,793 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 172,464 | 172,464 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 293,539 | 293,539 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 437,141 | 436,855 | -286 | -0.0654% | -286 | -0.0654% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 437,120 | 436,834 | -286 | -0.0654% | -286 | -0.0654% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 294,039 | 294,039 | 0 | 0.0000% | 0 | 0.0000% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,044 | 40,367 | +323 | +0.8066% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,072 | 37,192 | +120 | +0.3237% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 887,530 | 775,156 | -112,374 | -12.6614% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 685,595 | -110,867 | -13.9199% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,134 | 49,262 | +128 | +0.2605% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,283 | 40,606 | +323 | +0.8018% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,054 | 40,182 | +128 | +0.3196% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,276 | 368,276 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,395 | 261,395 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,805 | 122,805 | 0 | 0.0000% | -29 | -0.0236% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,721 | 139,721 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,921 | 369,921 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,780 | 369,780 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,071 | 261,071 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,299 | 122,299 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,435 | 140,435 | 0 | 0.0000% | -29 | -0.0206% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,377 | 370,377 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,263 | 111,263 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,117 | 111,117 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,750 | 166,912 | +162 | +0.0972% | -21,556 | -11.4375% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 207,825 | 208,068 | +243 | +0.1169% | -31,303 | -13.0772% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,105 | 217,375 | +270 | +0.1244% | -34,103 | -13.5610% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,016 | 176,205 | +189 | +0.1074% | -24,784 | -12.3310% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 256,678 | 256,678 | 0 | 0.0000% | -277 | -0.1078% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 253,395 | 253,395 | 0 | 0.0000% | -382 | -0.1505% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 834,345 | 835,182 | +837 | +0.1003% | -67,315 | -7.4588% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,044 | 40,367 | +323 | +0.8066% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,072 | 37,192 | +120 | +0.3237% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 887,530 | 775,156 | -112,374 | -12.6614% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 685,595 | -110,867 | -13.9199% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,134 | 49,262 | +128 | +0.2605% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,283 | 40,606 | +323 | +0.8018% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,054 | 40,182 | +128 | +0.3196% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,682 | 367,682 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,719 | 235,719 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,211 | 122,211 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,127 | 139,127 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,327 | 369,327 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,176 | 369,176 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,381 | 235,381 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,695 | 121,695 | 0 | 0.0000% | -29 | -0.0238% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,831 | 139,831 | 0 | 0.0000% | -29 | -0.0207% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,773 | 369,773 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,659 | 110,659 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,523 | 110,523 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,146 | 166,308 | +162 | +0.0975% | -21,556 | -11.4743% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,231 | 207,474 | +243 | +0.1173% | -31,303 | -13.1097% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,511 | 216,781 | +270 | +0.1247% | -34,103 | -13.5931% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,412 | 175,601 | +189 | +0.1077% | -24,784 | -12.3682% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 256,452 | 256,452 | 0 | 0.0000% | -277 | -0.1079% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 253,176 | 253,176 | 0 | 0.0000% | -382 | -0.1507% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 808,655 | 809,492 | +837 | +0.1035% | -67,315 | -7.6773% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 133,612 | 120,203 | -13,409 | -10.0358% | -13,409 | -10.0358% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,202 | 136,337 | +135 | +0.0991% | -17,573 | -11.4177% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 236,641 | 236,597 | -44 | -0.0186% | -44 | -0.0186% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 770,624 | 675,740 | -94,884 | -12.3126% | -94,884 | -12.3126% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 702,731 | 703,595 | +864 | +0.1229% | -69,103 | -8.9431% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 874,932 | 874,338 | -594 | -0.0679% | -594 | -0.0679% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,110 | 40,433 | +323 | +0.8053% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,138 | 37,258 | +120 | +0.3231% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 887,552 | 775,178 | -112,374 | -12.6611% | -112,374 | -12.6611% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 796,462 | 685,595 | -110,867 | -13.9199% | -110,867 | -13.9199% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,200 | 49,328 | +128 | +0.2602% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,393 | 40,716 | +323 | +0.7996% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,120 | 40,248 | +128 | +0.3190% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,739 | 367,739 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,842 | 235,842 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,444 | 122,444 | 0 | 0.0000% | -29 | -0.0237% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,206 | 139,206 | 0 | 0.0000% | -29 | -0.0208% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,384 | 369,384 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,431 | 369,431 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,460 | 235,460 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,818 | 121,818 | 0 | 0.0000% | -29 | -0.0238% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,998 | 139,998 | 0 | 0.0000% | -29 | -0.0207% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,830 | 369,830 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,753 | 110,753 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,592 | 110,592 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,262 | 166,424 | +162 | +0.0974% | -21,556 | -11.4672% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,366 | 207,609 | +243 | +0.1172% | -31,303 | -13.1023% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,712 | 216,982 | +270 | +0.1246% | -34,103 | -13.5823% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,550 | 175,739 | +189 | +0.1077% | -24,784 | -12.3597% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 256,524 | 256,524 | 0 | 0.0000% | -277 | -0.1079% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 253,267 | 253,267 | 0 | 0.0000% | -382 | -0.1506% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,618 | 99,618 | 0 | 0.0000% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,902 | 151,902 | 0 | 0.0000% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 352,988 | 352,988 | 0 | 0.0000% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,890 | 98,890 | 0 | 0.0000% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,582 | 610,582 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,302 | 99,302 | 0 | 0.0000% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,178 | 100,178 | 0 | 0.0000% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,312 | 617,312 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,602 | 98,602 | 0 | 0.0000% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 808,749 | 809,586 | +837 | +0.1035% | -67,315 | -7.6765% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,051 | 44,373 | +322 | +0.7310% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,789 | 37,909 | +120 | +0.3176% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 911,245 | 798,870 | -112,375 | -12.3320% | -112,375 | -12.3320% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 819,318 | 708,450 | -110,868 | -13.5317% | -110,868 | -13.5317% | - |
| `testGas_CancelPartialBid()` | 53,890 | 53,890 | 54,017 | +127 | +0.2357% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,290 | 44,612 | +322 | +0.7270% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,810 | 44,937 | +127 | +0.2834% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,000 | 393,000 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,767 | 287,767 | 0 | 0.0000% | -29 | -0.0101% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,548 | 133,548 | 0 | 0.0000% | -29 | -0.0217% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,336 | 151,336 | 0 | 0.0000% | -29 | -0.0192% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,872 | 392,872 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,637 | 395,637 | 0 | 0.0000% | -29 | -0.0073% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,572 | 288,572 | 0 | 0.0000% | -29 | -0.0100% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,175 | 134,175 | 0 | 0.0000% | -29 | -0.0216% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,183 | 153,183 | 0 | 0.0000% | -29 | -0.0189% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,461 | 394,461 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,040 | 126,040 | 0 | 0.0000% | -29 | -0.0230% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,761 | 124,761 | 0 | 0.0000% | -29 | -0.0232% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,028 | 185,190 | +162 | +0.0876% | -21,556 | -10.4263% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,402 | 227,645 | +243 | +0.1069% | -31,303 | -12.0885% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,464 | 230,734 | +270 | +0.1172% | -34,103 | -12.8770% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,294 | 190,483 | +189 | +0.0993% | -24,784 | -11.5131% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 292,957 | 292,957 | 0 | 0.0000% | -277 | -0.0945% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 277,919 | 277,919 | 0 | 0.0000% | -382 | -0.1373% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 835,050 | 835,887 | +837 | +0.1002% | -67,315 | -7.4529% | - |

<a id="stage-c"></a>

## solc / C / early-split

Status: **intermediate experiment**. Previous stage: `shared-cancel`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,022 | 127,022 | 0 | 0.0000% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,386 | 101,386 | 0 | 0.0000% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,542 | 101,542 | 0 | 0.0000% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,828 | 117,828 | 0 | 0.0000% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 160,825 | 162,509 | +1,684 | +1.0471% | +1,684 | +1.0471% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 170,012 | 172,538 | +2,526 | +1.4858% | +2,526 | +1.4858% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 291,723 | 165,906 | -125,817 | -43.1289% | -125,817 | -43.1289% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 434,330 | 445,276 | +10,946 | +2.5202% | +10,660 | +2.4527% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 434,023 | 444,969 | +10,946 | +2.5220% | +10,660 | +2.4545% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 292,666 | 166,849 | -125,817 | -42.9900% | -125,817 | -42.9900% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 162,793 | 164,345 | +1,552 | +0.9534% | +1,552 | +0.9534% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 172,464 | 174,792 | +2,328 | +1.3498% | +2,328 | +1.3498% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 293,539 | 167,710 | -125,829 | -42.8662% | -125,829 | -42.8662% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 436,855 | 446,943 | +10,088 | +2.3092% | +9,802 | +2.2423% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 436,834 | 446,922 | +10,088 | +2.3093% | +9,802 | +2.2424% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 294,039 | 168,210 | -125,829 | -42.7933% | -125,829 | -42.7933% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,276 | 368,276 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,395 | 261,395 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,805 | 122,805 | 0 | 0.0000% | -29 | -0.0236% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,721 | 139,721 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,921 | 369,921 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,780 | 369,780 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,071 | 261,071 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,299 | 122,299 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,435 | 140,435 | 0 | 0.0000% | -29 | -0.0206% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,377 | 370,377 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,263 | 111,263 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,117 | 111,117 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,912 | 166,912 | 0 | 0.0000% | -21,556 | -11.4375% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 208,068 | 208,068 | 0 | 0.0000% | -31,303 | -13.0772% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,375 | 217,375 | 0 | 0.0000% | -34,103 | -13.5610% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,205 | 176,205 | 0 | 0.0000% | -24,784 | -12.3310% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 256,678 | 203,816 | -52,862 | -20.5947% | -53,139 | -20.6803% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 253,395 | 220,693 | -32,702 | -12.9055% | -33,084 | -13.0366% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 835,182 | 835,182 | 0 | 0.0000% | -67,315 | -7.4588% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,682 | 367,682 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,719 | 235,719 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,211 | 122,211 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,127 | 139,127 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,327 | 369,327 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,176 | 369,176 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,381 | 235,381 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,695 | 121,695 | 0 | 0.0000% | -29 | -0.0238% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,831 | 139,831 | 0 | 0.0000% | -29 | -0.0207% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,773 | 369,773 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,659 | 110,659 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,523 | 110,523 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,308 | 166,308 | 0 | 0.0000% | -21,556 | -11.4743% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,474 | 207,474 | 0 | 0.0000% | -31,303 | -13.1097% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,781 | 216,781 | 0 | 0.0000% | -34,103 | -13.5931% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,601 | 175,601 | 0 | 0.0000% | -24,784 | -12.3682% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 256,452 | 203,590 | -52,862 | -20.6128% | -53,139 | -20.6985% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 253,176 | 220,474 | -32,702 | -12.9167% | -33,084 | -13.0479% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 809,492 | 809,492 | 0 | 0.0000% | -67,315 | -7.6773% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 120,203 | 120,203 | 0 | 0.0000% | -13,409 | -10.0358% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,337 | 136,337 | 0 | 0.0000% | -17,573 | -11.4177% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 236,597 | 238,273 | +1,676 | +0.7084% | +1,632 | +0.6897% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 675,740 | 675,740 | 0 | 0.0000% | -94,884 | -12.3126% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 703,595 | 703,595 | 0 | 0.0000% | -69,103 | -8.9431% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 874,338 | 896,282 | +21,944 | +2.5098% | +21,350 | +2.4402% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,433 | 40,433 | 0 | 0.0000% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,258 | 37,258 | 0 | 0.0000% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 775,178 | 775,178 | 0 | 0.0000% | -112,374 | -12.6611% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,328 | 49,328 | 0 | 0.0000% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,716 | 40,716 | 0 | 0.0000% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,248 | 40,248 | 0 | 0.0000% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,739 | 367,739 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,842 | 235,842 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,444 | 122,444 | 0 | 0.0000% | -29 | -0.0237% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,206 | 139,206 | 0 | 0.0000% | -29 | -0.0208% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,384 | 369,384 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,431 | 369,431 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,460 | 235,460 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,818 | 121,818 | 0 | 0.0000% | -29 | -0.0238% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,998 | 139,998 | 0 | 0.0000% | -29 | -0.0207% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,830 | 369,830 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,753 | 110,753 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,592 | 110,592 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,424 | 166,424 | 0 | 0.0000% | -21,556 | -11.4672% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,609 | 207,609 | 0 | 0.0000% | -31,303 | -13.1023% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,982 | 216,982 | 0 | 0.0000% | -34,103 | -13.5823% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,739 | 175,739 | 0 | 0.0000% | -24,784 | -12.3597% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 256,524 | 203,662 | -52,862 | -20.6070% | -53,139 | -20.6927% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 253,267 | 220,565 | -32,702 | -12.9121% | -33,084 | -13.0432% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,618 | 99,618 | 0 | 0.0000% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,902 | 151,902 | 0 | 0.0000% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 352,988 | 352,988 | 0 | 0.0000% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,890 | 98,890 | 0 | 0.0000% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,582 | 610,582 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,302 | 99,302 | 0 | 0.0000% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,178 | 100,178 | 0 | 0.0000% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,312 | 617,312 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,602 | 98,602 | 0 | 0.0000% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 809,586 | 809,586 | 0 | 0.0000% | -67,315 | -7.6765% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,373 | 44,373 | 0 | 0.0000% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,909 | 37,909 | 0 | 0.0000% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 798,870 | 798,870 | 0 | 0.0000% | -112,375 | -12.3320% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 708,450 | 708,450 | 0 | 0.0000% | -110,868 | -13.5317% | - |
| `testGas_CancelPartialBid()` | 53,890 | 54,017 | 54,017 | 0 | 0.0000% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,612 | 44,612 | 0 | 0.0000% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,937 | 44,937 | 0 | 0.0000% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,000 | 393,000 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,767 | 287,767 | 0 | 0.0000% | -29 | -0.0101% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,548 | 133,548 | 0 | 0.0000% | -29 | -0.0217% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,336 | 151,336 | 0 | 0.0000% | -29 | -0.0192% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,872 | 392,872 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,637 | 395,637 | 0 | 0.0000% | -29 | -0.0073% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,572 | 288,572 | 0 | 0.0000% | -29 | -0.0100% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,175 | 134,175 | 0 | 0.0000% | -29 | -0.0216% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,183 | 153,183 | 0 | 0.0000% | -29 | -0.0189% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,461 | 394,461 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,040 | 126,040 | 0 | 0.0000% | -29 | -0.0230% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,761 | 124,761 | 0 | 0.0000% | -29 | -0.0232% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,190 | 185,190 | 0 | 0.0000% | -21,556 | -10.4263% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,645 | 227,645 | 0 | 0.0000% | -31,303 | -12.0885% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,734 | 230,734 | 0 | 0.0000% | -34,103 | -12.8770% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,483 | 190,483 | 0 | 0.0000% | -24,784 | -11.5131% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 292,957 | 240,095 | -52,862 | -18.0443% | -53,139 | -18.1217% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 277,919 | 253,217 | -24,702 | -8.8882% | -25,084 | -9.0133% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 835,887 | 835,887 | 0 | 0.0000% | -67,315 | -7.4529% | - |

<a id="stage-c2"></a>

## solc / C2 / early-split-gated

Status: **intermediate experiment**. Previous stage: `early-split`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,022 | 127,022 | 0 | 0.0000% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,386 | 101,386 | 0 | 0.0000% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,542 | 101,542 | 0 | 0.0000% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,828 | 117,828 | 0 | 0.0000% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 162,509 | 161,041 | -1,468 | -0.9033% | +216 | +0.1343% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 172,538 | 170,336 | -2,202 | -1.2762% | +324 | +0.1906% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 165,906 | 165,979 | +73 | +0.0440% | -125,744 | -43.1039% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 445,276 | 435,734 | -9,542 | -2.1429% | +1,118 | +0.2572% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 444,969 | 435,427 | -9,542 | -2.1444% | +1,118 | +0.2574% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 166,849 | 166,922 | +73 | +0.0438% | -125,744 | -42.9650% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 164,345 | 163,009 | -1,336 | -0.8129% | +216 | +0.1327% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 174,792 | 172,788 | -2,004 | -1.1465% | +324 | +0.1879% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 167,710 | 167,783 | +73 | +0.0435% | -125,756 | -42.8413% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 446,943 | 438,259 | -8,684 | -1.9430% | +1,118 | +0.2558% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 446,922 | 438,238 | -8,684 | -1.9431% | +1,118 | +0.2558% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 168,210 | 168,283 | +73 | +0.0434% | -125,756 | -42.7685% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,276 | 368,276 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,395 | 261,395 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,805 | 122,805 | 0 | 0.0000% | -29 | -0.0236% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,721 | 139,721 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,921 | 369,921 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,780 | 369,780 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,071 | 261,071 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,299 | 122,299 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,435 | 140,435 | 0 | 0.0000% | -29 | -0.0206% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,377 | 370,377 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,263 | 111,263 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,117 | 111,117 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,912 | 166,912 | 0 | 0.0000% | -21,556 | -11.4375% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 208,068 | 208,068 | 0 | 0.0000% | -31,303 | -13.0772% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,375 | 217,375 | 0 | 0.0000% | -34,103 | -13.5610% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,205 | 176,205 | 0 | 0.0000% | -24,784 | -12.3310% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 203,816 | 203,889 | +73 | +0.0358% | -53,066 | -20.6519% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 220,693 | 220,766 | +73 | +0.0331% | -33,011 | -13.0079% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 835,182 | 835,182 | 0 | 0.0000% | -67,315 | -7.4588% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,682 | 367,682 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,719 | 235,719 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,211 | 122,211 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,127 | 139,127 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,327 | 369,327 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,176 | 369,176 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,381 | 235,381 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,695 | 121,695 | 0 | 0.0000% | -29 | -0.0238% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,831 | 139,831 | 0 | 0.0000% | -29 | -0.0207% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,773 | 369,773 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,659 | 110,659 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,523 | 110,523 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,308 | 166,308 | 0 | 0.0000% | -21,556 | -11.4743% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,474 | 207,474 | 0 | 0.0000% | -31,303 | -13.1097% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,781 | 216,781 | 0 | 0.0000% | -34,103 | -13.5931% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,601 | 175,601 | 0 | 0.0000% | -24,784 | -12.3682% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 203,590 | 203,663 | +73 | +0.0359% | -53,066 | -20.6700% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 220,474 | 220,547 | +73 | +0.0331% | -33,011 | -13.0191% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 809,492 | 809,492 | 0 | 0.0000% | -67,315 | -7.6773% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 120,203 | 120,203 | 0 | 0.0000% | -13,409 | -10.0358% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,337 | 136,337 | 0 | 0.0000% | -17,573 | -11.4177% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 238,273 | 238,613 | +340 | +0.1427% | +1,972 | +0.8333% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 675,740 | 675,740 | 0 | 0.0000% | -94,884 | -12.3126% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 703,595 | 703,595 | 0 | 0.0000% | -69,103 | -8.9431% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 896,282 | 891,654 | -4,628 | -0.5164% | +16,722 | +1.9112% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,433 | 40,433 | 0 | 0.0000% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,258 | 37,258 | 0 | 0.0000% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 775,178 | 775,178 | 0 | 0.0000% | -112,374 | -12.6611% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,328 | 49,328 | 0 | 0.0000% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,716 | 40,716 | 0 | 0.0000% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,248 | 40,248 | 0 | 0.0000% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,739 | 367,739 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,842 | 235,842 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,444 | 122,444 | 0 | 0.0000% | -29 | -0.0237% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,206 | 139,206 | 0 | 0.0000% | -29 | -0.0208% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,384 | 369,384 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,431 | 369,431 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,460 | 235,460 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,818 | 121,818 | 0 | 0.0000% | -29 | -0.0238% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,998 | 139,998 | 0 | 0.0000% | -29 | -0.0207% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,830 | 369,830 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,753 | 110,753 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,592 | 110,592 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,424 | 166,424 | 0 | 0.0000% | -21,556 | -11.4672% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,609 | 207,609 | 0 | 0.0000% | -31,303 | -13.1023% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,982 | 216,982 | 0 | 0.0000% | -34,103 | -13.5823% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,739 | 175,739 | 0 | 0.0000% | -24,784 | -12.3597% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 203,662 | 203,735 | +73 | +0.0358% | -53,066 | -20.6642% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 220,565 | 220,638 | +73 | +0.0331% | -33,011 | -13.0144% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,618 | 99,618 | 0 | 0.0000% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,902 | 151,902 | 0 | 0.0000% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 352,988 | 352,988 | 0 | 0.0000% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,890 | 98,890 | 0 | 0.0000% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,582 | 610,582 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,302 | 99,302 | 0 | 0.0000% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,178 | 100,178 | 0 | 0.0000% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,312 | 617,312 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,602 | 98,602 | 0 | 0.0000% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 809,586 | 809,586 | 0 | 0.0000% | -67,315 | -7.6765% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,373 | 44,373 | 0 | 0.0000% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,909 | 37,909 | 0 | 0.0000% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 798,870 | 798,870 | 0 | 0.0000% | -112,375 | -12.3320% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 708,450 | 708,450 | 0 | 0.0000% | -110,868 | -13.5317% | - |
| `testGas_CancelPartialBid()` | 53,890 | 54,017 | 54,017 | 0 | 0.0000% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,612 | 44,612 | 0 | 0.0000% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,937 | 44,937 | 0 | 0.0000% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,000 | 393,000 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,767 | 287,767 | 0 | 0.0000% | -29 | -0.0101% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,548 | 133,548 | 0 | 0.0000% | -29 | -0.0217% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,336 | 151,336 | 0 | 0.0000% | -29 | -0.0192% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,872 | 392,872 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,637 | 395,637 | 0 | 0.0000% | -29 | -0.0073% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,572 | 288,572 | 0 | 0.0000% | -29 | -0.0100% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,175 | 134,175 | 0 | 0.0000% | -29 | -0.0216% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,183 | 153,183 | 0 | 0.0000% | -29 | -0.0189% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,461 | 394,461 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,040 | 126,040 | 0 | 0.0000% | -29 | -0.0230% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,761 | 124,761 | 0 | 0.0000% | -29 | -0.0232% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,190 | 185,190 | 0 | 0.0000% | -21,556 | -10.4263% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,645 | 227,645 | 0 | 0.0000% | -31,303 | -12.0885% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,734 | 230,734 | 0 | 0.0000% | -34,103 | -12.8770% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,483 | 190,483 | 0 | 0.0000% | -24,784 | -11.5131% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 240,095 | 240,168 | +73 | +0.0304% | -53,066 | -18.0968% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 253,217 | 253,290 | +73 | +0.0288% | -25,011 | -8.9870% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 835,887 | 835,887 | 0 | 0.0000% | -67,315 | -7.4529% | - |

<a id="stage-d"></a>

## solc / D / insert-delta

Status: **intermediate experiment**. Previous stage: `early-split-gated`. Baseline: `096eab2`.

All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.

### Integrator Fees And Routing

Contract: `DeepstateV1IntegratorFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_IntegratorAndProtocolFeeFill()` | 127,054 | 127,022 | 127,022 | 0 | 0.0000% | -32 | -0.0252% | - |
| `testGas_IntegratorFillAskFullyMatchesSingleBid()` | 101,418 | 101,386 | 101,386 | 0 | 0.0000% | -32 | -0.0316% | - |
| `testGas_IntegratorFillBidFullyMatchesSingleAsk()` | 101,574 | 101,542 | 101,542 | 0 | 0.0000% | -32 | -0.0315% | - |
| `testGas_IntegratorFillRestBidEmptyBook()` | 151,826 | 151,826 | 151,826 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_IntegratorRouteNetsRepeatedFeeToken()` | 117,892 | 117,828 | 117,828 | 0 | 0.0000% | -64 | -0.0543% | - |

### Insertion Diagnostics

Contract: `OpportunityGasProbe`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testOpportunity_RestAsk16Orders()` | 160,825 | 161,041 | 161,247 | +206 | +0.1279% | +422 | +0.2624% | - |
| `testOpportunity_RestAsk64Orders()` | 170,012 | 170,336 | 170,558 | +222 | +0.1303% | +546 | +0.3212% | - |
| `testOpportunity_RestAskDifferentTickLeftNonceComb()` | 291,723 | 165,979 | 166,107 | +128 | +0.0771% | -125,616 | -43.0600% | - |
| `testOpportunity_RestAskDirtyLeftNonceComb()` | 434,616 | 435,734 | 386,058 | -49,676 | -11.4005% | -48,558 | -11.1726% | - |
| `testOpportunity_RestAskLeftNonceComb()` | 434,309 | 435,427 | 385,751 | -49,676 | -11.4086% | -48,558 | -11.1805% | - |
| `testOpportunity_RestAskWorseTickLeftNonceComb()` | 292,666 | 166,922 | 167,049 | +127 | +0.0761% | -125,617 | -42.9216% | - |
| `testOpportunity_RestBid16Orders()` | 162,793 | 163,009 | 163,215 | +206 | +0.1264% | +422 | +0.2592% | - |
| `testOpportunity_RestBid64Orders()` | 172,464 | 172,788 | 173,010 | +222 | +0.1285% | +546 | +0.3166% | - |
| `testOpportunity_RestBidDifferentTickLeftNonceComb()` | 293,539 | 167,783 | 167,923 | +140 | +0.0834% | -125,616 | -42.7936% | - |
| `testOpportunity_RestBidDirtyLeftNonceComb()` | 437,141 | 438,259 | 388,388 | -49,871 | -11.3793% | -48,753 | -11.1527% | - |
| `testOpportunity_RestBidLeftNonceComb()` | 437,120 | 438,238 | 388,367 | -49,871 | -11.3799% | -48,753 | -11.1532% | - |
| `testOpportunity_RestBidWorseTickLeftNonceComb()` | 294,039 | 168,283 | 168,422 | +139 | +0.0826% | -125,617 | -42.7212% | - |

### ERC20 With Protocol Fee

Contract: `RadixMatchingEngineFeeGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 368,276 | 368,276 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 261,395 | 261,395 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,805 | 122,805 | 0 | 0.0000% | -29 | -0.0236% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 139,721 | 139,721 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 369,921 | 369,921 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 369,780 | 369,780 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 261,071 | 261,071 | 0 | 0.0000% | -29 | -0.0111% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 122,299 | 122,299 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 140,435 | 140,435 | 0 | 0.0000% | -29 | -0.0206% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 370,377 | 370,377 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,263 | 111,263 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 111,117 | 111,117 | 0 | 0.0000% | -29 | -0.0261% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,912 | 166,912 | 0 | 0.0000% | -21,556 | -11.4375% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 208,068 | 208,068 | 0 | 0.0000% | -31,303 | -13.0772% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,375 | 217,375 | 0 | 0.0000% | -34,103 | -13.5610% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,205 | 176,205 | 0 | 0.0000% | -24,784 | -12.3310% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 203,889 | 204,017 | +128 | +0.0628% | -52,938 | -20.6021% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 220,766 | 220,906 | +140 | +0.0634% | -32,871 | -12.9527% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 835,182 | 835,182 | 0 | 0.0000% | -67,315 | -7.4588% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 775,156 | 0 | 0.0000% | -112,374 | -12.6614% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 367,682 | 367,682 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 235,719 | 235,719 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 122,211 | 122,211 | 0 | 0.0000% | -29 | -0.0237% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 139,127 | 139,127 | 0 | 0.0000% | -29 | -0.0208% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 369,327 | 369,327 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 369,176 | 369,176 | 0 | 0.0000% | -29 | -0.0079% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 235,381 | 235,381 | 0 | 0.0000% | -29 | -0.0123% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,695 | 121,695 | 0 | 0.0000% | -29 | -0.0238% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 139,831 | 139,831 | 0 | 0.0000% | -29 | -0.0207% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 369,773 | 369,773 | 0 | 0.0000% | -29 | -0.0078% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,659 | 110,659 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,523 | 110,523 | 0 | 0.0000% | -29 | -0.0262% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,308 | 166,308 | 0 | 0.0000% | -21,556 | -11.4743% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,474 | 207,474 | 0 | 0.0000% | -31,303 | -13.1097% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,781 | 216,781 | 0 | 0.0000% | -34,103 | -13.5931% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,601 | 175,601 | 0 | 0.0000% | -24,784 | -12.3682% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 203,663 | 203,791 | +128 | +0.0628% | -52,938 | -20.6202% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 220,547 | 220,687 | +140 | +0.0635% | -32,871 | -12.9639% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 809,492 | 809,492 | 0 | 0.0000% | -67,315 | -7.6773% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 120,203 | 120,203 | 0 | 0.0000% | -13,409 | -10.0358% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,337 | 136,337 | 0 | 0.0000% | -17,573 | -11.4177% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 238,613 | 228,965 | -9,648 | -4.0434% | -7,676 | -3.2437% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 675,740 | 675,740 | 0 | 0.0000% | -94,884 | -12.3126% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 703,595 | 703,595 | 0 | 0.0000% | -69,103 | -8.9431% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 891,654 | 791,805 | -99,849 | -11.1982% | -83,127 | -9.5010% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,433 | 40,433 | 0 | 0.0000% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,258 | 37,258 | 0 | 0.0000% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 775,178 | 775,178 | 0 | 0.0000% | -112,374 | -12.6611% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 685,595 | 0 | 0.0000% | -110,867 | -13.9199% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,328 | 49,328 | 0 | 0.0000% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,716 | 40,716 | 0 | 0.0000% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,248 | 40,248 | 0 | 0.0000% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 367,739 | 367,739 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 235,842 | 235,842 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 122,444 | 122,444 | 0 | 0.0000% | -29 | -0.0237% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 139,206 | 139,206 | 0 | 0.0000% | -29 | -0.0208% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 369,384 | 369,384 | 0 | 0.0000% | -29 | -0.0079% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 369,431 | 369,431 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 235,460 | 235,460 | 0 | 0.0000% | -29 | -0.0123% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,818 | 121,818 | 0 | 0.0000% | -29 | -0.0238% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,998 | 139,998 | 0 | 0.0000% | -29 | -0.0207% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 369,830 | 369,830 | 0 | 0.0000% | -29 | -0.0078% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,753 | 110,753 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,592 | 110,592 | 0 | 0.0000% | -29 | -0.0262% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,424 | 166,424 | 0 | 0.0000% | -21,556 | -11.4672% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,609 | 207,609 | 0 | 0.0000% | -31,303 | -13.1023% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,982 | 216,982 | 0 | 0.0000% | -34,103 | -13.5823% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,739 | 175,739 | 0 | 0.0000% | -24,784 | -12.3597% | Inherited repeat |
| `testGas_LargeRandomBookRestsAsk()` | 256,801 | 203,735 | 203,863 | +128 | +0.0628% | -52,938 | -20.6144% | Inherited repeat |
| `testGas_LargeRandomBookRestsBid()` | 253,649 | 220,638 | 220,778 | +140 | +0.0635% | -32,871 | -12.9592% | Inherited repeat |
| `testGas_MixedSweep1024()` | 99,647 | 99,618 | 99,618 | 0 | 0.0000% | -29 | -0.0291% | - |
| `testGas_MixedSweep1024AndRest()` | 151,931 | 151,902 | 151,902 | 0 | 0.0000% | -29 | -0.0191% | - |
| `testGas_MixedSweep1024BurningHookAndFees()` | 353,017 | 352,988 | 352,988 | 0 | 0.0000% | -29 | -0.0082% | - |
| `testGas_MixedSweep1024FitsOneMillionGas()` | 98,919 | 98,890 | 98,890 | 0 | 0.0000% | -29 | -0.0293% | Capped-gas check; baseline and candidate succeed |
| `testGas_MixedSweep1024RestBurningHooksAndFees()` | 610,611 | 610,582 | 610,582 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep256()` | 99,331 | 99,302 | 99,302 | 0 | 0.0000% | -29 | -0.0292% | - |
| `testGas_MixedSweep4096()` | 100,207 | 100,178 | 100,178 | 0 | 0.0000% | -29 | -0.0289% | - |
| `testGas_MixedSweep4096RestBurningHooksAndFees()` | 617,341 | 617,312 | 617,312 | 0 | 0.0000% | -29 | -0.0047% | - |
| `testGas_MixedSweep64()` | 98,631 | 98,602 | 98,602 | 0 | 0.0000% | -29 | -0.0294% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 809,586 | 809,586 | 0 | 0.0000% | -67,315 | -7.6765% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,373 | 44,373 | 0 | 0.0000% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,909 | 37,909 | 0 | 0.0000% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 798,870 | 798,870 | 0 | 0.0000% | -112,375 | -12.3320% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 708,450 | 708,450 | 0 | 0.0000% | -110,868 | -13.5317% | - |
| `testGas_CancelPartialBid()` | 53,890 | 54,017 | 54,017 | 0 | 0.0000% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,612 | 44,612 | 0 | 0.0000% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,937 | 44,937 | 0 | 0.0000% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 393,000 | 393,000 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 287,767 | 287,767 | 0 | 0.0000% | -29 | -0.0101% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 133,548 | 133,548 | 0 | 0.0000% | -29 | -0.0217% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 151,336 | 151,336 | 0 | 0.0000% | -29 | -0.0192% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 392,872 | 392,872 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 395,637 | 395,637 | 0 | 0.0000% | -29 | -0.0073% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 288,572 | 288,572 | 0 | 0.0000% | -29 | -0.0100% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 134,175 | 134,175 | 0 | 0.0000% | -29 | -0.0216% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 153,183 | 153,183 | 0 | 0.0000% | -29 | -0.0189% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 394,461 | 394,461 | 0 | 0.0000% | -29 | -0.0074% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 126,040 | 126,040 | 0 | 0.0000% | -29 | -0.0230% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,761 | 124,761 | 0 | 0.0000% | -29 | -0.0232% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,190 | 185,190 | 0 | 0.0000% | -21,556 | -10.4263% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,645 | 227,645 | 0 | 0.0000% | -31,303 | -12.0885% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,734 | 230,734 | 0 | 0.0000% | -34,103 | -12.8770% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,483 | 190,483 | 0 | 0.0000% | -24,784 | -11.5131% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 240,168 | 240,296 | +128 | +0.0533% | -52,938 | -18.0532% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 253,290 | 253,430 | +140 | +0.0553% | -24,871 | -8.9367% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 835,887 | 835,887 | 0 | 0.0000% | -67,315 | -7.4529% | - |
