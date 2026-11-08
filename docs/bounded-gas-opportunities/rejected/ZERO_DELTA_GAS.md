# Archived Zero-Delta Gas Table

**Rejected experiment, not a selected implementation candidate.** Its records are retained for a complete audit trail. The selected E patch does not contain this guard.

<a id="rejected-zero-delta"></a>

## solc / F / zero-delta

Status: **rejected; historical measurements only**. Previous stage: `uniform-difference`. Baseline: `096eab2`.

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
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 776,596 | +1,440 | +0.1858% | -110,934 | -12.4992% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 611,387 | -74,208 | -10.8239% | -185,075 | -23.2371% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 368,305 | 363,099 | 363,099 | 0 | 0.0000% | -5,206 | -1.4135% | - |
| `testGas_DirtyAskHalfNonceComb()` | 261,424 | 258,723 | 258,723 | 0 | 0.0000% | -2,701 | -1.0332% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 118,992 | 118,963 | 118,963 | 0 | 0.0000% | -29 | -0.0244% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,834 | 122,137 | 122,137 | 0 | 0.0000% | -697 | -0.5674% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,750 | 138,719 | 138,719 | 0 | 0.0000% | -1,031 | -0.7377% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,950 | 364,577 | 364,577 | 0 | 0.0000% | -5,373 | -1.4524% | - |
| `testGas_DirtyAskWholeNonceComb()` | 92,516 | 92,487 | 92,487 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,809 | 365,006 | 365,006 | 0 | 0.0000% | -4,803 | -1.2988% | - |
| `testGas_DirtyBidHalfNonceComb()` | 261,100 | 258,607 | 258,607 | 0 | 0.0000% | -2,493 | -0.9548% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 119,116 | 119,087 | 119,087 | 0 | 0.0000% | -29 | -0.0243% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 122,328 | 121,683 | 121,683 | 0 | 0.0000% | -645 | -0.5273% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 140,464 | 139,511 | 139,511 | 0 | 0.0000% | -953 | -0.6785% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 370,406 | 365,449 | 365,449 | 0 | 0.0000% | -4,957 | -1.3383% | - |
| `testGas_DirtyBidWholeNonceComb()` | 91,556 | 91,527 | 91,527 | 0 | 0.0000% | -29 | -0.0317% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 58,300 | 58,271 | 58,271 | 0 | 0.0000% | -29 | -0.0497% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 102,654 | 102,625 | 102,625 | 0 | 0.0000% | -29 | -0.0283% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 76,254 | 76,222 | 76,222 | 0 | 0.0000% | -32 | -0.0420% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 111,292 | 111,109 | 111,109 | 0 | 0.0000% | -183 | -0.1644% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,905 | 95,873 | 95,873 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,604 | 128,572 | 128,572 | 0 | 0.0000% | -32 | -0.0249% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,572 | 58,543 | 58,543 | 0 | 0.0000% | -29 | -0.0495% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 78,063 | 78,034 | 78,034 | 0 | 0.0000% | -29 | -0.0371% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 75,315 | 75,286 | 75,286 | 0 | 0.0000% | -29 | -0.0385% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,845 | 75,813 | 75,813 | 0 | 0.0000% | -32 | -0.0422% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 111,146 | 110,950 | 110,950 | 0 | 0.0000% | -196 | -0.1763% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,803 | 95,771 | 95,771 | 0 | 0.0000% | -32 | -0.0334% | - |
| `testGas_FillRestAskEmptyBook()` | 151,137 | 151,137 | 151,137 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 153,013 | 153,013 | 153,013 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 188,468 | 166,912 | 167,179 | +267 | +0.1600% | -21,289 | -11.2958% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 239,371 | 208,068 | 208,470 | +402 | +0.1932% | -30,901 | -12.9092% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,478 | 217,375 | 217,825 | +450 | +0.2070% | -33,653 | -13.3821% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,989 | 176,205 | 176,520 | +315 | +0.1788% | -24,469 | -12.1743% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,955 | 204,017 | 204,017 | 0 | 0.0000% | -52,938 | -20.6021% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,777 | 220,906 | 220,906 | 0 | 0.0000% | -32,871 | -12.9527% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 902,497 | 832,910 | 834,302 | +1,392 | +0.1671% | -68,195 | -7.5563% | - |

