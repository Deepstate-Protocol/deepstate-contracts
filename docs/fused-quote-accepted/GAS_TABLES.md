# Accepted Fused-Quote Gas Workup

Baseline is parent commit 83ce527, without the separate cancelAndFill prototype.
Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200; executor d3167db; frozen fixtures.
All 223 baseline values reuse the parent's validated measurements; every candidate case was rerun.
Public ABI, imported sources and persistent storage layout are unchanged. All 23 economic fingerprints agree.
The 222-order snapshot plus two test quotes uses mock ERC20s, a counting hook and 10-bps fees, not full Rewarder V3 execution or historical replay.
Forty-two Wide Sweep rows are inherited repetitions. The capped budget row is functional, not independent savings.
No workload-weighted savings or deployed transaction-fee estimate is claimed. Existing default-build and static-analysis release concerns are not resolved here.
**Production**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| ReplacePair | 420,635 | 420,635 | 0 | 0.00% |
| ReplaceBid | 270,222 | 270,222 | 0 | 0.00% |
| ReplaceAsk | 234,812 | 234,812 | 0 | 0.00% |
| PartialCancelReplaceBid | 320,683 | 320,683 | 0 | 0.00% |
| PartialCancelReplaceAsk | 277,527 | 277,527 | 0 | 0.00% |
| MatchFullBid | 215,525 | 215,525 | 0 | 0.00% |
| MatchFullAsk | 174,468 | 174,468 | 0 | 0.00% |
| MatchPartialBid | 224,291 | 224,049 | -242 | -0.11% |
| MatchPartialAsk | 183,496 | 183,254 | -242 | -0.13% |
| MatchCancelReplacePair | 496,391 | 496,149 | -242 | -0.05% |
| CancelUnfilledBid | 165,372 | 165,372 | 0 | 0.00% |
| CancelUnfilledAsk | 124,567 | 124,567 | 0 | 0.00% |
| CancelPartialBid | 181,146 | 181,146 | 0 | 0.00% |
| CancelPartialAsk | 139,633 | 139,633 | 0 | 0.00% |
| RestBidAtBest | 258,683 | 258,683 | 0 | 0.00% |
| RestAskAtBest | 224,662 | 224,662 | 0 | 0.00% |
| RestBidImproved | 285,180 | 285,180 | 0 | 0.00% |
| RestAskImproved | 250,592 | 250,592 | 0 | 0.00% |
| ClaimFilledBid | 93,102 | 93,102 | 0 | 0.00% |
| ClaimFilledAsk | 79,628 | 79,628 | 0 | 0.00% |
| MatchAndRestBid | 313,601 | 313,601 | 0 | 0.00% |
| MatchAndRestAsk | 344,874 | 344,874 | 0 | 0.00% |
| ClaimAndCancelPair | 188,978 | 188,978 | 0 | 0.00% |

