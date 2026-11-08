# Per-Stage Deltas

## Change 1

| Test | Baseline | Previous | Candidate | Delta vs Baseline | % vs Baseline | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,674 | 124,674 | 124,673 | -1 | -0.00% | -1 | -0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,163 | 99,163 | 99,162 | -1 | -0.00% | -1 | -0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,383 | 99,383 | 99,382 | -1 | -0.00% | -1 | -0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,971 | 150,971 | 150,971 | 0 | 0.00% | 0 | 0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 111,668 | 111,668 | 111,666 | -2 | -0.00% | -2 | -0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 155,250 | 155,250 | 154,963 | -287 | -0.18% | -287 | -0.18% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 164,501 | 164,501 | 164,214 | -287 | -0.17% | -287 | -0.17% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 162,184 | 162,184 | 161,897 | -287 | -0.18% | -287 | -0.18% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 364,636 | 364,636 | 364,349 | -287 | -0.08% | -287 | -0.08% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 364,329 | 364,329 | 364,042 | -287 | -0.08% | -287 | -0.08% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 163,098 | 163,098 | 162,811 | -287 | -0.18% | -287 | -0.18% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 156,151 | 156,151 | 155,864 | -287 | -0.18% | -287 | -0.18% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 165,886 | 165,886 | 165,599 | -287 | -0.17% | -287 | -0.17% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 162,805 | 162,805 | 162,518 | -287 | -0.18% | -287 | -0.18% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 365,854 | 365,854 | 365,567 | -287 | -0.08% | -287 | -0.08% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 365,833 | 365,833 | 365,546 | -287 | -0.08% | -287 | -0.08% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 163,301 | 163,301 | 163,014 | -287 | -0.18% | -287 | -0.18% | - |
| ProductionCategoriesTest:testProduction_CancelPartialAsk() | 139,920 | 139,920 | 139,920 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_CancelPartialBid() | 181,826 | 181,826 | 181,826 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_CancelUnfilledAsk() | 124,854 | 124,854 | 124,854 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_CancelUnfilledBid() | 166,052 | 166,052 | 166,052 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_ClaimAndCancelPair() | 189,611 | 189,611 | 189,611 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_ClaimFilledAsk() | 79,581 | 79,581 | 79,581 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_ClaimFilledBid() | 93,034 | 93,034 | 93,034 | 0 | 0.00% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchAndRestAsk() | 344,821 | 344,821 | 344,874 | +53 | +0.02% | +53 | +0.02% | - |
| ProductionCategoriesTest:testProduction_MatchAndRestBid() | 313,536 | 313,536 | 313,601 | +65 | +0.02% | +65 | +0.02% | - |
| ProductionCategoriesTest:testProduction_MatchCancelReplacePair() | 504,436 | 504,436 | 497,358 | -7,078 | -1.40% | -7,078 | -1.40% | - |
| ProductionCategoriesTest:testProduction_MatchFullAsk() | 174,403 | 174,403 | 174,468 | +65 | +0.04% | +65 | +0.04% | - |
| ProductionCategoriesTest:testProduction_MatchFullBid() | 215,472 | 215,472 | 215,525 | +53 | +0.02% | +53 | +0.02% | - |
| ProductionCategoriesTest:testProduction_MatchPartialAsk() | 183,431 | 183,431 | 183,496 | +65 | +0.04% | +65 | +0.04% | - |
| ProductionCategoriesTest:testProduction_MatchPartialBid() | 224,238 | 224,238 | 224,291 | +53 | +0.02% | +53 | +0.02% | - |
| ProductionCategoriesTest:testProduction_PartialCancelReplaceAsk() | 296,576 | 296,576 | 277,814 | -18,762 | -6.33% | -18,762 | -6.33% | - |
| ProductionCategoriesTest:testProduction_PartialCancelReplaceBid() | 332,336 | 332,336 | 321,363 | -10,973 | -3.30% | -10,973 | -3.30% | - |
| ProductionCategoriesTest:testProduction_ReplaceAsk() | 253,861 | 253,861 | 235,099 | -18,762 | -7.39% | -18,762 | -7.39% | - |
| ProductionCategoriesTest:testProduction_ReplaceBid() | 281,875 | 281,875 | 270,902 | -10,973 | -3.89% | -10,973 | -3.89% | - |
| ProductionCategoriesTest:testProduction_ReplacePair() | 428,745 | 428,745 | 421,602 | -7,143 | -1.67% | -7,143 | -1.67% | - |
| ProductionCategoriesTest:testProduction_RestAskAtBest() | 243,424 | 243,424 | 224,662 | -18,762 | -7.71% | -18,762 | -7.71% | - |
| ProductionCategoriesTest:testProduction_RestAskImproved() | 269,354 | 269,354 | 250,592 | -18,762 | -6.97% | -18,762 | -6.97% | - |
| ProductionCategoriesTest:testProduction_RestBidAtBest() | 269,656 | 269,656 | 258,683 | -10,973 | -4.07% | -10,973 | -4.07% | - |
| ProductionCategoriesTest:testProduction_RestBidImproved() | 296,153 | 296,153 | 285,180 | -10,973 | -3.71% | -10,973 | -3.71% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 38,577 | 38,577 | 38,577 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,646 | 36,646 | 36,646 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 748,579 | 748,579 | 748,579 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 659,053 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 47,366 | 47,366 | 47,366 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 38,638 | 38,638 | 38,638 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 38,282 | 38,282 | 38,282 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 353,328 | 353,328 | 353,327 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 252,348 | 252,348 | 252,347 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,460 | 116,460 | 116,459 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,484 | 119,484 | 119,483 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 135,582 | 135,582 | 135,581 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 355,148 | 355,148 | 355,147 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,726 | 90,726 | 90,725 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 354,283 | 354,283 | 354,282 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 251,724 | 251,724 | 251,723 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,524 | 116,524 | 116,523 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 118,847 | 118,847 | 118,846 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,135 | 136,135 | 136,134 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 355,053 | 355,053 | 355,052 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,756 | 89,756 | 89,755 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,550 | 56,550 | 56,549 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 100,397 | 100,397 | 100,396 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,352 | 74,352 | 74,351 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,326 | 108,326 | 108,325 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,817 | 93,817 | 93,816 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,221 | 125,221 | 125,220 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,828 | 56,828 | 56,827 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,855 | 75,855 | 75,854 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,571 | 73,571 | 73,570 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,173 | 74,173 | 74,172 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,251 | 108,251 | 108,250 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,973 | 93,973 | 93,972 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,918 | 149,918 | 149,918 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 150,629 | 150,629 | 150,629 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 158,772 | 158,772 | 158,771 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 198,062 | 198,062 | 198,061 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 206,957 | 206,957 | 206,956 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 167,625 | 167,625 | 167,624 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 196,386 | 196,386 | 196,385 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 210,520 | 210,520 | 210,519 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 796,263 | 796,263 | 796,262 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 38,577 | 38,577 | 38,577 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,646 | 36,646 | 36,646 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 748,579 | 748,579 | 748,579 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 659,053 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 47,366 | 47,366 | 47,366 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 38,638 | 38,638 | 38,638 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 38,282 | 38,282 | 38,282 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 352,894 | 352,894 | 352,893 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 226,878 | 226,878 | 226,877 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 90,990 | 90,990 | 90,989 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,050 | 119,050 | 119,049 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,148 | 135,148 | 135,147 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 354,714 | 354,714 | 354,713 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,256 | 65,256 | 65,255 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 353,864 | 353,864 | 353,863 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 226,269 | 226,269 | 226,268 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,069 | 91,069 | 91,068 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,428 | 118,428 | 118,427 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 135,716 | 135,716 | 135,715 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 354,634 | 354,634 | 354,633 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,301 | 64,301 | 64,300 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,131 | 56,131 | 56,130 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 74,942 | 74,942 | 74,941 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 73,933 | 73,933 | 73,932 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 107,907 | 107,907 | 107,906 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,398 | 93,398 | 93,397 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 124,787 | 124,787 | 124,786 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,394 | 56,394 | 56,393 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,421 | 75,421 | 75,420 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,137 | 73,137 | 73,136 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,739 | 73,739 | 73,738 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 107,817 | 107,817 | 107,816 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,539 | 93,539 | 93,538 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,756 | 149,756 | 149,756 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 150,466 | 150,466 | 150,466 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 158,353 | 158,353 | 158,352 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 197,628 | 197,628 | 197,627 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 206,523 | 206,523 | 206,522 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 167,206 | 167,206 | 167,205 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 196,224 | 196,224 | 196,223 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 210,357 | 210,357 | 210,356 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 770,808 | 770,808 | 770,807 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 114,766 | 114,766 | 114,766 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 129,748 | 129,748 | 129,747 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 214,604 | 214,604 | 214,317 | -287 | -0.13% | -287 | -0.13% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 653,318 | 653,318 | 653,318 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 667,744 | 667,744 | 667,743 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 768,289 | 768,289 | 768,002 | -287 | -0.04% | -287 | -0.04% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 38,643 | 38,643 | 38,643 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,712 | 36,712 | 36,712 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 748,601 | 748,601 | 748,601 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 659,053 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 47,432 | 47,432 | 47,432 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 38,748 | 38,748 | 38,748 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 38,348 | 38,348 | 38,348 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 352,951 | 352,951 | 352,950 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 227,001 | 227,001 | 227,000 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,069 | 91,069 | 91,068 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,283 | 119,283 | 119,282 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,227 | 135,227 | 135,226 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 354,771 | 354,771 | 354,770 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,379 | 65,379 | 65,378 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 354,119 | 354,119 | 354,118 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 226,348 | 226,348 | 226,347 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,170 | 91,170 | 91,169 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,551 | 118,551 | 118,550 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 135,883 | 135,883 | 135,882 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 354,691 | 354,691 | 354,690 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,358 | 64,358 | 64,357 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,225 | 56,225 | 56,224 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,036 | 75,036 | 75,035 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,115 | 74,115 | 74,114 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,001 | 108,001 | 108,000 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,536 | 93,536 | 93,535 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 124,856 | 124,856 | 124,855 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,507 | 56,507 | 56,506 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,534 | 75,534 | 75,533 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,206 | 73,206 | 73,205 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,852 | 73,852 | 73,851 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 107,886 | 107,886 | 107,885 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,674 | 93,674 | 93,673 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,850 | 149,850 | 149,850 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 150,601 | 150,601 | 150,601 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 158,469 | 158,469 | 158,468 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 197,763 | 197,763 | 197,762 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 206,724 | 206,724 | 206,723 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 167,344 | 167,344 | 167,343 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 196,296 | 196,296 | 196,295 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 210,448 | 210,448 | 210,447 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 97,634 | 97,634 | 97,633 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 148,906 | 148,906 | 148,905 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 348,088 | 348,088 | 348,153 | +65 | +0.02% | +65 | +0.02% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 96,906 | 96,906 | 96,905 | -1 | -0.00% | -1 | -0.00% | functional budget check; both capped calls succeed |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 602,168 | 602,168 | 602,233 | +65 | +0.01% | +65 | +0.01% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,318 | 97,318 | 97,317 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,194 | 98,194 | 98,193 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 608,847 | 608,847 | 608,912 | +65 | +0.01% | +65 | +0.01% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 96,618 | 96,618 | 96,617 | -1 | -0.00% | -1 | -0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 770,902 | 770,902 | 770,901 | -1 | -0.00% | -1 | -0.00% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 42,373 | 42,373 | 42,373 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,148 | 37,148 | 37,148 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 768,508 | 768,508 | 768,508 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 678,133 | 678,133 | 678,133 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 51,695 | 51,695 | 51,695 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 42,434 | 42,434 | 42,434 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 42,613 | 42,613 | 42,613 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 365,756 | 365,756 | 365,821 | +65 | +0.02% | +65 | +0.02% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 269,740 | 269,740 | 269,805 | +65 | +0.02% | +65 | +0.02% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 165,852 | 165,852 | 165,917 | +65 | +0.04% | +65 | +0.04% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 126,300 | 126,300 | 126,365 | +65 | +0.05% | +65 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 142,800 | 142,800 | 142,865 | +65 | +0.05% | +65 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 367,592 | 367,592 | 367,657 | +65 | +0.02% | +65 | +0.02% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 142,178 | 142,178 | 142,243 | +65 | +0.05% | +65 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 367,696 | 367,696 | 367,749 | +53 | +0.01% | +53 | +0.01% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 270,101 | 270,101 | 270,154 | +53 | +0.02% | +53 | +0.02% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 166,901 | 166,901 | 166,954 | +53 | +0.03% | +53 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 126,648 | 126,648 | 126,701 | +53 | +0.04% | +53 | +0.04% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 144,338 | 144,338 | 144,391 | +53 | +0.04% | +53 | +0.04% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 368,482 | 368,482 | 368,535 | +53 | +0.01% | +53 | +0.01% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 142,193 | 142,193 | 142,246 | +53 | +0.04% | +53 | +0.04% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 70,194 | 70,194 | 70,247 | +53 | +0.08% | +53 | +0.08% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 223,142 | 223,142 | 223,195 | +53 | +0.02% | +53 | +0.02% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 81,333 | 81,333 | 81,386 | +53 | +0.07% | +53 | +0.07% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 117,709 | 117,709 | 117,762 | +53 | +0.05% | +53 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 100,749 | 100,749 | 100,802 | +53 | +0.05% | +53 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 133,021 | 133,021 | 133,086 | +65 | +0.05% | +65 | +0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 69,487 | 69,487 | 69,552 | +65 | +0.09% | +65 | +0.09% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 222,772 | 222,772 | 222,837 | +65 | +0.03% | +65 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 88,431 | 88,431 | 88,496 | +65 | +0.07% | +65 | +0.07% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 80,248 | 80,248 | 80,313 | +65 | +0.08% | +65 | +0.08% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 116,649 | 116,649 | 116,714 | +65 | +0.06% | +65 | +0.06% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 99,999 | 99,999 | 100,064 | +65 | +0.07% | +65 | +0.07% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 138,972 | 138,972 | 138,972 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 139,682 | 139,682 | 139,682 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 170,904 | 170,904 | 170,957 | +53 | +0.03% | +53 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 212,449 | 212,449 | 212,514 | +65 | +0.03% | +65 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 214,993 | 214,993 | 215,058 | +65 | +0.03% | +65 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 176,210 | 176,210 | 176,263 | +53 | +0.03% | +53 | +0.03% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 224,736 | 224,736 | 205,974 | -18,762 | -8.35% | -18,762 | -8.35% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 234,006 | 234,006 | 207,481 | -26,525 | -11.34% | -26,525 | -11.34% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 778,307 | 778,307 | 778,360 | +53 | +0.01% | +53 | +0.01% | - |

