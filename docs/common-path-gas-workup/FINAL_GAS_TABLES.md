# Common-Path Gas Workup

Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200; frozen fixture; executor d3167db.
Baseline is b4164fe, not the deployed Robinhood source. All 223 baseline values reproduce the preceding comparison exactly.
Change 1 reuses the hook-required best leaf to reject non-crossing matching and avoids match-buffer allocation on empty/non-crossing hooked sides.
Change 2 captures a top cancellation successor at its first collapsed parent, only when hooks require that successor.
Changes are cumulative. Every measured row and regression remains visible; no thresholds filter the results.
The production group is ordered by the previously observed post-DGP3 category frequency, not the frequency of individual bid/ask variants.
Its fixture uses the same 222 indexed orders plus two test quotes, mock ERC20s and a counter hook, not full V3 rewarder execution.
All 23 economic-state fingerprints agree across baseline and both candidates.
Forty-two Wide Sweep rows are inherited repetitions. The budget check is functional, not an independent workload; both calls succeed.
No production-weighted overall savings percentage is claimed.
Final functional validation, invariant campaign, bounds tests, SMT checks, ABI and persistent layout checks completed.
The existing default-build stack-depth blocker is recorded in raw/prepush-formal-build.log. Fresh coverage, Slither and Halmos have not passed.
The final combined implementation includes both changes; deltas below are against b4164fe.

**Production Categories**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| ReplacePair | 428,745 | 420,635 | -8,110 | -1.89% |
| ReplaceBid | 281,875 | 270,222 | -11,653 | -4.13% |
| ReplaceAsk | 253,861 | 234,812 | -19,049 | -7.50% |
| PartialCancelReplaceBid | 332,336 | 320,683 | -11,653 | -3.51% |
| PartialCancelReplaceAsk | 296,576 | 277,527 | -19,049 | -6.42% |
| MatchFullBid | 215,472 | 215,525 | +53 | +0.02% |
| MatchFullAsk | 174,403 | 174,468 | +65 | +0.04% |
| MatchPartialBid | 224,238 | 224,291 | +53 | +0.02% |
| MatchPartialAsk | 183,431 | 183,496 | +65 | +0.04% |
| MatchCancelReplacePair | 504,436 | 496,391 | -8,045 | -1.59% |
| CancelUnfilledBid | 166,052 | 165,372 | -680 | -0.41% |
| CancelUnfilledAsk | 124,854 | 124,567 | -287 | -0.23% |
| CancelPartialBid | 181,826 | 181,146 | -680 | -0.37% |
| CancelPartialAsk | 139,920 | 139,633 | -287 | -0.21% |
| RestBidAtBest | 269,656 | 258,683 | -10,973 | -4.07% |
| RestAskAtBest | 243,424 | 224,662 | -18,762 | -7.71% |
| RestBidImproved | 296,153 | 285,180 | -10,973 | -3.71% |
| RestAskImproved | 269,354 | 250,592 | -18,762 | -6.97% |
| ClaimFilledBid | 93,034 | 93,102 | +68 | +0.07% |
| ClaimFilledAsk | 79,581 | 79,628 | +47 | +0.06% |
| MatchAndRestBid | 313,536 | 313,601 | +65 | +0.02% |
| MatchAndRestAsk | 344,821 | 344,874 | +53 | +0.02% |
| ClaimAndCancelPair | 189,611 | 188,978 | -633 | -0.33% |