### ERC20 Without Hooks

Contract: `RadixMatchingEngineGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,044 | 40,367 | 40,367 | 0 | 0.0000% | +323 | +0.8066% | - |
| `testGas_CancelFilledBidClaim()` | 37,072 | 37,192 | 37,192 | 0 | 0.0000% | +120 | +0.3237% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,530 | 775,156 | 776,596 | +1,440 | +0.1858% | -110,934 | -12.4992% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 611,387 | -74,208 | -10.8239% | -185,075 | -23.2371% | - |
| `testGas_CancelPartialBid()` | 49,134 | 49,262 | 49,262 | 0 | 0.0000% | +128 | +0.2605% | - |
| `testGas_CancelUnfilledAsk()` | 40,283 | 40,606 | 40,606 | 0 | 0.0000% | +323 | +0.8018% | - |
| `testGas_CancelUnfilledBid()` | 40,054 | 40,182 | 40,182 | 0 | 0.0000% | +128 | +0.3196% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,711 | 362,505 | 362,505 | 0 | 0.0000% | -5,206 | -1.4158% | - |
| `testGas_DirtyAskHalfNonceComb()` | 235,748 | 233,047 | 233,047 | 0 | 0.0000% | -2,701 | -1.1457% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,316 | 93,287 | 93,287 | 0 | 0.0000% | -29 | -0.0311% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 122,240 | 121,543 | 121,543 | 0 | 0.0000% | -697 | -0.5702% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 139,156 | 138,125 | 138,125 | 0 | 0.0000% | -1,031 | -0.7409% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,356 | 363,983 | 363,983 | 0 | 0.0000% | -5,373 | -1.4547% | - |
| `testGas_DirtyAskWholeNonceComb()` | 66,840 | 66,811 | 66,811 | 0 | 0.0000% | -29 | -0.0434% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,205 | 364,402 | 364,402 | 0 | 0.0000% | -4,803 | -1.3009% | - |
| `testGas_DirtyBidHalfNonceComb()` | 235,410 | 232,917 | 232,917 | 0 | 0.0000% | -2,493 | -1.0590% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,426 | 93,397 | 93,397 | 0 | 0.0000% | -29 | -0.0310% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 121,724 | 121,079 | 121,079 | 0 | 0.0000% | -645 | -0.5299% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 139,860 | 138,907 | 138,907 | 0 | 0.0000% | -953 | -0.6814% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,802 | 364,845 | 364,845 | 0 | 0.0000% | -4,957 | -1.3404% | - |
| `testGas_DirtyBidWholeNonceComb()` | 65,866 | 65,837 | 65,837 | 0 | 0.0000% | -29 | -0.0440% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,696 | 57,667 | 57,667 | 0 | 0.0000% | -29 | -0.0503% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 76,964 | 76,935 | 76,935 | 0 | 0.0000% | -29 | -0.0377% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,650 | 75,618 | 75,618 | 0 | 0.0000% | -32 | -0.0423% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,688 | 110,505 | 110,505 | 0 | 0.0000% | -183 | -0.1653% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,301 | 95,269 | 95,269 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,010 | 127,978 | 127,978 | 0 | 0.0000% | -32 | -0.0250% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 57,978 | 57,949 | 57,949 | 0 | 0.0000% | -29 | -0.0500% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,469 | 77,440 | 77,440 | 0 | 0.0000% | -29 | -0.0374% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,721 | 74,692 | 74,692 | 0 | 0.0000% | -29 | -0.0388% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,251 | 75,219 | 75,219 | 0 | 0.0000% | -32 | -0.0425% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,552 | 110,356 | 110,356 | 0 | 0.0000% | -196 | -0.1773% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,209 | 95,177 | 95,177 | 0 | 0.0000% | -32 | -0.0336% | - |
| `testGas_FillRestAskEmptyBook()` | 150,911 | 150,911 | 150,911 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 152,794 | 152,794 | 152,794 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,864 | 166,308 | 166,575 | +267 | +0.1605% | -21,289 | -11.3321% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,777 | 207,474 | 207,876 | +402 | +0.1938% | -30,901 | -12.9414% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 250,884 | 216,781 | 217,231 | +450 | +0.2076% | -33,653 | -13.4138% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,385 | 175,601 | 175,916 | +315 | +0.1794% | -24,469 | -12.2110% | - |
| `testGas_LargeRandomBookRestsAsk()` | 256,729 | 203,791 | 203,791 | 0 | 0.0000% | -52,938 | -20.6202% | - |
| `testGas_LargeRandomBookRestsBid()` | 253,558 | 220,687 | 220,687 | 0 | 0.0000% | -32,871 | -12.9639% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,807 | 807,220 | 808,612 | +1,392 | +0.1724% | -68,195 | -7.7777% | - |

### Native ETH Histories

Contract: `RadixMatchingEngineGasTestNativeDirtySpine`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_ObservedNativeBidCancelAfterThreePartialMatches()` | 133,612 | 120,203 | 120,383 | +180 | +0.1497% | -13,229 | -9.9011% | - |
| `testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest()` | 153,910 | 136,337 | 136,562 | +225 | +0.1650% | -17,348 | -11.2715% | - |
| `testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine()` | 236,641 | 228,965 | 229,097 | +132 | +0.0577% | -7,544 | -3.1880% | - |
| `testGas_PathologicalNativeBidCancelAfterThreePartialMatches()` | 770,624 | 675,740 | 677,180 | +1,440 | +0.2131% | -93,444 | -12.1258% | - |
| `testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest()` | 772,698 | 702,104 | 703,544 | +1,440 | +0.2051% | -69,154 | -8.9497% | - |
| `testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine()` | 874,932 | 791,805 | 792,861 | +1,056 | +0.1334% | -82,071 | -9.3803% | - |