**Core**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,594 | 38,594 | 0 | 0.00% |
| CancelFilledBidClaim | 36,676 | 36,676 | 0 | 0.00% |
| CancelFullDepthBidCombRightmost | 752,062 | 752,062 | 0 | 0.00% |
| CancelMaxValidDepthAskCombRightmost | 662,536 | 662,536 | 0 | 0.00% |
| CancelPartialBid | 47,381 | 47,381 | 0 | 0.00% |
| CancelUnfilledAsk | 38,655 | 38,655 | 0 | 0.00% |
| CancelUnfilledBid | 38,299 | 38,299 | 0 | 0.00% |
| DirtyAskCrossLeafNonceComb | 352,893 | 352,593 | -300 | -0.09% |
| DirtyAskHalfNonceComb | 226,877 | 226,577 | -300 | -0.13% |
| DirtyAskNearlyWholeNonceComb | 90,989 | 90,689 | -300 | -0.33% |
| DirtyAskSmallFill16Orders | 119,049 | 118,749 | -300 | -0.25% |
| DirtyAskSmallFill64Orders | 135,147 | 134,847 | -300 | -0.22% |
| DirtyAskSmallFillNonceComb | 354,713 | 354,413 | -300 | -0.08% |
| DirtyAskWholeNonceComb | 65,255 | 65,255 | 0 | 0.00% |
| DirtyBidCrossLeafNonceComb | 353,863 | 353,563 | -300 | -0.08% |
| DirtyBidHalfNonceComb | 226,268 | 225,968 | -300 | -0.13% |
| DirtyBidNearlyWholeNonceComb | 91,068 | 90,768 | -300 | -0.33% |
| DirtyBidSmallFill16Orders | 118,427 | 118,127 | -300 | -0.25% |
| DirtyBidSmallFill64Orders | 135,715 | 135,415 | -300 | -0.22% |
| DirtyBidSmallFillNonceComb | 354,633 | 354,333 | -300 | -0.08% |
| DirtyBidWholeNonceComb | 64,300 | 64,300 | 0 | 0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,130 | 56,130 | 0 | 0.00% |
| FillAskConsumesFullDepthBidComb | 74,941 | 74,941 | 0 | 0.00% |
| FillAskFullyMatchesSingleBid | 73,932 | 73,932 | 0 | 0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 107,906 | 107,606 | -300 | -0.28% |
| FillAskPartiallyMatchesSingleBid | 93,397 | 93,155 | -242 | -0.26% |
| FillBidConsumesAskAndRestsRemainder | 124,786 | 124,786 | 0 | 0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,393 | 56,393 | 0 | 0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,420 | 75,420 | 0 | 0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,136 | 73,136 | 0 | 0.00% |
| FillBidFullyMatchesSingleAsk | 73,738 | 73,738 | 0 | 0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 107,816 | 107,516 | -300 | -0.28% |
| FillBidPartiallyMatchesSingleAsk | 93,538 | 93,296 | -242 | -0.26% |
| FillRestAskEmptyBook | 149,756 | 149,756 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,466 | 150,466 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,352 | 158,352 | 0 | 0.00% |
| LargeRandomBookBidMatchesOneAsk | 197,627 | 197,627 | 0 | 0.00% |
| LargeRandomBookPartialFillsAsk | 206,522 | 206,280 | -242 | -0.12% |
| LargeRandomBookPartialFillsBid | 167,205 | 166,963 | -242 | -0.14% |
| LargeRandomBookRestsAsk | 196,223 | 196,223 | 0 | 0.00% |
| LargeRandomBookRestsBid | 210,356 | 210,356 | 0 | 0.00% |
| PathologicalOffSpinePartialFillBidComb | 770,807 | 770,520 | -287 | -0.04% |

**Hooks**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 42,351 | 42,351 | 0 | 0.00% |
| CancelFilledBidClaim | 37,178 | 37,178 | 0 | 0.00% |
| CancelFullDepthBidCombRightmost | 760,361 | 760,361 | 0 | 0.00% |
| CancelMaxValidDepthAskCombRightmost | 669,986 | 669,986 | 0 | 0.00% |
| CancelPartialBid | 51,675 | 51,675 | 0 | 0.00% |
| CancelUnfilledAsk | 42,412 | 42,412 | 0 | 0.00% |
| CancelUnfilledBid | 42,591 | 42,591 | 0 | 0.00% |
| DirtyAskCrossLeafNonceComb | 365,821 | 365,521 | -300 | -0.08% |
| DirtyAskHalfNonceComb | 269,805 | 269,505 | -300 | -0.11% |
| DirtyAskNearlyWholeNonceComb | 165,917 | 165,617 | -300 | -0.18% |
| DirtyAskSmallFill16Orders | 126,365 | 126,065 | -300 | -0.24% |
| DirtyAskSmallFill64Orders | 142,865 | 142,565 | -300 | -0.21% |
| DirtyAskSmallFillNonceComb | 367,657 | 367,357 | -300 | -0.08% |
| DirtyAskWholeNonceComb | 142,243 | 142,243 | 0 | 0.00% |
| DirtyBidCrossLeafNonceComb | 367,749 | 367,449 | -300 | -0.08% |
| DirtyBidHalfNonceComb | 270,154 | 269,854 | -300 | -0.11% |
| DirtyBidNearlyWholeNonceComb | 166,954 | 166,654 | -300 | -0.18% |
| DirtyBidSmallFill16Orders | 126,701 | 126,401 | -300 | -0.24% |
| DirtyBidSmallFill64Orders | 144,391 | 144,091 | -300 | -0.21% |
| DirtyBidSmallFillNonceComb | 368,535 | 368,235 | -300 | -0.08% |
| DirtyBidWholeNonceComb | 142,246 | 142,246 | 0 | 0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 70,247 | 70,247 | 0 | 0.00% |
| FillAskConsumesFullDepthBidComb | 223,195 | 223,195 | 0 | 0.00% |
| FillAskFullyMatchesSingleBid | 81,386 | 81,386 | 0 | 0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 117,762 | 117,462 | -300 | -0.25% |
| FillAskPartiallyMatchesSingleBid | 100,802 | 100,560 | -242 | -0.24% |
| FillBidConsumesAskAndRestsRemainder | 133,086 | 133,086 | 0 | 0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 69,552 | 69,552 | 0 | 0.00% |
| FillBidConsumesMaxValidDepthAskComb | 222,837 | 222,837 | 0 | 0.00% |
| FillBidConsumesSamePriceAskSubtree | 88,496 | 88,496 | 0 | 0.00% |
| FillBidFullyMatchesSingleAsk | 80,313 | 80,313 | 0 | 0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 116,714 | 116,414 | -300 | -0.26% |
| FillBidPartiallyMatchesSingleAsk | 100,064 | 99,822 | -242 | -0.24% |
| FillRestAskEmptyBook | 138,972 | 138,972 | 0 | 0.00% |
| FillRestBidEmptyBook | 139,682 | 139,682 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 170,957 | 170,957 | 0 | 0.00% |
| LargeRandomBookBidMatchesOneAsk | 212,514 | 212,514 | 0 | 0.00% |
| LargeRandomBookPartialFillsAsk | 215,058 | 214,816 | -242 | -0.11% |
| LargeRandomBookPartialFillsBid | 176,263 | 176,021 | -242 | -0.14% |
| LargeRandomBookRestsAsk | 205,974 | 205,974 | 0 | 0.00% |
| LargeRandomBookRestsBid | 207,481 | 207,481 | 0 | 0.00% |
| PathologicalOffSpinePartialFillBidComb | 778,360 | 778,073 | -287 | -0.04% |