**Core**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,577 | 38,594 | +17 | +0.04% |
| CancelFilledBidClaim | 36,646 | 36,676 | +30 | +0.08% |
| CancelFullDepthBidCombRightmost | 748,579 | 752,062 | +3,483 | +0.47% |
| CancelMaxValidDepthAskCombRightmost | 659,053 | 662,536 | +3,483 | +0.53% |
| CancelPartialBid | 47,366 | 47,381 | +15 | +0.03% |
| CancelUnfilledAsk | 38,638 | 38,655 | +17 | +0.04% |
| CancelUnfilledBid | 38,282 | 38,299 | +17 | +0.04% |
| DirtyAskCrossLeafNonceComb | 352,894 | 352,893 | -1 | -0.00% |
| DirtyAskHalfNonceComb | 226,878 | 226,877 | -1 | -0.00% |
| DirtyAskNearlyWholeNonceComb | 90,990 | 90,989 | -1 | -0.00% |
| DirtyAskSmallFill16Orders | 119,050 | 119,049 | -1 | -0.00% |
| DirtyAskSmallFill64Orders | 135,148 | 135,147 | -1 | -0.00% |
| DirtyAskSmallFillNonceComb | 354,714 | 354,713 | -1 | -0.00% |
| DirtyAskWholeNonceComb | 65,256 | 65,255 | -1 | -0.00% |
| DirtyBidCrossLeafNonceComb | 353,864 | 353,863 | -1 | -0.00% |
| DirtyBidHalfNonceComb | 226,269 | 226,268 | -1 | -0.00% |
| DirtyBidNearlyWholeNonceComb | 91,069 | 91,068 | -1 | -0.00% |
| DirtyBidSmallFill16Orders | 118,428 | 118,427 | -1 | -0.00% |
| DirtyBidSmallFill64Orders | 135,716 | 135,715 | -1 | -0.00% |
| DirtyBidSmallFillNonceComb | 354,634 | 354,633 | -1 | -0.00% |
| DirtyBidWholeNonceComb | 64,301 | 64,300 | -1 | -0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,131 | 56,130 | -1 | -0.00% |
| FillAskConsumesFullDepthBidComb | 74,942 | 74,941 | -1 | -0.00% |
| FillAskFullyMatchesSingleBid | 73,933 | 73,932 | -1 | -0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 107,907 | 107,906 | -1 | -0.00% |
| FillAskPartiallyMatchesSingleBid | 93,398 | 93,397 | -1 | -0.00% |
| FillBidConsumesAskAndRestsRemainder | 124,787 | 124,786 | -1 | -0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,394 | 56,393 | -1 | -0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,421 | 75,420 | -1 | -0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,137 | 73,136 | -1 | -0.00% |
| FillBidFullyMatchesSingleAsk | 73,739 | 73,738 | -1 | -0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 107,817 | 107,816 | -1 | -0.00% |
| FillBidPartiallyMatchesSingleAsk | 93,539 | 93,538 | -1 | -0.00% |
| FillRestAskEmptyBook | 149,756 | 149,756 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,466 | 150,466 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,353 | 158,352 | -1 | -0.00% |
| LargeRandomBookBidMatchesOneAsk | 197,628 | 197,627 | -1 | -0.00% |
| LargeRandomBookPartialFillsAsk | 206,523 | 206,522 | -1 | -0.00% |
| LargeRandomBookPartialFillsBid | 167,206 | 167,205 | -1 | -0.00% |
| LargeRandomBookRestsAsk | 196,224 | 196,223 | -1 | -0.00% |
| LargeRandomBookRestsBid | 210,357 | 210,356 | -1 | -0.00% |
| PathologicalOffSpinePartialFillBidComb | 770,808 | 770,807 | -1 | -0.00% |