### Wide Sweeps And Inherited Repeats

Contract: `RadixMatchingEngineGasTestWideSweep`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 40,110 | 40,433 | 40,433 | 0 | 0.0000% | +323 | +0.8053% | Inherited repeat |
| `testGas_CancelFilledBidClaim()` | 37,138 | 37,258 | 37,258 | 0 | 0.0000% | +120 | +0.3231% | Inherited repeat |
| `testGas_CancelFullDepthBidCombRightmost()` | 887,552 | 775,178 | 776,618 | +1,440 | +0.1858% | -110,934 | -12.4989% | Inherited repeat |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 796,462 | 685,595 | 611,387 | -74,208 | -10.8239% | -185,075 | -23.2371% | Inherited repeat |
| `testGas_CancelPartialBid()` | 49,200 | 49,328 | 49,328 | 0 | 0.0000% | +128 | +0.2602% | Inherited repeat |
| `testGas_CancelUnfilledAsk()` | 40,393 | 40,716 | 40,716 | 0 | 0.0000% | +323 | +0.7996% | Inherited repeat |
| `testGas_CancelUnfilledBid()` | 40,120 | 40,248 | 40,248 | 0 | 0.0000% | +128 | +0.3190% | Inherited repeat |
| `testGas_DirtyAskCrossLeafNonceComb()` | 367,768 | 362,562 | 362,562 | 0 | 0.0000% | -5,206 | -1.4156% | Inherited repeat |
| `testGas_DirtyAskHalfNonceComb()` | 235,871 | 233,170 | 233,170 | 0 | 0.0000% | -2,701 | -1.1451% | Inherited repeat |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 93,395 | 93,366 | 93,366 | 0 | 0.0000% | -29 | -0.0311% | Inherited repeat |
| `testGas_DirtyAskSmallFill16Orders()` | 122,473 | 121,776 | 121,776 | 0 | 0.0000% | -697 | -0.5691% | Inherited repeat |
| `testGas_DirtyAskSmallFill64Orders()` | 139,235 | 138,204 | 138,204 | 0 | 0.0000% | -1,031 | -0.7405% | Inherited repeat |
| `testGas_DirtyAskSmallFillNonceComb()` | 369,413 | 364,040 | 364,040 | 0 | 0.0000% | -5,373 | -1.4545% | Inherited repeat |
| `testGas_DirtyAskWholeNonceComb()` | 66,963 | 66,934 | 66,934 | 0 | 0.0000% | -29 | -0.0433% | Inherited repeat |
| `testGas_DirtyBidCrossLeafNonceComb()` | 369,460 | 364,657 | 364,657 | 0 | 0.0000% | -4,803 | -1.3000% | Inherited repeat |
| `testGas_DirtyBidHalfNonceComb()` | 235,489 | 232,996 | 232,996 | 0 | 0.0000% | -2,493 | -1.0586% | Inherited repeat |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 93,527 | 93,498 | 93,498 | 0 | 0.0000% | -29 | -0.0310% | Inherited repeat |
| `testGas_DirtyBidSmallFill16Orders()` | 121,847 | 121,202 | 121,202 | 0 | 0.0000% | -645 | -0.5294% | Inherited repeat |
| `testGas_DirtyBidSmallFill64Orders()` | 140,027 | 139,074 | 139,074 | 0 | 0.0000% | -953 | -0.6806% | Inherited repeat |
| `testGas_DirtyBidSmallFillNonceComb()` | 369,859 | 364,902 | 364,902 | 0 | 0.0000% | -4,957 | -1.3402% | Inherited repeat |
| `testGas_DirtyBidWholeNonceComb()` | 65,923 | 65,894 | 65,894 | 0 | 0.0000% | -29 | -0.0440% | Inherited repeat |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 57,790 | 57,761 | 57,761 | 0 | 0.0000% | -29 | -0.0502% | Inherited repeat |
| `testGas_FillAskConsumesFullDepthBidComb()` | 77,058 | 77,029 | 77,029 | 0 | 0.0000% | -29 | -0.0376% | Inherited repeat |
| `testGas_FillAskFullyMatchesSingleBid()` | 75,832 | 75,800 | 75,800 | 0 | 0.0000% | -32 | -0.0422% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 110,782 | 110,599 | 110,599 | 0 | 0.0000% | -183 | -0.1652% | Inherited repeat |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 95,439 | 95,407 | 95,407 | 0 | 0.0000% | -32 | -0.0335% | Inherited repeat |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 128,079 | 128,047 | 128,047 | 0 | 0.0000% | -32 | -0.0250% | Inherited repeat |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 58,091 | 58,062 | 58,062 | 0 | 0.0000% | -29 | -0.0499% | Inherited repeat |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 77,582 | 77,553 | 77,553 | 0 | 0.0000% | -29 | -0.0374% | Inherited repeat |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 74,790 | 74,761 | 74,761 | 0 | 0.0000% | -29 | -0.0388% | Inherited repeat |
| `testGas_FillBidFullyMatchesSingleAsk()` | 75,364 | 75,332 | 75,332 | 0 | 0.0000% | -32 | -0.0425% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 110,621 | 110,425 | 110,425 | 0 | 0.0000% | -196 | -0.1772% | Inherited repeat |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 95,344 | 95,312 | 95,312 | 0 | 0.0000% | -32 | -0.0336% | Inherited repeat |
| `testGas_FillRestAskEmptyBook()` | 151,005 | 151,005 | 151,005 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_FillRestBidEmptyBook()` | 152,929 | 152,929 | 152,929 | 0 | 0.0000% | 0 | 0.0000% | Inherited repeat |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 187,980 | 166,424 | 166,691 | +267 | +0.1604% | -21,289 | -11.3251% | Inherited repeat |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 238,912 | 207,609 | 208,011 | +402 | +0.1936% | -30,901 | -12.9341% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsAsk()` | 251,085 | 216,982 | 217,432 | +450 | +0.2074% | -33,653 | -13.4030% | Inherited repeat |
| `testGas_LargeRandomBookPartialFillsBid()` | 200,523 | 175,739 | 176,054 | +315 | +0.1792% | -24,469 | -12.2026% | Inherited repeat |
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
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 876,901 | 807,314 | 808,706 | +1,392 | +0.1724% | -68,195 | -7.7768% | Inherited repeat |