## Change 2

| Test | Baseline | Previous | Candidate | Delta vs Baseline | % vs Baseline | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,674 | 124,673 | 124,673 | -1 | -0.00% | 0 | 0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,163 | 99,162 | 99,162 | -1 | -0.00% | 0 | 0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,383 | 99,382 | 99,382 | -1 | -0.00% | 0 | 0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,971 | 150,971 | 150,971 | 0 | 0.00% | 0 | 0.00% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 111,668 | 111,666 | 111,666 | -2 | -0.00% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 155,250 | 154,963 | 154,963 | -287 | -0.18% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 164,501 | 164,214 | 164,214 | -287 | -0.17% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 162,184 | 161,897 | 161,897 | -287 | -0.18% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 364,636 | 364,349 | 364,349 | -287 | -0.08% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 364,329 | 364,042 | 364,042 | -287 | -0.08% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 163,098 | 162,811 | 162,811 | -287 | -0.18% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 156,151 | 155,864 | 155,864 | -287 | -0.18% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 165,886 | 165,599 | 165,599 | -287 | -0.17% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 162,805 | 162,518 | 162,518 | -287 | -0.18% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 365,854 | 365,567 | 365,567 | -287 | -0.08% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 365,833 | 365,546 | 365,546 | -287 | -0.08% | 0 | 0.00% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 163,301 | 163,014 | 163,014 | -287 | -0.18% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_CancelPartialAsk() | 139,920 | 139,920 | 139,633 | -287 | -0.21% | -287 | -0.21% | - |
| ProductionCategoriesTest:testProduction_CancelPartialBid() | 181,826 | 181,826 | 181,146 | -680 | -0.37% | -680 | -0.37% | - |
| ProductionCategoriesTest:testProduction_CancelUnfilledAsk() | 124,854 | 124,854 | 124,567 | -287 | -0.23% | -287 | -0.23% | - |
| ProductionCategoriesTest:testProduction_CancelUnfilledBid() | 166,052 | 166,052 | 165,372 | -680 | -0.41% | -680 | -0.41% | - |
| ProductionCategoriesTest:testProduction_ClaimAndCancelPair() | 189,611 | 189,611 | 188,978 | -633 | -0.33% | -633 | -0.33% | - |
| ProductionCategoriesTest:testProduction_ClaimFilledAsk() | 79,581 | 79,581 | 79,628 | +47 | +0.06% | +47 | +0.06% | - |
| ProductionCategoriesTest:testProduction_ClaimFilledBid() | 93,034 | 93,034 | 93,102 | +68 | +0.07% | +68 | +0.07% | - |
| ProductionCategoriesTest:testProduction_MatchAndRestAsk() | 344,821 | 344,874 | 344,874 | +53 | +0.02% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchAndRestBid() | 313,536 | 313,601 | 313,601 | +65 | +0.02% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchCancelReplacePair() | 504,436 | 497,358 | 496,391 | -8,045 | -1.59% | -967 | -0.19% | - |
| ProductionCategoriesTest:testProduction_MatchFullAsk() | 174,403 | 174,468 | 174,468 | +65 | +0.04% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchFullBid() | 215,472 | 215,525 | 215,525 | +53 | +0.02% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchPartialAsk() | 183,431 | 183,496 | 183,496 | +65 | +0.04% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_MatchPartialBid() | 224,238 | 224,291 | 224,291 | +53 | +0.02% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_PartialCancelReplaceAsk() | 296,576 | 277,814 | 277,527 | -19,049 | -6.42% | -287 | -0.10% | - |
| ProductionCategoriesTest:testProduction_PartialCancelReplaceBid() | 332,336 | 321,363 | 320,683 | -11,653 | -3.51% | -680 | -0.21% | - |
| ProductionCategoriesTest:testProduction_ReplaceAsk() | 253,861 | 235,099 | 234,812 | -19,049 | -7.50% | -287 | -0.12% | - |
| ProductionCategoriesTest:testProduction_ReplaceBid() | 281,875 | 270,902 | 270,222 | -11,653 | -4.13% | -680 | -0.25% | - |
| ProductionCategoriesTest:testProduction_ReplacePair() | 428,745 | 421,602 | 420,635 | -8,110 | -1.89% | -967 | -0.23% | - |
| ProductionCategoriesTest:testProduction_RestAskAtBest() | 243,424 | 224,662 | 224,662 | -18,762 | -7.71% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_RestAskImproved() | 269,354 | 250,592 | 250,592 | -18,762 | -6.97% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_RestBidAtBest() | 269,656 | 258,683 | 258,683 | -10,973 | -4.07% | 0 | 0.00% | - |
| ProductionCategoriesTest:testProduction_RestBidImproved() | 296,153 | 285,180 | 285,180 | -10,973 | -3.71% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 38,577 | 38,577 | 38,594 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,646 | 36,646 | 36,676 | +30 | +0.08% | +30 | +0.08% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 748,579 | 748,579 | 752,062 | +3,483 | +0.47% | +3,483 | +0.47% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 662,536 | +3,483 | +0.53% | +3,483 | +0.53% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 47,366 | 47,366 | 47,381 | +15 | +0.03% | +15 | +0.03% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 38,638 | 38,638 | 38,655 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 38,282 | 38,282 | 38,299 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 353,328 | 353,327 | 353,327 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 252,348 | 252,347 | 252,347 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,460 | 116,459 | 116,459 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,484 | 119,483 | 119,483 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 135,582 | 135,581 | 135,581 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 355,148 | 355,147 | 355,147 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,726 | 90,725 | 90,725 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 354,283 | 354,282 | 354,282 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 251,724 | 251,723 | 251,723 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,524 | 116,523 | 116,523 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 118,847 | 118,846 | 118,846 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,135 | 136,134 | 136,134 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 355,053 | 355,052 | 355,052 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,756 | 89,755 | 89,755 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,550 | 56,549 | 56,549 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 100,397 | 100,396 | 100,396 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,352 | 74,351 | 74,351 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,326 | 108,325 | 108,325 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,817 | 93,816 | 93,816 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,221 | 125,220 | 125,220 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,828 | 56,827 | 56,827 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,855 | 75,854 | 75,854 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,571 | 73,570 | 73,570 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,173 | 74,172 | 74,172 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,251 | 108,250 | 108,250 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,973 | 93,972 | 93,972 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,918 | 149,918 | 149,918 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 150,629 | 150,629 | 150,629 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 158,772 | 158,771 | 158,771 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 198,062 | 198,061 | 198,061 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 206,957 | 206,956 | 206,956 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 167,625 | 167,624 | 167,624 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 196,386 | 196,385 | 196,385 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 210,520 | 210,519 | 210,519 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 796,263 | 796,262 | 796,262 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 38,577 | 38,577 | 38,594 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,646 | 36,646 | 36,676 | +30 | +0.08% | +30 | +0.08% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 748,579 | 748,579 | 752,062 | +3,483 | +0.47% | +3,483 | +0.47% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 662,536 | +3,483 | +0.53% | +3,483 | +0.53% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 47,366 | 47,366 | 47,381 | +15 | +0.03% | +15 | +0.03% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 38,638 | 38,638 | 38,655 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 38,282 | 38,282 | 38,299 | +17 | +0.04% | +17 | +0.04% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 352,894 | 352,893 | 352,893 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 226,878 | 226,877 | 226,877 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 90,990 | 90,989 | 90,989 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,050 | 119,049 | 119,049 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,148 | 135,147 | 135,147 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 354,714 | 354,713 | 354,713 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,256 | 65,255 | 65,255 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 353,864 | 353,863 | 353,863 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 226,269 | 226,268 | 226,268 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,069 | 91,068 | 91,068 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,428 | 118,427 | 118,427 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 135,716 | 135,715 | 135,715 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 354,634 | 354,633 | 354,633 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,301 | 64,300 | 64,300 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,131 | 56,130 | 56,130 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 74,942 | 74,941 | 74,941 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 73,933 | 73,932 | 73,932 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 107,907 | 107,906 | 107,906 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,398 | 93,397 | 93,397 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 124,787 | 124,786 | 124,786 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,394 | 56,393 | 56,393 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,421 | 75,420 | 75,420 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,137 | 73,136 | 73,136 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,739 | 73,738 | 73,738 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 107,817 | 107,816 | 107,816 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,539 | 93,538 | 93,538 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,756 | 149,756 | 149,756 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 150,466 | 150,466 | 150,466 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 158,353 | 158,352 | 158,352 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 197,628 | 197,627 | 197,627 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 206,523 | 206,522 | 206,522 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 167,206 | 167,205 | 167,205 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 196,224 | 196,223 | 196,223 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 210,357 | 210,356 | 210,356 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 770,808 | 770,807 | 770,807 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 114,766 | 114,766 | 115,063 | +297 | +0.26% | +297 | +0.26% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 129,748 | 129,747 | 129,747 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 214,604 | 214,317 | 214,317 | -287 | -0.13% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 653,318 | 653,318 | 656,207 | +2,889 | +0.44% | +2,889 | +0.44% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 667,744 | 667,743 | 667,743 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 768,289 | 768,002 | 768,002 | -287 | -0.04% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 38,643 | 38,643 | 38,660 | +17 | +0.04% | +17 | +0.04% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,712 | 36,712 | 36,742 | +30 | +0.08% | +30 | +0.08% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 748,601 | 748,601 | 752,084 | +3,483 | +0.47% | +3,483 | +0.47% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 659,053 | 659,053 | 662,536 | +3,483 | +0.53% | +3,483 | +0.53% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 47,432 | 47,432 | 47,447 | +15 | +0.03% | +15 | +0.03% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 38,748 | 38,748 | 38,765 | +17 | +0.04% | +17 | +0.04% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 38,348 | 38,348 | 38,365 | +17 | +0.04% | +17 | +0.04% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 352,951 | 352,950 | 352,950 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 227,001 | 227,000 | 227,000 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,069 | 91,068 | 91,068 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,283 | 119,282 | 119,282 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,227 | 135,226 | 135,226 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 354,771 | 354,770 | 354,770 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,379 | 65,378 | 65,378 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 354,119 | 354,118 | 354,118 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 226,348 | 226,347 | 226,347 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,170 | 91,169 | 91,169 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,551 | 118,550 | 118,550 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 135,883 | 135,882 | 135,882 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 354,691 | 354,690 | 354,690 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,358 | 64,357 | 64,357 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,225 | 56,224 | 56,224 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,036 | 75,035 | 75,035 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,115 | 74,114 | 74,114 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,001 | 108,000 | 108,000 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,536 | 93,535 | 93,535 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 124,856 | 124,855 | 124,855 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,507 | 56,506 | 56,506 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 75,534 | 75,533 | 75,533 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,206 | 73,205 | 73,205 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,852 | 73,851 | 73,851 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 107,886 | 107,885 | 107,885 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,674 | 93,673 | 93,673 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,850 | 149,850 | 149,850 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 150,601 | 150,601 | 150,601 | 0 | 0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 158,469 | 158,468 | 158,468 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 197,763 | 197,762 | 197,762 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 206,724 | 206,723 | 206,723 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 167,344 | 167,343 | 167,343 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 196,296 | 196,295 | 196,295 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 210,448 | 210,447 | 210,447 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 97,634 | 97,633 | 97,633 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 148,906 | 148,905 | 148,905 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 348,088 | 348,153 | 348,153 | +65 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 96,906 | 96,905 | 96,905 | -1 | -0.00% | 0 | 0.00% | functional budget check; both capped calls succeed |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 602,168 | 602,233 | 602,233 | +65 | +0.01% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,318 | 97,317 | 97,317 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,194 | 98,193 | 98,193 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 608,847 | 608,912 | 608,912 | +65 | +0.01% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 96,618 | 96,617 | 96,617 | -1 | -0.00% | 0 | 0.00% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 770,902 | 770,901 | 770,901 | -1 | -0.00% | 0 | 0.00% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 42,373 | 42,373 | 42,351 | -22 | -0.05% | -22 | -0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,148 | 37,148 | 37,178 | +30 | +0.08% | +30 | +0.08% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 768,508 | 768,508 | 760,361 | -8,147 | -1.06% | -8,147 | -1.06% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 678,133 | 678,133 | 669,986 | -8,147 | -1.20% | -8,147 | -1.20% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 51,695 | 51,695 | 51,675 | -20 | -0.04% | -20 | -0.04% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 42,434 | 42,434 | 42,412 | -22 | -0.05% | -22 | -0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 42,613 | 42,613 | 42,591 | -22 | -0.05% | -22 | -0.05% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 365,756 | 365,821 | 365,821 | +65 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 269,740 | 269,805 | 269,805 | +65 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 165,852 | 165,917 | 165,917 | +65 | +0.04% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 126,300 | 126,365 | 126,365 | +65 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 142,800 | 142,865 | 142,865 | +65 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 367,592 | 367,657 | 367,657 | +65 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 142,178 | 142,243 | 142,243 | +65 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 367,696 | 367,749 | 367,749 | +53 | +0.01% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 270,101 | 270,154 | 270,154 | +53 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 166,901 | 166,954 | 166,954 | +53 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 126,648 | 126,701 | 126,701 | +53 | +0.04% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 144,338 | 144,391 | 144,391 | +53 | +0.04% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 368,482 | 368,535 | 368,535 | +53 | +0.01% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 142,193 | 142,246 | 142,246 | +53 | +0.04% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 70,194 | 70,247 | 70,247 | +53 | +0.08% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 223,142 | 223,195 | 223,195 | +53 | +0.02% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 81,333 | 81,386 | 81,386 | +53 | +0.07% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 117,709 | 117,762 | 117,762 | +53 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 100,749 | 100,802 | 100,802 | +53 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 133,021 | 133,086 | 133,086 | +65 | +0.05% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 69,487 | 69,552 | 69,552 | +65 | +0.09% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 222,772 | 222,837 | 222,837 | +65 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 88,431 | 88,496 | 88,496 | +65 | +0.07% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 80,248 | 80,313 | 80,313 | +65 | +0.08% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 116,649 | 116,714 | 116,714 | +65 | +0.06% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 99,999 | 100,064 | 100,064 | +65 | +0.07% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 138,972 | 138,972 | 138,972 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 139,682 | 139,682 | 139,682 | 0 | 0.00% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 170,904 | 170,957 | 170,957 | +53 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 212,449 | 212,514 | 212,514 | +65 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 214,993 | 215,058 | 215,058 | +65 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 176,210 | 176,263 | 176,263 | +53 | +0.03% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 224,736 | 205,974 | 205,974 | -18,762 | -8.35% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 234,006 | 207,481 | 207,481 | -26,525 | -11.34% | 0 | 0.00% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 778,307 | 778,360 | 778,360 | +53 | +0.01% | 0 | 0.00% | - |