**Hooks**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 42,373 | 42,351 | -22 | -0.05% |
| CancelFilledBidClaim | 37,148 | 37,178 | +30 | +0.08% |
| CancelFullDepthBidCombRightmost | 768,508 | 760,361 | -8,147 | -1.06% |
| CancelMaxValidDepthAskCombRightmost | 678,133 | 669,986 | -8,147 | -1.20% |
| CancelPartialBid | 51,695 | 51,675 | -20 | -0.04% |
| CancelUnfilledAsk | 42,434 | 42,412 | -22 | -0.05% |
| CancelUnfilledBid | 42,613 | 42,591 | -22 | -0.05% |
| DirtyAskCrossLeafNonceComb | 365,756 | 365,821 | +65 | +0.02% |
| DirtyAskHalfNonceComb | 269,740 | 269,805 | +65 | +0.02% |
| DirtyAskNearlyWholeNonceComb | 165,852 | 165,917 | +65 | +0.04% |
| DirtyAskSmallFill16Orders | 126,300 | 126,365 | +65 | +0.05% |
| DirtyAskSmallFill64Orders | 142,800 | 142,865 | +65 | +0.05% |
| DirtyAskSmallFillNonceComb | 367,592 | 367,657 | +65 | +0.02% |
| DirtyAskWholeNonceComb | 142,178 | 142,243 | +65 | +0.05% |
| DirtyBidCrossLeafNonceComb | 367,696 | 367,749 | +53 | +0.01% |
| DirtyBidHalfNonceComb | 270,101 | 270,154 | +53 | +0.02% |
| DirtyBidNearlyWholeNonceComb | 166,901 | 166,954 | +53 | +0.03% |
| DirtyBidSmallFill16Orders | 126,648 | 126,701 | +53 | +0.04% |
| DirtyBidSmallFill64Orders | 144,338 | 144,391 | +53 | +0.04% |
| DirtyBidSmallFillNonceComb | 368,482 | 368,535 | +53 | +0.01% |
| DirtyBidWholeNonceComb | 142,193 | 142,246 | +53 | +0.04% |
| FillAskConsumesDirtySamePriceBidSubtree | 70,194 | 70,247 | +53 | +0.08% |
| FillAskConsumesFullDepthBidComb | 223,142 | 223,195 | +53 | +0.02% |
| FillAskFullyMatchesSingleBid | 81,333 | 81,386 | +53 | +0.07% |
| FillAskPartiallyMatchesOffSpineBidBranch | 117,709 | 117,762 | +53 | +0.05% |
| FillAskPartiallyMatchesSingleBid | 100,749 | 100,802 | +53 | +0.05% |
| FillBidConsumesAskAndRestsRemainder | 133,021 | 133,086 | +65 | +0.05% |
| FillBidConsumesDirtySamePriceAskSubtree | 69,487 | 69,552 | +65 | +0.09% |
| FillBidConsumesMaxValidDepthAskComb | 222,772 | 222,837 | +65 | +0.03% |
| FillBidConsumesSamePriceAskSubtree | 88,431 | 88,496 | +65 | +0.07% |
| FillBidFullyMatchesSingleAsk | 80,248 | 80,313 | +65 | +0.08% |
| FillBidPartiallyMatchesOffSpineAskBranch | 116,649 | 116,714 | +65 | +0.06% |
| FillBidPartiallyMatchesSingleAsk | 99,999 | 100,064 | +65 | +0.07% |
| FillRestAskEmptyBook | 138,972 | 138,972 | 0 | 0.00% |
| FillRestBidEmptyBook | 139,682 | 139,682 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 170,904 | 170,957 | +53 | +0.03% |
| LargeRandomBookBidMatchesOneAsk | 212,449 | 212,514 | +65 | +0.03% |
| LargeRandomBookPartialFillsAsk | 214,993 | 215,058 | +65 | +0.03% |
| LargeRandomBookPartialFillsBid | 176,210 | 176,263 | +53 | +0.03% |
| LargeRandomBookRestsAsk | 224,736 | 205,974 | -18,762 | -8.35% |
| LargeRandomBookRestsBid | 234,006 | 207,481 | -26,525 | -11.34% |
| PathologicalOffSpinePartialFillBidComb | 778,307 | 778,360 | +53 | +0.01% |

**Protocol Fee**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,577 | 38,594 | +17 | +0.04% |
| CancelFilledBidClaim | 36,646 | 36,676 | +30 | +0.08% |
| CancelFullDepthBidCombRightmost | 748,579 | 752,062 | +3,483 | +0.47% |
| CancelMaxValidDepthAskCombRightmost | 659,053 | 662,536 | +3,483 | +0.53% |
| CancelPartialBid | 47,366 | 47,381 | +15 | +0.03% |
| CancelUnfilledAsk | 38,638 | 38,655 | +17 | +0.04% |
| CancelUnfilledBid | 38,282 | 38,299 | +17 | +0.04% |
| DirtyAskCrossLeafNonceComb | 353,328 | 353,327 | -1 | -0.00% |
| DirtyAskHalfNonceComb | 252,348 | 252,347 | -1 | -0.00% |
| DirtyAskNearlyWholeNonceComb | 116,460 | 116,459 | -1 | -0.00% |
| DirtyAskSmallFill16Orders | 119,484 | 119,483 | -1 | -0.00% |
| DirtyAskSmallFill64Orders | 135,582 | 135,581 | -1 | -0.00% |
| DirtyAskSmallFillNonceComb | 355,148 | 355,147 | -1 | -0.00% |
| DirtyAskWholeNonceComb | 90,726 | 90,725 | -1 | -0.00% |
| DirtyBidCrossLeafNonceComb | 354,283 | 354,282 | -1 | -0.00% |
| DirtyBidHalfNonceComb | 251,724 | 251,723 | -1 | -0.00% |
| DirtyBidNearlyWholeNonceComb | 116,524 | 116,523 | -1 | -0.00% |
| DirtyBidSmallFill16Orders | 118,847 | 118,846 | -1 | -0.00% |
| DirtyBidSmallFill64Orders | 136,135 | 136,134 | -1 | -0.00% |
| DirtyBidSmallFillNonceComb | 355,053 | 355,052 | -1 | -0.00% |
| DirtyBidWholeNonceComb | 89,756 | 89,755 | -1 | -0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,550 | 56,549 | -1 | -0.00% |
| FillAskConsumesFullDepthBidComb | 100,397 | 100,396 | -1 | -0.00% |
| FillAskFullyMatchesSingleBid | 74,352 | 74,351 | -1 | -0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 108,326 | 108,325 | -1 | -0.00% |
| FillAskPartiallyMatchesSingleBid | 93,817 | 93,816 | -1 | -0.00% |
| FillBidConsumesAskAndRestsRemainder | 125,221 | 125,220 | -1 | -0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,828 | 56,827 | -1 | -0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,855 | 75,854 | -1 | -0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,571 | 73,570 | -1 | -0.00% |
| FillBidFullyMatchesSingleAsk | 74,173 | 74,172 | -1 | -0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 108,251 | 108,250 | -1 | -0.00% |
| FillBidPartiallyMatchesSingleAsk | 93,973 | 93,972 | -1 | -0.00% |
| FillRestAskEmptyBook | 149,918 | 149,918 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,629 | 150,629 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,772 | 158,771 | -1 | -0.00% |
| LargeRandomBookBidMatchesOneAsk | 198,062 | 198,061 | -1 | -0.00% |
| LargeRandomBookPartialFillsAsk | 206,957 | 206,956 | -1 | -0.00% |
| LargeRandomBookPartialFillsBid | 167,625 | 167,624 | -1 | -0.00% |
| LargeRandomBookRestsAsk | 196,386 | 196,385 | -1 | -0.00% |
| LargeRandomBookRestsBid | 210,520 | 210,519 | -1 | -0.00% |
| PathologicalOffSpinePartialFillBidComb | 796,263 | 796,262 | -1 | -0.00% |