### Top-Order Hooks

Contract: `RadixMatchingEngineHookGasTest`.

| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `testGas_CancelAskSkipsPathologicalBidTree()` | 44,051 | 44,373 | 44,373 | 0 | 0.0000% | +322 | +0.7310% | - |
| `testGas_CancelFilledBidClaim()` | 37,789 | 37,909 | 37,909 | 0 | 0.0000% | +120 | +0.3176% | - |
| `testGas_CancelFullDepthBidCombRightmost()` | 911,245 | 798,870 | 800,310 | +1,440 | +0.1803% | -110,935 | -12.1740% | - |
| `testGas_CancelMaxValidDepthAskCombRightmost()` | 819,318 | 708,450 | 634,242 | -74,208 | -10.4747% | -185,076 | -22.5890% | - |
| `testGas_CancelPartialBid()` | 53,890 | 54,017 | 54,017 | 0 | 0.0000% | +127 | +0.2357% | - |
| `testGas_CancelUnfilledAsk()` | 44,290 | 44,612 | 44,612 | 0 | 0.0000% | +322 | +0.7270% | - |
| `testGas_CancelUnfilledBid()` | 44,810 | 44,937 | 44,937 | 0 | 0.0000% | +127 | +0.2834% | - |
| `testGas_DirtyAskCrossLeafNonceComb()` | 393,029 | 387,823 | 387,823 | 0 | 0.0000% | -5,206 | -1.3246% | - |
| `testGas_DirtyAskHalfNonceComb()` | 287,796 | 285,095 | 285,095 | 0 | 0.0000% | -2,701 | -0.9385% | - |
| `testGas_DirtyAskNearlyWholeNonceComb()` | 173,627 | 173,598 | 173,598 | 0 | 0.0000% | -29 | -0.0167% | - |
| `testGas_DirtyAskSmallFill16Orders()` | 133,577 | 132,880 | 132,880 | 0 | 0.0000% | -697 | -0.5218% | - |
| `testGas_DirtyAskSmallFill64Orders()` | 151,365 | 150,334 | 150,334 | 0 | 0.0000% | -1,031 | -0.6811% | - |
| `testGas_DirtyAskSmallFillNonceComb()` | 392,901 | 387,528 | 387,528 | 0 | 0.0000% | -5,373 | -1.3675% | - |
| `testGas_DirtyAskWholeNonceComb()` | 146,964 | 146,935 | 146,935 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_DirtyBidCrossLeafNonceComb()` | 395,666 | 390,863 | 390,863 | 0 | 0.0000% | -4,803 | -1.2139% | - |
| `testGas_DirtyBidHalfNonceComb()` | 288,601 | 286,108 | 286,108 | 0 | 0.0000% | -2,493 | -0.8638% | - |
| `testGas_DirtyBidNearlyWholeNonceComb()` | 174,880 | 174,851 | 174,851 | 0 | 0.0000% | -29 | -0.0166% | - |
| `testGas_DirtyBidSmallFill16Orders()` | 134,204 | 133,559 | 133,559 | 0 | 0.0000% | -645 | -0.4806% | - |
| `testGas_DirtyBidSmallFill64Orders()` | 153,212 | 152,259 | 152,259 | 0 | 0.0000% | -953 | -0.6220% | - |
| `testGas_DirtyBidSmallFillNonceComb()` | 394,490 | 389,533 | 389,533 | 0 | 0.0000% | -4,957 | -1.2566% | - |
| `testGas_DirtyBidWholeNonceComb()` | 147,133 | 147,104 | 147,104 | 0 | 0.0000% | -29 | -0.0197% | - |
| `testGas_FillAskConsumesDirtySamePriceBidSubtree()` | 74,641 | 74,612 | 74,612 | 0 | 0.0000% | -29 | -0.0389% | - |
| `testGas_FillAskConsumesFullDepthBidComb()` | 228,926 | 228,897 | 228,897 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillAskFullyMatchesSingleBid()` | 86,047 | 86,015 | 86,015 | 0 | 0.0000% | -32 | -0.0372% | - |
| `testGas_FillAskPartiallyMatchesOffSpineBidBranch()` | 126,069 | 125,886 | 125,886 | 0 | 0.0000% | -183 | -0.1452% | - |
| `testGas_FillAskPartiallyMatchesSingleBid()` | 107,894 | 107,862 | 107,862 | 0 | 0.0000% | -32 | -0.0297% | - |
| `testGas_FillBidConsumesAskAndRestsRemainder()` | 141,498 | 141,466 | 141,466 | 0 | 0.0000% | -32 | -0.0226% | - |
| `testGas_FillBidConsumesDirtySamePriceAskSubtree()` | 73,780 | 73,751 | 73,751 | 0 | 0.0000% | -29 | -0.0393% | - |
| `testGas_FillBidConsumesMaxValidDepthAskComb()` | 228,572 | 228,543 | 228,543 | 0 | 0.0000% | -29 | -0.0127% | - |
| `testGas_FillBidConsumesSamePriceAskSubtree()` | 92,741 | 92,712 | 92,712 | 0 | 0.0000% | -29 | -0.0313% | - |
| `testGas_FillBidFullyMatchesSingleAsk()` | 84,399 | 84,367 | 84,367 | 0 | 0.0000% | -32 | -0.0379% | - |
| `testGas_FillBidPartiallyMatchesOffSpineAskBranch()` | 124,790 | 124,594 | 124,594 | 0 | 0.0000% | -196 | -0.1571% | - |
| `testGas_FillBidPartiallyMatchesSingleAsk()` | 106,553 | 106,521 | 106,521 | 0 | 0.0000% | -32 | -0.0300% | - |
| `testGas_FillRestAskEmptyBook()` | 142,840 | 142,840 | 142,840 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_FillRestBidEmptyBook()` | 144,720 | 144,720 | 144,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| `testGas_LargeRandomBookAskMatchesOneBid()` | 206,746 | 185,190 | 185,457 | +267 | +0.1442% | -21,289 | -10.2972% | - |
| `testGas_LargeRandomBookBidMatchesOneAsk()` | 258,948 | 227,645 | 228,047 | +402 | +0.1766% | -30,901 | -11.9333% | - |
| `testGas_LargeRandomBookPartialFillsAsk()` | 264,837 | 230,734 | 231,184 | +450 | +0.1950% | -33,653 | -12.7071% | - |
| `testGas_LargeRandomBookPartialFillsBid()` | 215,267 | 190,483 | 190,798 | +315 | +0.1654% | -24,469 | -11.3668% | - |
| `testGas_LargeRandomBookRestsAsk()` | 293,234 | 240,296 | 240,296 | 0 | 0.0000% | -52,938 | -18.0532% | - |
| `testGas_LargeRandomBookRestsBid()` | 278,301 | 253,430 | 253,430 | 0 | 0.0000% | -24,871 | -8.9367% | - |
| `testGas_PathologicalOffSpinePartialFillBidComb()` | 903,202 | 833,615 | 835,007 | +1,392 | +0.1670% | -68,195 | -7.5504% | - |