**Protocol Fee**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,594 | 38,594 | 0 | 0.00% |
| CancelFilledBidClaim | 36,676 | 36,676 | 0 | 0.00% |
| CancelFullDepthBidCombRightmost | 752,062 | 752,062 | 0 | 0.00% |
| CancelMaxValidDepthAskCombRightmost | 662,536 | 662,536 | 0 | 0.00% |
| CancelPartialBid | 47,381 | 47,381 | 0 | 0.00% |
| CancelUnfilledAsk | 38,655 | 38,655 | 0 | 0.00% |
| CancelUnfilledBid | 38,299 | 38,299 | 0 | 0.00% |
| DirtyAskCrossLeafNonceComb | 353,327 | 353,027 | -300 | -0.08% |
| DirtyAskHalfNonceComb | 252,347 | 252,047 | -300 | -0.12% |
| DirtyAskNearlyWholeNonceComb | 116,459 | 116,159 | -300 | -0.26% |
| DirtyAskSmallFill16Orders | 119,483 | 119,183 | -300 | -0.25% |
| DirtyAskSmallFill64Orders | 135,581 | 135,281 | -300 | -0.22% |
| DirtyAskSmallFillNonceComb | 355,147 | 354,847 | -300 | -0.08% |
| DirtyAskWholeNonceComb | 90,725 | 90,725 | 0 | 0.00% |
| DirtyBidCrossLeafNonceComb | 354,282 | 353,982 | -300 | -0.08% |
| DirtyBidHalfNonceComb | 251,723 | 251,423 | -300 | -0.12% |
| DirtyBidNearlyWholeNonceComb | 116,523 | 116,223 | -300 | -0.26% |
| DirtyBidSmallFill16Orders | 118,846 | 118,546 | -300 | -0.25% |
| DirtyBidSmallFill64Orders | 136,134 | 135,834 | -300 | -0.22% |
| DirtyBidSmallFillNonceComb | 355,052 | 354,752 | -300 | -0.08% |
| DirtyBidWholeNonceComb | 89,755 | 89,755 | 0 | 0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,549 | 56,549 | 0 | 0.00% |
| FillAskConsumesFullDepthBidComb | 100,396 | 100,396 | 0 | 0.00% |
| FillAskFullyMatchesSingleBid | 74,351 | 74,351 | 0 | 0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 108,325 | 108,025 | -300 | -0.28% |
| FillAskPartiallyMatchesSingleBid | 93,816 | 93,574 | -242 | -0.26% |
| FillBidConsumesAskAndRestsRemainder | 125,220 | 125,220 | 0 | 0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,827 | 56,827 | 0 | 0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,854 | 75,854 | 0 | 0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,570 | 73,570 | 0 | 0.00% |
| FillBidFullyMatchesSingleAsk | 74,172 | 74,172 | 0 | 0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 108,250 | 107,950 | -300 | -0.28% |
| FillBidPartiallyMatchesSingleAsk | 93,972 | 93,730 | -242 | -0.26% |
| FillRestAskEmptyBook | 149,918 | 149,918 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,629 | 150,629 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,771 | 158,771 | 0 | 0.00% |
| LargeRandomBookBidMatchesOneAsk | 198,061 | 198,061 | 0 | 0.00% |
| LargeRandomBookPartialFillsAsk | 206,956 | 206,714 | -242 | -0.12% |
| LargeRandomBookPartialFillsBid | 167,624 | 167,382 | -242 | -0.14% |
| LargeRandomBookRestsAsk | 196,385 | 196,385 | 0 | 0.00% |
| LargeRandomBookRestsBid | 210,519 | 210,519 | 0 | 0.00% |
| PathologicalOffSpinePartialFillBidComb | 796,262 | 795,975 | -287 | -0.04% |