**Wide Sweep**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,643 | 38,660 | +17 | +0.04% |
| CancelFilledBidClaim | 36,712 | 36,742 | +30 | +0.08% |
| CancelFullDepthBidCombRightmost | 748,601 | 752,084 | +3,483 | +0.47% |
| CancelMaxValidDepthAskCombRightmost | 659,053 | 662,536 | +3,483 | +0.53% |
| CancelPartialBid | 47,432 | 47,447 | +15 | +0.03% |
| CancelUnfilledAsk | 38,748 | 38,765 | +17 | +0.04% |
| CancelUnfilledBid | 38,348 | 38,365 | +17 | +0.04% |
| DirtyAskCrossLeafNonceComb | 352,951 | 352,950 | -1 | -0.00% |
| DirtyAskHalfNonceComb | 227,001 | 227,000 | -1 | -0.00% |
| DirtyAskNearlyWholeNonceComb | 91,069 | 91,068 | -1 | -0.00% |
| DirtyAskSmallFill16Orders | 119,283 | 119,282 | -1 | -0.00% |
| DirtyAskSmallFill64Orders | 135,227 | 135,226 | -1 | -0.00% |
| DirtyAskSmallFillNonceComb | 354,771 | 354,770 | -1 | -0.00% |
| DirtyAskWholeNonceComb | 65,379 | 65,378 | -1 | -0.00% |
| DirtyBidCrossLeafNonceComb | 354,119 | 354,118 | -1 | -0.00% |
| DirtyBidHalfNonceComb | 226,348 | 226,347 | -1 | -0.00% |
| DirtyBidNearlyWholeNonceComb | 91,170 | 91,169 | -1 | -0.00% |
| DirtyBidSmallFill16Orders | 118,551 | 118,550 | -1 | -0.00% |
| DirtyBidSmallFill64Orders | 135,883 | 135,882 | -1 | -0.00% |
| DirtyBidSmallFillNonceComb | 354,691 | 354,690 | -1 | -0.00% |
| DirtyBidWholeNonceComb | 64,358 | 64,357 | -1 | -0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,225 | 56,224 | -1 | -0.00% |
| FillAskConsumesFullDepthBidComb | 75,036 | 75,035 | -1 | -0.00% |
| FillAskFullyMatchesSingleBid | 74,115 | 74,114 | -1 | -0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 108,001 | 108,000 | -1 | -0.00% |
| FillAskPartiallyMatchesSingleBid | 93,536 | 93,535 | -1 | -0.00% |
| FillBidConsumesAskAndRestsRemainder | 124,856 | 124,855 | -1 | -0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,507 | 56,506 | -1 | -0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,534 | 75,533 | -1 | -0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,206 | 73,205 | -1 | -0.00% |
| FillBidFullyMatchesSingleAsk | 73,852 | 73,851 | -1 | -0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 107,886 | 107,885 | -1 | -0.00% |
| FillBidPartiallyMatchesSingleAsk | 93,674 | 93,673 | -1 | -0.00% |
| FillRestAskEmptyBook | 149,850 | 149,850 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,601 | 150,601 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,469 | 158,468 | -1 | -0.00% |
| LargeRandomBookBidMatchesOneAsk | 197,763 | 197,762 | -1 | -0.00% |
| LargeRandomBookPartialFillsAsk | 206,724 | 206,723 | -1 | -0.00% |
| LargeRandomBookPartialFillsBid | 167,344 | 167,343 | -1 | -0.00% |
| LargeRandomBookRestsAsk | 196,296 | 196,295 | -1 | -0.00% |
| LargeRandomBookRestsBid | 210,448 | 210,447 | -1 | -0.00% |
| MixedSweep1024 | 97,634 | 97,633 | -1 | -0.00% |
| MixedSweep1024AndRest | 148,906 | 148,905 | -1 | -0.00% |
| MixedSweep1024BurningHookAndFees | 348,088 | 348,153 | +65 | +0.02% |
| MixedSweep1024FitsOneMillionGas | 96,906 | 96,905 | -1 | -0.00% |
| MixedSweep1024RestBurningHooksAndFees | 602,168 | 602,233 | +65 | +0.01% |
| MixedSweep256 | 97,318 | 97,317 | -1 | -0.00% |
| MixedSweep4096 | 98,194 | 98,193 | -1 | -0.00% |
| MixedSweep4096RestBurningHooksAndFees | 608,847 | 608,912 | +65 | +0.01% |
| MixedSweep64 | 96,618 | 96,617 | -1 | -0.00% |
| PathologicalOffSpinePartialFillBidComb | 770,902 | 770,901 | -1 | -0.00% |