**Wide Sweep**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| CancelAskSkipsPathologicalBidTree | 38,660 | 38,660 | 0 | 0.00% |
| CancelFilledBidClaim | 36,742 | 36,742 | 0 | 0.00% |
| CancelFullDepthBidCombRightmost | 752,084 | 752,084 | 0 | 0.00% |
| CancelMaxValidDepthAskCombRightmost | 662,536 | 662,536 | 0 | 0.00% |
| CancelPartialBid | 47,447 | 47,447 | 0 | 0.00% |
| CancelUnfilledAsk | 38,765 | 38,765 | 0 | 0.00% |
| CancelUnfilledBid | 38,365 | 38,365 | 0 | 0.00% |
| DirtyAskCrossLeafNonceComb | 352,950 | 352,650 | -300 | -0.08% |
| DirtyAskHalfNonceComb | 227,000 | 226,700 | -300 | -0.13% |
| DirtyAskNearlyWholeNonceComb | 91,068 | 90,768 | -300 | -0.33% |
| DirtyAskSmallFill16Orders | 119,282 | 118,982 | -300 | -0.25% |
| DirtyAskSmallFill64Orders | 135,226 | 134,926 | -300 | -0.22% |
| DirtyAskSmallFillNonceComb | 354,770 | 354,470 | -300 | -0.08% |
| DirtyAskWholeNonceComb | 65,378 | 65,378 | 0 | 0.00% |
| DirtyBidCrossLeafNonceComb | 354,118 | 353,818 | -300 | -0.08% |
| DirtyBidHalfNonceComb | 226,347 | 226,047 | -300 | -0.13% |
| DirtyBidNearlyWholeNonceComb | 91,169 | 90,869 | -300 | -0.33% |
| DirtyBidSmallFill16Orders | 118,550 | 118,250 | -300 | -0.25% |
| DirtyBidSmallFill64Orders | 135,882 | 135,582 | -300 | -0.22% |
| DirtyBidSmallFillNonceComb | 354,690 | 354,390 | -300 | -0.08% |
| DirtyBidWholeNonceComb | 64,357 | 64,357 | 0 | 0.00% |
| FillAskConsumesDirtySamePriceBidSubtree | 56,224 | 56,224 | 0 | 0.00% |
| FillAskConsumesFullDepthBidComb | 75,035 | 75,035 | 0 | 0.00% |
| FillAskFullyMatchesSingleBid | 74,114 | 74,114 | 0 | 0.00% |
| FillAskPartiallyMatchesOffSpineBidBranch | 108,000 | 107,700 | -300 | -0.28% |
| FillAskPartiallyMatchesSingleBid | 93,535 | 93,293 | -242 | -0.26% |
| FillBidConsumesAskAndRestsRemainder | 124,855 | 124,855 | 0 | 0.00% |
| FillBidConsumesDirtySamePriceAskSubtree | 56,506 | 56,506 | 0 | 0.00% |
| FillBidConsumesMaxValidDepthAskComb | 75,533 | 75,533 | 0 | 0.00% |
| FillBidConsumesSamePriceAskSubtree | 73,205 | 73,205 | 0 | 0.00% |
| FillBidFullyMatchesSingleAsk | 73,851 | 73,851 | 0 | 0.00% |
| FillBidPartiallyMatchesOffSpineAskBranch | 107,885 | 107,585 | -300 | -0.28% |
| FillBidPartiallyMatchesSingleAsk | 93,673 | 93,431 | -242 | -0.26% |
| FillRestAskEmptyBook | 149,850 | 149,850 | 0 | 0.00% |
| FillRestBidEmptyBook | 150,601 | 150,601 | 0 | 0.00% |
| LargeRandomBookAskMatchesOneBid | 158,468 | 158,468 | 0 | 0.00% |
| LargeRandomBookBidMatchesOneAsk | 197,762 | 197,762 | 0 | 0.00% |
| LargeRandomBookPartialFillsAsk | 206,723 | 206,481 | -242 | -0.12% |
| LargeRandomBookPartialFillsBid | 167,343 | 167,101 | -242 | -0.14% |
| LargeRandomBookRestsAsk | 196,295 | 196,295 | 0 | 0.00% |
| LargeRandomBookRestsBid | 210,447 | 210,447 | 0 | 0.00% |
| MixedSweep1024 | 97,633 | 97,633 | 0 | 0.00% |
| MixedSweep1024AndRest | 148,905 | 148,905 | 0 | 0.00% |
| MixedSweep1024BurningHookAndFees | 348,153 | 348,153 | 0 | 0.00% |
| MixedSweep1024FitsOneMillionGas | 96,905 | 96,905 | 0 | 0.00% |
| MixedSweep1024RestBurningHooksAndFees | 602,233 | 602,233 | 0 | 0.00% |
| MixedSweep256 | 97,317 | 97,317 | 0 | 0.00% |
| MixedSweep4096 | 98,193 | 98,193 | 0 | 0.00% |
| MixedSweep4096RestBurningHooksAndFees | 608,912 | 608,912 | 0 | 0.00% |
| MixedSweep64 | 96,617 | 96,617 | 0 | 0.00% |
| PathologicalOffSpinePartialFillBidComb | 770,901 | 770,614 | -287 | -0.04% |