**Additional Cases**
| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| DeepstateV1IntegratorFeeGasTest:IntegratorAndProtocolFeeFill | 124,674 | 124,673 | -1 | -0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillAskFullyMatchesSingleBid | 99,163 | 99,162 | -1 | -0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillBidFullyMatchesSingleAsk | 99,383 | 99,382 | -1 | -0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillRestBidEmptyBook | 150,971 | 150,971 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorRouteNetsRepeatedFeeToken | 111,668 | 111,666 | -2 | -0.00% |
| OpportunityGasProbe:RestAsk16Orders | 155,250 | 154,963 | -287 | -0.18% |
| OpportunityGasProbe:RestAsk64Orders | 164,501 | 164,214 | -287 | -0.17% |
| OpportunityGasProbe:RestAskDifferentTickLeftNonceComb | 162,184 | 161,897 | -287 | -0.18% |
| OpportunityGasProbe:RestAskDirtyLeftNonceComb | 364,636 | 364,349 | -287 | -0.08% |
| OpportunityGasProbe:RestAskLeftNonceComb | 364,329 | 364,042 | -287 | -0.08% |
| OpportunityGasProbe:RestAskWorseTickLeftNonceComb | 163,098 | 162,811 | -287 | -0.18% |
| OpportunityGasProbe:RestBid16Orders | 156,151 | 155,864 | -287 | -0.18% |
| OpportunityGasProbe:RestBid64Orders | 165,886 | 165,599 | -287 | -0.17% |
| OpportunityGasProbe:RestBidDifferentTickLeftNonceComb | 162,805 | 162,518 | -287 | -0.18% |
| OpportunityGasProbe:RestBidDirtyLeftNonceComb | 365,854 | 365,567 | -287 | -0.08% |
| OpportunityGasProbe:RestBidLeftNonceComb | 365,833 | 365,546 | -287 | -0.08% |
| OpportunityGasProbe:RestBidWorseTickLeftNonceComb | 163,301 | 163,014 | -287 | -0.18% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidCancelAfterThreePartialMatches | 114,766 | 115,063 | +297 | +0.26% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidPartialMatchAfterDirtySpineRest | 129,748 | 129,747 | -1 | -0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidRestsAfterFiveLevelDirtySpine | 214,604 | 214,317 | -287 | -0.13% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidCancelAfterThreePartialMatches | 653,318 | 656,207 | +2,889 | +0.44% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidPartialMatchAfterDirtySpineRest | 667,744 | 667,743 | -1 | -0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidRestsAfterFullDepthDirtySpine | 768,289 | 768,002 | -287 | -0.04% |