**Additional Cases**
| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |
|---|---:|---:|---:|---:|
| OpportunityGasProbe:RestAsk16Orders | 154,963 | 154,963 | 0 | 0.00% |
| OpportunityGasProbe:RestAsk64Orders | 164,214 | 164,214 | 0 | 0.00% |
| OpportunityGasProbe:RestAskDifferentTickLeftNonceComb | 161,897 | 161,897 | 0 | 0.00% |
| OpportunityGasProbe:RestAskDirtyLeftNonceComb | 364,349 | 364,349 | 0 | 0.00% |
| OpportunityGasProbe:RestAskLeftNonceComb | 364,042 | 364,042 | 0 | 0.00% |
| OpportunityGasProbe:RestAskWorseTickLeftNonceComb | 162,811 | 162,811 | 0 | 0.00% |
| OpportunityGasProbe:RestBid16Orders | 155,864 | 155,864 | 0 | 0.00% |
| OpportunityGasProbe:RestBid64Orders | 165,599 | 165,599 | 0 | 0.00% |
| OpportunityGasProbe:RestBidDifferentTickLeftNonceComb | 162,518 | 162,518 | 0 | 0.00% |
| OpportunityGasProbe:RestBidDirtyLeftNonceComb | 365,567 | 365,567 | 0 | 0.00% |
| OpportunityGasProbe:RestBidLeftNonceComb | 365,546 | 365,546 | 0 | 0.00% |
| OpportunityGasProbe:RestBidWorseTickLeftNonceComb | 163,014 | 163,014 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorAndProtocolFeeFill | 124,673 | 124,673 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillAskFullyMatchesSingleBid | 99,162 | 99,162 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillBidFullyMatchesSingleAsk | 99,382 | 99,382 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorFillRestBidEmptyBook | 150,971 | 150,971 | 0 | 0.00% |
| DeepstateV1IntegratorFeeGasTest:IntegratorRouteNetsRepeatedFeeToken | 111,666 | 111,666 | 0 | 0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidCancelAfterThreePartialMatches | 115,063 | 115,063 | 0 | 0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidPartialMatchAfterDirtySpineRest | 129,747 | 129,503 | -244 | -0.19% |
| RadixMatchingEngineGasTestNativeDirtySpine:ObservedNativeBidRestsAfterFiveLevelDirtySpine | 214,317 | 214,317 | 0 | 0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidCancelAfterThreePartialMatches | 656,207 | 656,207 | 0 | 0.00% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidPartialMatchAfterDirtySpineRest | 667,743 | 667,456 | -287 | -0.04% |
| RadixMatchingEngineGasTestNativeDirtySpine:PathologicalNativeBidRestsAfterFullDepthDirtySpine | 768,002 | 768,002 | 0 | 0.00% |
