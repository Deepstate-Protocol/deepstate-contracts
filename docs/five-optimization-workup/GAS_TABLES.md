# Five Bounded Optimization Stages

Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200. Frozen fixture and Forge executor d3167db.
Baseline: candidate E, source SHA-256 `45d978cb4e482bb2ad0d0a76e5e82eac26da8739b86e65f09fae1d6ba10d1f70`. It reproduces all 200 previously reported observations exactly.
Stages are cumulative, not five isolated experiments. Each stage is compared against E and the immediately preceding stage.
All 200 cases per stage remain visible, including 42 inherited repetitions and the functional gas-budget check.
Negative deltas save gas; positive deltas are regressions. Benchmark frequencies are not production-volume weights.

## 1. Shared resting quotes

| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,804 | 124,804 | 124,785 | -19 | -0.0152% | -19 | -0.0152% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,293 | 99,293 | 99,274 | -19 | -0.0191% | -19 | -0.0191% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,513 | 99,513 | 99,494 | -19 | -0.0191% | -19 | -0.0191% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,111 | 150,111 | 150,749 | +638 | +0.4250% | +638 | +0.4250% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 112,061 | 112,061 | 112,042 | -19 | -0.0170% | -19 | -0.0170% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 157,922 | 157,922 | 156,700 | -1,222 | -0.7738% | -1,222 | -0.7738% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 166,859 | 166,859 | 165,637 | -1,222 | -0.7324% | -1,222 | -0.7324% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 163,201 | 163,201 | 162,075 | -1,126 | -0.6899% | -1,126 | -0.6899% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 371,112 | 371,112 | 368,482 | -2,630 | -0.7087% | -2,630 | -0.7087% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 370,805 | 370,805 | 368,175 | -2,630 | -0.7093% | -2,630 | -0.7093% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 164,094 | 164,094 | 162,989 | -1,105 | -0.6734% | -1,105 | -0.6734% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 159,811 | 159,811 | 157,632 | -2,179 | -1.3635% | -2,179 | -1.3635% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 169,232 | 169,232 | 167,053 | -2,179 | -1.2876% | -2,179 | -1.2876% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 164,739 | 164,739 | 162,721 | -2,018 | -1.2250% | -2,018 | -1.2250% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 373,318 | 373,318 | 369,731 | -3,587 | -0.9608% | -3,587 | -0.9608% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 373,297 | 373,297 | 369,710 | -3,587 | -0.9609% | -3,587 | -0.9609% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 165,214 | 165,214 | 163,217 | -1,997 | -1.2087% | -1,997 | -1.2087% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 39,851 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,570 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,176 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 48,640 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 39,912 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 39,561 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,844 | 355,844 | 355,844 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 253,720 | 253,720 | 253,720 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,616 | 116,616 | 116,616 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,768 | 119,768 | 119,768 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 136,018 | 136,018 | 136,018 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,560 | 357,560 | 357,560 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,746 | 90,746 | 90,746 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,799 | 356,799 | 356,799 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 253,096 | 253,096 | 253,096 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,680 | 116,680 | 116,680 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 119,131 | 119,131 | 119,131 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,571 | 136,571 | 136,571 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,465 | 357,465 | 357,465 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,776 | 89,776 | 89,776 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,570 | 56,570 | 56,570 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 101,046 | 101,046 | 101,046 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,472 | 74,472 | 74,464 | -8 | -0.0107% | -8 | -0.0107% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,558 | 108,558 | 108,558 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,950 | 93,950 | 93,950 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 126,090 | 126,090 | 125,243 | -847 | -0.6717% | -847 | -0.6717% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,848 | 56,848 | 56,848 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,504 | 76,504 | 76,504 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,591 | 73,591 | 73,591 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,293 | 74,293 | 74,285 | -8 | -0.0108% | -8 | -0.0108% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,483 | 108,483 | 108,483 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 94,106 | 94,106 | 94,106 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,620 | 149,620 | 149,674 | +54 | +0.0361% | +54 | +0.0361% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 151,245 | 151,245 | 150,407 | -838 | -0.5541% | -838 | -0.5541% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 161,271 | 161,271 | 161,263 | -8 | -0.0050% | -8 | -0.0050% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,632 | 201,632 | 201,624 | -8 | -0.0040% | -8 | -0.0040% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,660 | 210,660 | 210,660 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 170,257 | 170,257 | 170,257 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 199,495 | 199,495 | 198,108 | -1,387 | -0.6953% | -1,387 | -0.6953% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 215,387 | 215,387 | 212,999 | -2,388 | -1.1087% | -2,388 | -1.1087% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 810,225 | 810,225 | 810,217 | -8 | -0.0010% | -8 | -0.0010% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 39,851 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,570 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,176 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 48,640 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 39,912 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 39,561 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,410 | 355,410 | 355,410 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 228,250 | 228,250 | 228,250 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 91,146 | 91,146 | 91,146 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,334 | 119,334 | 119,334 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,584 | 135,584 | 135,584 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,126 | 357,126 | 357,126 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,276 | 65,276 | 65,276 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,380 | 356,380 | 356,380 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 227,641 | 227,641 | 227,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,225 | 91,225 | 91,225 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,712 | 118,712 | 118,712 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 136,152 | 136,152 | 136,152 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,046 | 357,046 | 357,046 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,321 | 64,321 | 64,321 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,151 | 56,151 | 56,151 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 75,591 | 75,591 | 75,591 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,053 | 74,053 | 74,045 | -8 | -0.0108% | -8 | -0.0108% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,139 | 108,139 | 108,139 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,531 | 93,531 | 93,531 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,656 | 125,656 | 124,809 | -847 | -0.6741% | -847 | -0.6741% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,414 | 56,414 | 56,414 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,070 | 76,070 | 76,070 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,157 | 73,157 | 73,157 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,859 | 73,859 | 73,851 | -8 | -0.0108% | -8 | -0.0108% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,049 | 108,049 | 108,049 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,672 | 93,672 | 93,672 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,458 | 149,458 | 149,512 | +54 | +0.0361% | +54 | +0.0361% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 151,082 | 151,082 | 150,244 | -838 | -0.5547% | -838 | -0.5547% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 160,852 | 160,852 | 160,844 | -8 | -0.0050% | -8 | -0.0050% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,198 | 201,198 | 201,190 | -8 | -0.0040% | -8 | -0.0040% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,226 | 210,226 | 210,226 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 169,838 | 169,838 | 169,838 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 199,333 | 199,333 | 197,946 | -1,387 | -0.6958% | -1,387 | -0.6958% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 215,224 | 215,224 | 212,836 | -2,388 | -1.1095% | -2,388 | -1.1095% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 784,770 | 784,770 | 784,762 | -8 | -0.0010% | -8 | -0.0010% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 117,210 | 117,210 | 117,210 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 131,666 | 131,666 | 131,666 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 220,505 | 220,505 | 216,885 | -3,620 | -1.6417% | -3,620 | -1.6417% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 658,666 | 658,666 | 658,666 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 681,103 | 681,103 | 681,103 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 772,290 | 772,290 | 768,590 | -3,700 | -0.4791% | -3,700 | -0.4791% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 39,917 | 39,917 | 39,917 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,636 | 36,636 | 36,636 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 754,198 | 754,198 | 754,198 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 48,706 | 48,706 | 48,706 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 40,022 | 40,022 | 40,022 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 39,627 | 39,627 | 39,627 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 355,467 | 355,467 | 355,467 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 228,373 | 228,373 | 228,373 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,225 | 91,225 | 91,225 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,567 | 119,567 | 119,567 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,663 | 135,663 | 135,663 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 357,183 | 357,183 | 357,183 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,399 | 65,399 | 65,399 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 356,635 | 356,635 | 356,635 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 227,720 | 227,720 | 227,720 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,326 | 91,326 | 91,326 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,835 | 118,835 | 118,835 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 136,319 | 136,319 | 136,319 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 357,103 | 357,103 | 357,103 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,378 | 64,378 | 64,378 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,245 | 56,245 | 56,245 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,685 | 75,685 | 75,685 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,235 | 74,235 | 74,227 | -8 | -0.0108% | -8 | -0.0108% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,233 | 108,233 | 108,233 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,669 | 93,669 | 93,669 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 125,725 | 125,725 | 124,878 | -847 | -0.6737% | -847 | -0.6737% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,527 | 56,527 | 56,527 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,183 | 76,183 | 76,183 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,226 | 73,226 | 73,226 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,972 | 73,972 | 73,964 | -8 | -0.0108% | -8 | -0.0108% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,118 | 108,118 | 108,118 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,807 | 93,807 | 93,807 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,552 | 149,552 | 149,606 | +54 | +0.0361% | +54 | +0.0361% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 151,217 | 151,217 | 150,379 | -838 | -0.5542% | -838 | -0.5542% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 160,968 | 160,968 | 160,960 | -8 | -0.0050% | -8 | -0.0050% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 201,333 | 201,333 | 201,325 | -8 | -0.0040% | -8 | -0.0040% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 210,427 | 210,427 | 210,427 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 169,976 | 169,976 | 169,976 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 199,405 | 199,405 | 198,018 | -1,387 | -0.6956% | -1,387 | -0.6956% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 215,315 | 215,315 | 212,927 | -2,388 | -1.1091% | -2,388 | -1.1091% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 98,283 | 98,283 | 98,283 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 150,262 | 150,262 | 149,465 | -797 | -0.5304% | -797 | -0.5304% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 350,806 | 350,806 | 350,806 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 97,555 | 97,555 | 97,555 | 0 | 0.0000% | 0 | 0.0000% | functional budget check |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 607,866 | 607,866 | 607,079 | -787 | -0.1295% | -787 | -0.1295% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,967 | 97,967 | 97,967 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,843 | 98,843 | 98,843 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 614,536 | 614,536 | 613,749 | -787 | -0.1281% | -787 | -0.1281% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 97,267 | 97,267 | 97,267 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 784,864 | 784,864 | 784,856 | -8 | -0.0010% | -8 | -0.0010% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 43,634 | 43,634 | 43,634 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,073 | 37,073 | 37,073 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 776,242 | 776,242 | 776,234 | -8 | -0.0010% | -8 | -0.0010% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 685,850 | 685,850 | 685,850 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 52,964 | 52,964 | 52,958 | -6 | -0.0113% | -6 | -0.0113% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 43,697 | 43,697 | 43,697 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 43,885 | 43,885 | 43,879 | -6 | -0.0137% | -6 | -0.0137% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 378,882 | 378,882 | 378,882 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 278,752 | 278,752 | 278,752 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 170,245 | 170,245 | 170,245 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 129,932 | 129,932 | 129,932 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 146,974 | 146,974 | 146,974 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 378,812 | 378,812 | 378,812 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 144,198 | 144,198 | 144,198 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 380,830 | 380,830 | 380,822 | -8 | -0.0021% | -8 | -0.0021% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 279,121 | 279,121 | 279,113 | -8 | -0.0029% | -8 | -0.0029% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 171,302 | 171,302 | 171,294 | -8 | -0.0047% | -8 | -0.0047% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 130,288 | 130,288 | 130,280 | -8 | -0.0061% | -8 | -0.0061% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 148,520 | 148,520 | 148,512 | -8 | -0.0054% | -8 | -0.0054% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 379,710 | 379,710 | 379,702 | -8 | -0.0021% | -8 | -0.0021% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 144,221 | 144,221 | 144,213 | -8 | -0.0055% | -8 | -0.0055% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 72,309 | 72,309 | 72,301 | -8 | -0.0111% | -8 | -0.0111% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 225,703 | 225,703 | 225,695 | -8 | -0.0035% | -8 | -0.0035% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 83,538 | 83,538 | 83,522 | -16 | -0.0192% | -16 | -0.0192% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 122,709 | 122,709 | 122,701 | -8 | -0.0065% | -8 | -0.0065% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 105,209 | 105,209 | 105,201 | -8 | -0.0076% | -8 | -0.0076% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 138,240 | 138,240 | 137,402 | -838 | -0.6062% | -838 | -0.6062% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 71,594 | 71,594 | 71,594 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 225,325 | 225,325 | 225,325 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 90,535 | 90,535 | 90,535 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 82,445 | 82,445 | 82,437 | -8 | -0.0097% | -8 | -0.0097% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 121,641 | 121,641 | 121,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 104,451 | 104,451 | 104,451 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 140,948 | 140,948 | 141,010 | +62 | +0.0440% | +62 | +0.0440% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 142,572 | 142,572 | 141,742 | -830 | -0.5822% | -830 | -0.5822% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 177,783 | 177,783 | 177,767 | -16 | -0.0090% | -16 | -0.0090% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 220,370 | 220,370 | 220,362 | -8 | -0.0036% | -8 | -0.0036% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 223,200 | 223,200 | 223,200 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 182,769 | 182,769 | 182,761 | -8 | -0.0044% | -8 | -0.0044% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 234,701 | 234,701 | 233,323 | -1,378 | -0.5871% | -1,378 | -0.5871% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 245,737 | 245,737 | 243,350 | -2,387 | -0.9714% | -2,387 | -0.9714% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 809,297 | 809,297 | 809,281 | -16 | -0.0020% | -16 | -0.0020% | - |

## 2. Known hook tops

| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,804 | 124,785 | 124,947 | +143 | +0.1146% | +162 | +0.1298% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,293 | 99,274 | 99,436 | +143 | +0.1440% | +162 | +0.1632% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,513 | 99,494 | 99,656 | +143 | +0.1437% | +162 | +0.1628% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,111 | 150,749 | 150,770 | +659 | +0.4390% | +21 | +0.0139% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 112,061 | 112,042 | 112,311 | +250 | +0.2231% | +269 | +0.2401% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 157,922 | 156,700 | 156,877 | -1,045 | -0.6617% | +177 | +0.1130% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 166,859 | 165,637 | 165,872 | -987 | -0.5915% | +235 | +0.1419% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 163,201 | 162,075 | 162,148 | -1,053 | -0.6452% | +73 | +0.0450% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 371,112 | 368,482 | 369,580 | -1,532 | -0.4128% | +1,098 | +0.2980% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 370,805 | 368,175 | 369,273 | -1,532 | -0.4132% | +1,098 | +0.2982% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 164,094 | 162,989 | 163,062 | -1,032 | -0.6289% | +73 | +0.0448% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 159,811 | 157,632 | 157,787 | -2,024 | -1.2665% | +155 | +0.0983% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 169,232 | 167,053 | 167,266 | -1,966 | -1.1617% | +213 | +0.1275% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 164,739 | 162,721 | 162,772 | -1,967 | -1.1940% | +51 | +0.0313% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 373,318 | 369,731 | 370,807 | -2,511 | -0.6726% | +1,076 | +0.2910% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 373,297 | 369,710 | 370,786 | -2,511 | -0.6727% | +1,076 | +0.2910% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 165,214 | 163,217 | 163,268 | -1,946 | -1.1779% | +51 | +0.0312% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 39,851 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,570 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,176 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 48,640 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 39,912 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 39,561 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,844 | 355,844 | 356,197 | +353 | +0.0992% | +353 | +0.0992% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 253,720 | 253,720 | 253,987 | +267 | +0.1052% | +267 | +0.1052% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,616 | 116,616 | 116,787 | +171 | +0.1466% | +171 | +0.1466% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,768 | 119,768 | 119,937 | +169 | +0.1411% | +169 | +0.1411% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 136,018 | 136,018 | 136,199 | +181 | +0.1331% | +181 | +0.1331% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,560 | 357,560 | 357,897 | +337 | +0.0942% | +337 | +0.0942% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,746 | 90,746 | 90,851 | +105 | +0.1157% | +105 | +0.1157% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,799 | 356,799 | 357,152 | +353 | +0.0989% | +353 | +0.0989% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 253,096 | 253,096 | 253,363 | +267 | +0.1055% | +267 | +0.1055% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,680 | 116,680 | 116,851 | +171 | +0.1466% | +171 | +0.1466% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 119,131 | 119,131 | 119,300 | +169 | +0.1419% | +169 | +0.1419% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,571 | 136,571 | 136,752 | +181 | +0.1325% | +181 | +0.1325% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,465 | 357,465 | 357,802 | +337 | +0.0943% | +337 | +0.0943% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,776 | 89,776 | 89,881 | +105 | +0.1170% | +105 | +0.1170% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,570 | 56,570 | 56,675 | +105 | +0.1856% | +105 | +0.1856% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 101,046 | 101,046 | 101,147 | +101 | +0.1000% | +101 | +0.1000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,472 | 74,464 | 74,625 | +153 | +0.2054% | +161 | +0.2162% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,558 | 108,558 | 108,735 | +177 | +0.1630% | +177 | +0.1630% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,950 | 93,950 | 94,090 | +140 | +0.1490% | +140 | +0.1490% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 126,090 | 125,243 | 125,392 | -698 | -0.5536% | +149 | +0.1190% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,848 | 56,848 | 56,953 | +105 | +0.1847% | +105 | +0.1847% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,504 | 76,504 | 76,605 | +101 | +0.1320% | +101 | +0.1320% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,591 | 73,591 | 73,696 | +105 | +0.1427% | +105 | +0.1427% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,293 | 74,285 | 74,446 | +153 | +0.2059% | +161 | +0.2167% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,483 | 108,483 | 108,660 | +177 | +0.1632% | +177 | +0.1632% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 94,106 | 94,106 | 94,246 | +140 | +0.1488% | +140 | +0.1488% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,620 | 149,674 | 149,717 | +97 | +0.0648% | +43 | +0.0287% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 151,245 | 150,407 | 150,428 | -817 | -0.5402% | +21 | +0.0140% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 161,271 | 161,263 | 161,564 | +293 | +0.1817% | +301 | +0.1867% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,632 | 201,624 | 201,985 | +353 | +0.1751% | +361 | +0.1790% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,660 | 210,660 | 211,000 | +340 | +0.1614% | +340 | +0.1614% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 170,257 | 170,257 | 170,537 | +280 | +0.1645% | +280 | +0.1645% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 199,495 | 198,108 | 198,367 | -1,128 | -0.5654% | +259 | +0.1307% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 215,387 | 212,999 | 213,254 | -2,133 | -0.9903% | +255 | +0.1197% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 810,225 | 810,217 | 811,273 | +1,048 | +0.1293% | +1,056 | +0.1303% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 39,851 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,570 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,176 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 48,640 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 39,912 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 39,561 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,410 | 355,410 | 355,763 | +353 | +0.0993% | +353 | +0.0993% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 228,250 | 228,250 | 228,517 | +267 | +0.1170% | +267 | +0.1170% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 91,146 | 91,146 | 91,317 | +171 | +0.1876% | +171 | +0.1876% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,334 | 119,334 | 119,503 | +169 | +0.1416% | +169 | +0.1416% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,584 | 135,584 | 135,765 | +181 | +0.1335% | +181 | +0.1335% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,126 | 357,126 | 357,463 | +337 | +0.0944% | +337 | +0.0944% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,276 | 65,276 | 65,381 | +105 | +0.1609% | +105 | +0.1609% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,380 | 356,380 | 356,733 | +353 | +0.0991% | +353 | +0.0991% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 227,641 | 227,641 | 227,908 | +267 | +0.1173% | +267 | +0.1173% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,225 | 91,225 | 91,396 | +171 | +0.1874% | +171 | +0.1874% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,712 | 118,712 | 118,881 | +169 | +0.1424% | +169 | +0.1424% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 136,152 | 136,152 | 136,333 | +181 | +0.1329% | +181 | +0.1329% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,046 | 357,046 | 357,383 | +337 | +0.0944% | +337 | +0.0944% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,321 | 64,321 | 64,426 | +105 | +0.1632% | +105 | +0.1632% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,151 | 56,151 | 56,256 | +105 | +0.1870% | +105 | +0.1870% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 75,591 | 75,591 | 75,692 | +101 | +0.1336% | +101 | +0.1336% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,053 | 74,045 | 74,206 | +153 | +0.2066% | +161 | +0.2174% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,139 | 108,139 | 108,316 | +177 | +0.1637% | +177 | +0.1637% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,531 | 93,531 | 93,671 | +140 | +0.1497% | +140 | +0.1497% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,656 | 124,809 | 124,958 | -698 | -0.5555% | +149 | +0.1194% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,414 | 56,414 | 56,519 | +105 | +0.1861% | +105 | +0.1861% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,070 | 76,070 | 76,171 | +101 | +0.1328% | +101 | +0.1328% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,157 | 73,157 | 73,262 | +105 | +0.1435% | +105 | +0.1435% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,859 | 73,851 | 74,012 | +153 | +0.2072% | +161 | +0.2180% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,049 | 108,049 | 108,226 | +177 | +0.1638% | +177 | +0.1638% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,672 | 93,672 | 93,812 | +140 | +0.1495% | +140 | +0.1495% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,458 | 149,512 | 149,555 | +97 | +0.0649% | +43 | +0.0288% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 151,082 | 150,244 | 150,265 | -817 | -0.5408% | +21 | +0.0140% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 160,852 | 160,844 | 161,145 | +293 | +0.1822% | +301 | +0.1871% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,198 | 201,190 | 201,551 | +353 | +0.1754% | +361 | +0.1794% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,226 | 210,226 | 210,566 | +340 | +0.1617% | +340 | +0.1617% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 169,838 | 169,838 | 170,118 | +280 | +0.1649% | +280 | +0.1649% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 199,333 | 197,946 | 198,205 | -1,128 | -0.5659% | +259 | +0.1308% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 215,224 | 212,836 | 213,091 | -2,133 | -0.9911% | +255 | +0.1198% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 784,770 | 784,762 | 785,818 | +1,048 | +0.1335% | +1,056 | +0.1346% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 117,210 | 117,210 | 117,210 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 131,666 | 131,666 | 131,906 | +240 | +0.1823% | +240 | +0.1823% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 220,505 | 216,885 | 217,045 | -3,460 | -1.5691% | +160 | +0.0738% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 658,666 | 658,666 | 658,666 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 681,103 | 681,103 | 682,061 | +958 | +0.1407% | +958 | +0.1407% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 772,290 | 768,590 | 770,204 | -2,086 | -0.2701% | +1,614 | +0.2100% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 39,917 | 39,917 | 39,917 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,636 | 36,636 | 36,636 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 754,198 | 754,198 | 754,198 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,641 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 48,706 | 48,706 | 48,706 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 40,022 | 40,022 | 40,022 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 39,627 | 39,627 | 39,627 | 0 | 0.0000% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 355,467 | 355,467 | 355,820 | +353 | +0.0993% | +353 | +0.0993% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 228,373 | 228,373 | 228,640 | +267 | +0.1169% | +267 | +0.1169% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,225 | 91,225 | 91,396 | +171 | +0.1874% | +171 | +0.1874% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,567 | 119,567 | 119,736 | +169 | +0.1413% | +169 | +0.1413% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,663 | 135,663 | 135,844 | +181 | +0.1334% | +181 | +0.1334% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 357,183 | 357,183 | 357,520 | +337 | +0.0943% | +337 | +0.0943% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,399 | 65,399 | 65,504 | +105 | +0.1606% | +105 | +0.1606% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 356,635 | 356,635 | 356,988 | +353 | +0.0990% | +353 | +0.0990% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 227,720 | 227,720 | 227,987 | +267 | +0.1172% | +267 | +0.1172% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,326 | 91,326 | 91,497 | +171 | +0.1872% | +171 | +0.1872% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,835 | 118,835 | 119,004 | +169 | +0.1422% | +169 | +0.1422% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 136,319 | 136,319 | 136,500 | +181 | +0.1328% | +181 | +0.1328% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 357,103 | 357,103 | 357,440 | +337 | +0.0944% | +337 | +0.0944% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,378 | 64,378 | 64,483 | +105 | +0.1631% | +105 | +0.1631% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,245 | 56,245 | 56,350 | +105 | +0.1867% | +105 | +0.1867% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,685 | 75,685 | 75,786 | +101 | +0.1334% | +101 | +0.1334% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,235 | 74,227 | 74,388 | +153 | +0.2061% | +161 | +0.2169% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,233 | 108,233 | 108,410 | +177 | +0.1635% | +177 | +0.1635% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,669 | 93,669 | 93,809 | +140 | +0.1495% | +140 | +0.1495% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 125,725 | 124,878 | 125,027 | -698 | -0.5552% | +149 | +0.1193% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,527 | 56,527 | 56,632 | +105 | +0.1858% | +105 | +0.1858% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,183 | 76,183 | 76,284 | +101 | +0.1326% | +101 | +0.1326% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,226 | 73,226 | 73,331 | +105 | +0.1434% | +105 | +0.1434% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,972 | 73,964 | 74,125 | +153 | +0.2068% | +161 | +0.2177% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,118 | 108,118 | 108,295 | +177 | +0.1637% | +177 | +0.1637% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,807 | 93,807 | 93,947 | +140 | +0.1492% | +140 | +0.1492% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,552 | 149,606 | 149,649 | +97 | +0.0649% | +43 | +0.0287% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 151,217 | 150,379 | 150,400 | -817 | -0.5403% | +21 | +0.0140% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 160,968 | 160,960 | 161,261 | +293 | +0.1820% | +301 | +0.1870% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 201,333 | 201,325 | 201,686 | +353 | +0.1753% | +361 | +0.1793% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 210,427 | 210,427 | 210,767 | +340 | +0.1616% | +340 | +0.1616% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 169,976 | 169,976 | 170,256 | +280 | +0.1647% | +280 | +0.1647% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 199,405 | 198,018 | 198,277 | -1,128 | -0.5657% | +259 | +0.1308% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 215,315 | 212,927 | 213,182 | -2,133 | -0.9906% | +255 | +0.1198% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 98,283 | 98,283 | 98,384 | +101 | +0.1028% | +101 | +0.1028% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 150,262 | 149,465 | 149,553 | -709 | -0.4718% | +88 | +0.0589% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 350,806 | 350,806 | 350,943 | +137 | +0.0391% | +137 | +0.0391% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 97,555 | 97,555 | 97,656 | +101 | +0.1035% | +101 | +0.1035% | functional budget check |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 607,866 | 607,079 | 604,933 | -2,933 | -0.4825% | -2,146 | -0.3535% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,967 | 97,967 | 98,068 | +101 | +0.1031% | +101 | +0.1031% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,843 | 98,843 | 98,944 | +101 | +0.1022% | +101 | +0.1022% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 614,536 | 613,749 | 611,603 | -2,933 | -0.4773% | -2,146 | -0.3497% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 97,267 | 97,267 | 97,368 | +101 | +0.1038% | +101 | +0.1038% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 784,864 | 784,856 | 785,912 | +1,048 | +0.1335% | +1,056 | +0.1345% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 43,634 | 43,634 | 43,634 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,073 | 37,073 | 37,073 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 776,242 | 776,234 | 776,234 | -8 | -0.0010% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 685,850 | 685,850 | 685,850 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 52,964 | 52,958 | 52,958 | -6 | -0.0113% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 43,697 | 43,697 | 43,697 | 0 | 0.0000% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 43,885 | 43,879 | 43,879 | -6 | -0.0137% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 378,882 | 378,882 | 370,676 | -8,206 | -2.1658% | -8,206 | -2.1658% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 278,752 | 278,752 | 273,430 | -5,322 | -1.9092% | -5,322 | -1.9092% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 170,245 | 170,245 | 168,230 | -2,015 | -1.1836% | -2,015 | -1.1836% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 129,932 | 129,932 | 128,888 | -1,044 | -0.8035% | -1,044 | -0.8035% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 146,974 | 146,974 | 145,546 | -1,428 | -0.9716% | -1,428 | -0.9716% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 378,812 | 378,812 | 372,392 | -6,420 | -1.6948% | -6,420 | -1.6948% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 144,198 | 144,198 | 144,339 | +141 | +0.0978% | +141 | +0.0978% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 380,830 | 380,822 | 372,616 | -8,214 | -2.1569% | -8,206 | -2.1548% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 279,121 | 279,113 | 273,791 | -5,330 | -1.9096% | -5,322 | -1.9068% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 171,302 | 171,294 | 169,279 | -2,023 | -1.1810% | -2,015 | -1.1763% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 130,288 | 130,280 | 129,236 | -1,052 | -0.8074% | -1,044 | -0.8014% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 148,520 | 148,512 | 147,084 | -1,436 | -0.9669% | -1,428 | -0.9615% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 379,710 | 379,702 | 373,282 | -6,428 | -1.6929% | -6,420 | -1.6908% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 144,221 | 144,213 | 144,354 | +133 | +0.0922% | +141 | +0.0978% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 72,309 | 72,301 | 72,442 | +133 | +0.1839% | +141 | +0.1950% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 225,703 | 225,695 | 225,832 | +129 | +0.0572% | +137 | +0.0607% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 83,538 | 83,522 | 83,738 | +200 | +0.2394% | +216 | +0.2586% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 122,709 | 122,701 | 120,259 | -2,450 | -1.9966% | -2,442 | -1.9902% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 105,209 | 105,201 | 103,169 | -2,040 | -1.9390% | -2,032 | -1.9315% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 138,240 | 137,402 | 135,336 | -2,904 | -2.1007% | -2,066 | -1.5036% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 71,594 | 71,594 | 71,735 | +141 | +0.1969% | +141 | +0.1969% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 225,325 | 225,325 | 225,462 | +137 | +0.0608% | +137 | +0.0608% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 90,535 | 90,535 | 90,676 | +141 | +0.1557% | +141 | +0.1557% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 82,445 | 82,437 | 82,653 | +208 | +0.2523% | +216 | +0.2620% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 121,641 | 121,641 | 119,199 | -2,442 | -2.0075% | -2,442 | -2.0075% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 104,451 | 104,451 | 102,419 | -2,032 | -1.9454% | -2,032 | -1.9454% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 140,948 | 141,010 | 138,783 | -2,165 | -1.5360% | -2,227 | -1.5793% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 142,572 | 141,742 | 139,493 | -3,079 | -2.1596% | -2,249 | -1.5867% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 177,783 | 177,767 | 178,123 | +340 | +0.1912% | +356 | +0.2003% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 220,370 | 220,362 | 220,778 | +408 | +0.1851% | +416 | +0.1888% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 223,200 | 223,200 | 221,153 | -2,047 | -0.9171% | -2,047 | -0.9171% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 182,769 | 182,761 | 181,248 | -1,521 | -0.8322% | -1,513 | -0.8279% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 234,701 | 233,323 | 230,967 | -3,734 | -1.5910% | -2,356 | -1.0098% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 245,737 | 243,350 | 240,990 | -4,747 | -1.9317% | -2,360 | -0.9698% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 809,297 | 809,281 | 795,461 | -13,836 | -1.7096% | -13,820 | -1.7077% | - |

## 3. Cached branch classification

| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,804 | 124,947 | 124,998 | +194 | +0.1554% | +51 | +0.0408% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,293 | 99,436 | 99,487 | +194 | +0.1954% | +51 | +0.0513% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,513 | 99,656 | 99,707 | +194 | +0.1949% | +51 | +0.0512% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,111 | 150,770 | 150,968 | +857 | +0.5709% | +198 | +0.1313% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 112,061 | 112,311 | 112,320 | +259 | +0.2311% | +9 | +0.0080% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 157,922 | 156,877 | 155,088 | -2,834 | -1.7946% | -1,789 | -1.1404% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 166,859 | 165,872 | 164,175 | -2,684 | -1.6085% | -1,697 | -1.0231% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 163,201 | 162,148 | 162,356 | -845 | -0.5178% | +208 | +0.1283% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 371,112 | 369,580 | 368,624 | -2,488 | -0.6704% | -956 | -0.2587% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 370,805 | 369,273 | 368,317 | -2,488 | -0.6710% | -956 | -0.2589% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 164,094 | 163,062 | 163,270 | -824 | -0.5022% | +208 | +0.1276% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 159,811 | 157,787 | 155,989 | -3,822 | -2.3916% | -1,798 | -1.1395% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 169,232 | 167,266 | 165,560 | -3,672 | -2.1698% | -1,706 | -1.0199% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 164,739 | 162,772 | 162,977 | -1,762 | -1.0696% | +205 | +0.1259% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 373,318 | 370,807 | 369,842 | -3,476 | -0.9311% | -965 | -0.2602% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 373,297 | 370,786 | 369,821 | -3,476 | -0.9312% | -965 | -0.2603% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 165,214 | 163,268 | 163,473 | -1,741 | -1.0538% | +205 | +0.1256% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 38,577 | -1,274 | -3.1969% | -1,274 | -3.1969% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,646 | +76 | +0.2078% | +76 | +0.2078% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,349 | +173 | +0.0229% | +173 | +0.0229% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,823 | +182 | +0.0274% | +182 | +0.0274% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 47,366 | -1,274 | -2.6192% | -1,274 | -2.6192% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 38,638 | -1,274 | -3.1920% | -1,274 | -3.1920% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 38,282 | -1,279 | -3.2330% | -1,279 | -3.2330% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,844 | 356,197 | 356,393 | +549 | +0.1543% | +196 | +0.0550% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 253,720 | 253,987 | 254,183 | +463 | +0.1825% | +196 | +0.0772% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,616 | 116,787 | 116,983 | +367 | +0.3147% | +196 | +0.1678% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,768 | 119,937 | 120,133 | +365 | +0.3048% | +196 | +0.1634% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 136,018 | 136,199 | 136,395 | +377 | +0.2772% | +196 | +0.1439% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,560 | 357,897 | 358,093 | +533 | +0.1491% | +196 | +0.0548% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,746 | 90,851 | 91,047 | +301 | +0.3317% | +196 | +0.2157% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,799 | 357,152 | 357,348 | +549 | +0.1539% | +196 | +0.0549% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 253,096 | 253,363 | 253,559 | +463 | +0.1829% | +196 | +0.0774% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,680 | 116,851 | 117,047 | +367 | +0.3145% | +196 | +0.1677% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 119,131 | 119,300 | 119,496 | +365 | +0.3064% | +196 | +0.1643% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,571 | 136,752 | 136,948 | +377 | +0.2760% | +196 | +0.1433% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,465 | 357,802 | 357,998 | +533 | +0.1491% | +196 | +0.0548% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,776 | 89,881 | 90,077 | +301 | +0.3353% | +196 | +0.2181% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,570 | 56,675 | 56,871 | +301 | +0.5321% | +196 | +0.3458% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 101,046 | 101,147 | 100,911 | -135 | -0.1336% | -236 | -0.2333% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,472 | 74,625 | 74,676 | +204 | +0.2739% | +51 | +0.0683% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,558 | 108,735 | 108,931 | +373 | +0.3436% | +196 | +0.1803% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,950 | 94,090 | 94,141 | +191 | +0.2033% | +51 | +0.0542% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 126,090 | 125,392 | 125,545 | -545 | -0.4322% | +153 | +0.1220% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,848 | 56,953 | 57,149 | +301 | +0.5295% | +196 | +0.3441% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,504 | 76,605 | 76,369 | -135 | -0.1765% | -236 | -0.3081% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,591 | 73,696 | 73,892 | +301 | +0.4090% | +196 | +0.2660% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,293 | 74,446 | 74,497 | +204 | +0.2746% | +51 | +0.0685% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,483 | 108,660 | 108,856 | +373 | +0.3438% | +196 | +0.1804% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 94,106 | 94,246 | 94,297 | +191 | +0.2030% | +51 | +0.0541% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,620 | 149,717 | 149,915 | +295 | +0.1972% | +198 | +0.1322% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 151,245 | 150,428 | 150,626 | -619 | -0.4093% | +198 | +0.1316% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 161,271 | 161,564 | 160,600 | -671 | -0.4161% | -964 | -0.5967% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,632 | 201,985 | 200,586 | -1,046 | -0.5188% | -1,399 | -0.6926% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,660 | 211,000 | 209,601 | -1,059 | -0.5027% | -1,399 | -0.6630% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 170,257 | 170,537 | 169,573 | -684 | -0.4017% | -964 | -0.5653% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 199,495 | 198,367 | 197,347 | -2,148 | -1.0767% | -1,020 | -0.5142% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 215,387 | 213,254 | 211,799 | -3,588 | -1.6658% | -1,455 | -0.6823% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 810,225 | 811,273 | 806,684 | -3,541 | -0.4370% | -4,589 | -0.5657% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 39,851 | 38,577 | -1,274 | -3.1969% | -1,274 | -3.1969% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,570 | 36,646 | +76 | +0.2078% | +76 | +0.2078% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,176 | 754,349 | +173 | +0.0229% | +173 | +0.0229% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,823 | +182 | +0.0274% | +182 | +0.0274% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 48,640 | 48,640 | 47,366 | -1,274 | -2.6192% | -1,274 | -2.6192% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 39,912 | 39,912 | 38,638 | -1,274 | -3.1920% | -1,274 | -3.1920% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 39,561 | 39,561 | 38,282 | -1,279 | -3.2330% | -1,279 | -3.2330% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,410 | 355,763 | 355,959 | +549 | +0.1545% | +196 | +0.0551% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 228,250 | 228,517 | 228,713 | +463 | +0.2028% | +196 | +0.0858% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 91,146 | 91,317 | 91,513 | +367 | +0.4027% | +196 | +0.2146% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,334 | 119,503 | 119,699 | +365 | +0.3059% | +196 | +0.1640% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,584 | 135,765 | 135,961 | +377 | +0.2781% | +196 | +0.1444% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,126 | 357,463 | 357,659 | +533 | +0.1492% | +196 | +0.0548% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,276 | 65,381 | 65,577 | +301 | +0.4611% | +196 | +0.2998% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,380 | 356,733 | 356,929 | +549 | +0.1540% | +196 | +0.0549% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 227,641 | 227,908 | 228,104 | +463 | +0.2034% | +196 | +0.0860% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,225 | 91,396 | 91,592 | +367 | +0.4023% | +196 | +0.2145% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,712 | 118,881 | 119,077 | +365 | +0.3075% | +196 | +0.1649% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 136,152 | 136,333 | 136,529 | +377 | +0.2769% | +196 | +0.1438% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,046 | 357,383 | 357,579 | +533 | +0.1493% | +196 | +0.0548% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,321 | 64,426 | 64,622 | +301 | +0.4680% | +196 | +0.3042% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,151 | 56,256 | 56,452 | +301 | +0.5361% | +196 | +0.3484% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 75,591 | 75,692 | 75,456 | -135 | -0.1786% | -236 | -0.3118% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,053 | 74,206 | 74,257 | +204 | +0.2755% | +51 | +0.0687% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,139 | 108,316 | 108,512 | +373 | +0.3449% | +196 | +0.1810% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,531 | 93,671 | 93,722 | +191 | +0.2042% | +51 | +0.0544% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,656 | 124,958 | 125,111 | -545 | -0.4337% | +153 | +0.1224% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,414 | 56,519 | 56,715 | +301 | +0.5336% | +196 | +0.3468% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,070 | 76,171 | 75,935 | -135 | -0.1775% | -236 | -0.3098% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,157 | 73,262 | 73,458 | +301 | +0.4114% | +196 | +0.2675% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,859 | 74,012 | 74,063 | +204 | +0.2762% | +51 | +0.0689% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,049 | 108,226 | 108,422 | +373 | +0.3452% | +196 | +0.1811% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,672 | 93,812 | 93,863 | +191 | +0.2039% | +51 | +0.0544% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,458 | 149,555 | 149,753 | +295 | +0.1974% | +198 | +0.1324% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 151,082 | 150,265 | 150,463 | -619 | -0.4097% | +198 | +0.1318% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 160,852 | 161,145 | 160,181 | -671 | -0.4172% | -964 | -0.5982% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,198 | 201,551 | 200,152 | -1,046 | -0.5199% | -1,399 | -0.6941% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,226 | 210,566 | 209,167 | -1,059 | -0.5037% | -1,399 | -0.6644% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 169,838 | 170,118 | 169,154 | -684 | -0.4027% | -964 | -0.5667% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 199,333 | 198,205 | 197,185 | -2,148 | -1.0776% | -1,020 | -0.5146% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 215,224 | 213,091 | 211,636 | -3,588 | -1.6671% | -1,455 | -0.6828% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 784,770 | 785,818 | 781,229 | -3,541 | -0.4512% | -4,589 | -0.5840% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 117,210 | 117,210 | 115,266 | -1,944 | -1.6586% | -1,944 | -1.6586% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 131,666 | 131,906 | 131,232 | -434 | -0.3296% | -674 | -0.5110% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 220,505 | 217,045 | 215,002 | -5,503 | -2.4956% | -2,043 | -0.9413% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 658,666 | 658,666 | 658,450 | -216 | -0.0328% | -216 | -0.0328% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 681,103 | 682,061 | 677,618 | -3,485 | -0.5117% | -4,443 | -0.6514% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 772,290 | 770,204 | 770,143 | -2,147 | -0.2780% | -61 | -0.0079% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 39,917 | 39,917 | 38,643 | -1,274 | -3.1916% | -1,274 | -3.1916% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,636 | 36,636 | 36,712 | +76 | +0.2074% | +76 | +0.2074% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 754,198 | 754,198 | 754,371 | +173 | +0.0229% | +173 | +0.0229% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,641 | 664,823 | +182 | +0.0274% | +182 | +0.0274% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 48,706 | 48,706 | 47,432 | -1,274 | -2.6157% | -1,274 | -2.6157% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 40,022 | 40,022 | 38,748 | -1,274 | -3.1832% | -1,274 | -3.1832% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 39,627 | 39,627 | 38,348 | -1,279 | -3.2276% | -1,279 | -3.2276% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 355,467 | 355,820 | 356,016 | +549 | +0.1544% | +196 | +0.0551% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 228,373 | 228,640 | 228,836 | +463 | +0.2027% | +196 | +0.0857% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,225 | 91,396 | 91,592 | +367 | +0.4023% | +196 | +0.2145% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,567 | 119,736 | 119,932 | +365 | +0.3053% | +196 | +0.1637% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,663 | 135,844 | 136,040 | +377 | +0.2779% | +196 | +0.1443% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 357,183 | 357,520 | 357,716 | +533 | +0.1492% | +196 | +0.0548% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,399 | 65,504 | 65,700 | +301 | +0.4603% | +196 | +0.2992% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 356,635 | 356,988 | 357,184 | +549 | +0.1539% | +196 | +0.0549% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 227,720 | 227,987 | 228,183 | +463 | +0.2033% | +196 | +0.0860% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,326 | 91,497 | 91,693 | +367 | +0.4019% | +196 | +0.2142% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,835 | 119,004 | 119,200 | +365 | +0.3071% | +196 | +0.1647% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 136,319 | 136,500 | 136,696 | +377 | +0.2766% | +196 | +0.1436% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 357,103 | 357,440 | 357,636 | +533 | +0.1493% | +196 | +0.0548% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,378 | 64,483 | 64,679 | +301 | +0.4676% | +196 | +0.3040% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,245 | 56,350 | 56,546 | +301 | +0.5352% | +196 | +0.3478% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,685 | 75,786 | 75,550 | -135 | -0.1784% | -236 | -0.3114% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,235 | 74,388 | 74,439 | +204 | +0.2748% | +51 | +0.0686% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,233 | 108,410 | 108,606 | +373 | +0.3446% | +196 | +0.1808% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,669 | 93,809 | 93,860 | +191 | +0.2039% | +51 | +0.0544% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 125,725 | 125,027 | 125,180 | -545 | -0.4335% | +153 | +0.1224% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,527 | 56,632 | 56,828 | +301 | +0.5325% | +196 | +0.3461% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,183 | 76,284 | 76,048 | -135 | -0.1772% | -236 | -0.3094% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,226 | 73,331 | 73,527 | +301 | +0.4111% | +196 | +0.2673% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,972 | 74,125 | 74,176 | +204 | +0.2758% | +51 | +0.0688% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,118 | 108,295 | 108,491 | +373 | +0.3450% | +196 | +0.1810% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,807 | 93,947 | 93,998 | +191 | +0.2036% | +51 | +0.0543% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,552 | 149,649 | 149,847 | +295 | +0.1973% | +198 | +0.1323% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 151,217 | 150,400 | 150,598 | -619 | -0.4093% | +198 | +0.1316% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 160,968 | 161,261 | 160,297 | -671 | -0.4169% | -964 | -0.5978% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 201,333 | 201,686 | 200,287 | -1,046 | -0.5195% | -1,399 | -0.6937% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 210,427 | 210,767 | 209,368 | -1,059 | -0.5033% | -1,399 | -0.6638% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 169,976 | 170,256 | 169,292 | -684 | -0.4024% | -964 | -0.5662% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 199,405 | 198,277 | 197,257 | -2,148 | -1.0772% | -1,020 | -0.5144% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 215,315 | 213,182 | 211,727 | -3,588 | -1.6664% | -1,455 | -0.6825% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 98,283 | 98,384 | 98,148 | -135 | -0.1374% | -236 | -0.2399% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 150,262 | 149,553 | 149,420 | -842 | -0.5604% | -133 | -0.0889% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 350,806 | 350,943 | 348,591 | -2,215 | -0.6314% | -2,352 | -0.6702% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 97,555 | 97,656 | 97,420 | -135 | -0.1384% | -236 | -0.2417% | functional budget check |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 607,866 | 604,933 | 602,672 | -5,194 | -0.8545% | -2,261 | -0.3738% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,967 | 98,068 | 97,832 | -135 | -0.1378% | -236 | -0.2406% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,843 | 98,944 | 98,708 | -135 | -0.1366% | -236 | -0.2385% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 614,536 | 611,603 | 609,351 | -5,185 | -0.8437% | -2,252 | -0.3682% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 97,267 | 97,368 | 97,132 | -135 | -0.1388% | -236 | -0.2424% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 784,864 | 785,912 | 781,323 | -3,541 | -0.4512% | -4,589 | -0.5839% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 43,634 | 43,634 | 42,373 | -1,261 | -2.8899% | -1,261 | -2.8899% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,073 | 37,073 | 37,148 | +75 | +0.2023% | +75 | +0.2023% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 776,242 | 776,234 | 774,278 | -1,964 | -0.2530% | -1,956 | -0.2520% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 685,850 | 685,850 | 683,903 | -1,947 | -0.2839% | -1,947 | -0.2839% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 52,964 | 52,958 | 51,695 | -1,269 | -2.3960% | -1,263 | -2.3849% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 43,697 | 43,697 | 42,434 | -1,263 | -2.8904% | -1,263 | -2.8904% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 43,885 | 43,879 | 42,613 | -1,272 | -2.8985% | -1,266 | -2.8852% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 378,882 | 370,676 | 368,814 | -10,068 | -2.6573% | -1,862 | -0.5023% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 278,752 | 273,430 | 271,568 | -7,184 | -2.5772% | -1,862 | -0.6810% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 170,245 | 168,230 | 166,368 | -3,877 | -2.2773% | -1,862 | -1.1068% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 129,932 | 128,888 | 126,942 | -2,990 | -2.3012% | -1,946 | -1.5098% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 146,974 | 145,546 | 143,606 | -3,368 | -2.2916% | -1,940 | -1.3329% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 378,812 | 372,392 | 370,530 | -8,282 | -2.1863% | -1,862 | -0.5000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 144,198 | 144,339 | 142,489 | -1,709 | -1.1852% | -1,850 | -1.2817% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 380,830 | 372,616 | 370,754 | -10,076 | -2.6458% | -1,862 | -0.4997% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 279,121 | 273,791 | 271,929 | -7,192 | -2.5767% | -1,862 | -0.6801% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 171,302 | 169,279 | 167,417 | -3,885 | -2.2679% | -1,862 | -1.1000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 130,288 | 129,236 | 127,290 | -2,998 | -2.3011% | -1,946 | -1.5058% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 148,520 | 147,084 | 145,144 | -3,376 | -2.2731% | -1,940 | -1.3190% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 379,710 | 373,282 | 371,420 | -8,290 | -2.1832% | -1,862 | -0.4988% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 144,221 | 144,354 | 142,504 | -1,717 | -1.1905% | -1,850 | -1.2816% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 72,309 | 72,442 | 70,505 | -1,804 | -2.4948% | -1,937 | -2.6739% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 225,703 | 225,832 | 223,645 | -2,058 | -0.9118% | -2,187 | -0.9684% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 83,538 | 83,738 | 81,647 | -1,891 | -2.2636% | -2,091 | -2.4971% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 122,709 | 120,259 | 118,307 | -4,402 | -3.5873% | -1,952 | -1.6232% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 105,209 | 103,169 | 101,066 | -4,143 | -3.9379% | -2,103 | -2.0384% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 138,240 | 135,336 | 133,335 | -4,905 | -3.5482% | -2,001 | -1.4785% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 71,594 | 71,735 | 69,798 | -1,796 | -2.5086% | -1,937 | -2.7002% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 225,325 | 225,462 | 223,275 | -2,050 | -0.9098% | -2,187 | -0.9700% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 90,535 | 90,676 | 88,742 | -1,793 | -1.9804% | -1,934 | -2.1329% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 82,445 | 82,653 | 80,562 | -1,883 | -2.2839% | -2,091 | -2.5299% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 121,641 | 119,199 | 117,247 | -4,394 | -3.6123% | -1,952 | -1.6376% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 104,451 | 102,419 | 100,316 | -4,135 | -3.9588% | -2,103 | -2.0533% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 140,948 | 138,783 | 138,969 | -1,979 | -1.4041% | +186 | +0.1340% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 142,572 | 139,493 | 139,679 | -2,893 | -2.0292% | +186 | +0.1333% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 177,783 | 178,123 | 172,722 | -5,061 | -2.8467% | -5,401 | -3.0322% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 220,370 | 220,778 | 214,963 | -5,407 | -2.4536% | -5,815 | -2.6339% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 223,200 | 221,153 | 217,630 | -5,570 | -2.4955% | -3,523 | -1.5930% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 182,769 | 181,248 | 178,151 | -4,618 | -2.5267% | -3,097 | -1.7087% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 234,701 | 230,967 | 225,695 | -9,006 | -3.8372% | -5,272 | -2.2826% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 245,737 | 240,990 | 235,283 | -10,454 | -4.2541% | -5,707 | -2.3681% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 809,297 | 795,461 | 788,721 | -20,576 | -2.5425% | -6,740 | -0.8473% | - |

## 4. Reused branch metadata

| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,804 | 124,998 | 125,001 | +197 | +0.1578% | +3 | +0.0024% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,293 | 99,487 | 99,490 | +197 | +0.1984% | +3 | +0.0030% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,513 | 99,707 | 99,710 | +197 | +0.1980% | +3 | +0.0030% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,111 | 150,968 | 150,971 | +860 | +0.5729% | +3 | +0.0020% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 112,061 | 112,320 | 112,324 | +263 | +0.2347% | +4 | +0.0036% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 157,922 | 155,088 | 155,457 | -2,465 | -1.5609% | +369 | +0.2379% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 166,859 | 164,175 | 164,708 | -2,151 | -1.2891% | +533 | +0.3247% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 163,201 | 162,356 | 162,391 | -810 | -0.4963% | +35 | +0.0216% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 371,112 | 368,624 | 364,843 | -6,269 | -1.6892% | -3,781 | -1.0257% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 370,805 | 368,317 | 364,536 | -6,269 | -1.6906% | -3,781 | -1.0266% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 164,094 | 163,270 | 163,305 | -789 | -0.4808% | +35 | +0.0214% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 159,811 | 155,989 | 156,358 | -3,453 | -2.1607% | +369 | +0.2366% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 169,232 | 165,560 | 166,093 | -3,139 | -1.8549% | +533 | +0.3219% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 164,739 | 162,977 | 163,012 | -1,727 | -1.0483% | +35 | +0.0215% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 373,318 | 369,842 | 366,061 | -7,257 | -1.9439% | -3,781 | -1.0223% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 373,297 | 369,821 | 366,040 | -7,257 | -1.9440% | -3,781 | -1.0224% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 165,214 | 163,473 | 163,508 | -1,706 | -1.0326% | +35 | +0.0214% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 38,577 | 38,577 | -1,274 | -3.1969% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,646 | 36,646 | +76 | +0.2078% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,349 | 748,579 | -5,597 | -0.7421% | -5,770 | -0.7649% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,823 | 659,053 | -5,588 | -0.8408% | -5,770 | -0.8679% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 48,640 | 47,366 | 47,366 | -1,274 | -2.6192% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 39,912 | 38,638 | 38,638 | -1,274 | -3.1920% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 39,561 | 38,282 | 38,282 | -1,279 | -3.2330% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,844 | 356,393 | 353,826 | -2,018 | -0.5671% | -2,567 | -0.7203% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 253,720 | 254,183 | 252,846 | -874 | -0.3445% | -1,337 | -0.5260% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,616 | 116,983 | 116,958 | +342 | +0.2933% | -25 | -0.0214% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,768 | 120,133 | 119,808 | +40 | +0.0334% | -325 | -0.2705% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 136,018 | 136,395 | 135,906 | -112 | -0.0823% | -489 | -0.3585% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,560 | 358,093 | 355,472 | -2,088 | -0.5840% | -2,621 | -0.7319% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,746 | 91,047 | 91,050 | +304 | +0.3350% | +3 | +0.0033% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,799 | 357,348 | 354,781 | -2,018 | -0.5656% | -2,567 | -0.7183% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 253,096 | 253,559 | 252,222 | -874 | -0.3453% | -1,337 | -0.5273% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,680 | 117,047 | 117,022 | +342 | +0.2931% | -25 | -0.0214% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 119,131 | 119,496 | 119,171 | +40 | +0.0336% | -325 | -0.2720% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,571 | 136,948 | 136,459 | -112 | -0.0820% | -489 | -0.3571% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,465 | 357,998 | 355,377 | -2,088 | -0.5841% | -2,621 | -0.7321% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,776 | 90,077 | 90,080 | +304 | +0.3386% | +3 | +0.0033% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,570 | 56,871 | 56,874 | +304 | +0.5374% | +3 | +0.0053% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 101,046 | 100,911 | 100,914 | -132 | -0.1306% | +3 | +0.0030% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,472 | 74,676 | 74,679 | +207 | +0.2780% | +3 | +0.0040% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,558 | 108,931 | 108,824 | +266 | +0.2450% | -107 | -0.0982% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,950 | 94,141 | 94,144 | +194 | +0.2065% | +3 | +0.0032% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 126,090 | 125,545 | 125,548 | -542 | -0.4299% | +3 | +0.0024% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,848 | 57,149 | 57,152 | +304 | +0.5348% | +3 | +0.0052% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,504 | 76,369 | 76,372 | -132 | -0.1725% | +3 | +0.0039% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,591 | 73,892 | 73,895 | +304 | +0.4131% | +3 | +0.0041% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,293 | 74,497 | 74,500 | +207 | +0.2786% | +3 | +0.0040% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,483 | 108,856 | 108,749 | +266 | +0.2452% | -107 | -0.0983% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 94,106 | 94,297 | 94,300 | +194 | +0.2062% | +3 | +0.0032% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,620 | 149,915 | 149,918 | +298 | +0.1992% | +3 | +0.0020% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 151,245 | 150,626 | 150,629 | -616 | -0.4073% | +3 | +0.0020% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 161,271 | 160,600 | 159,099 | -2,172 | -1.3468% | -1,501 | -0.9346% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,632 | 200,586 | 198,389 | -3,243 | -1.6084% | -2,197 | -1.0953% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,660 | 209,601 | 207,284 | -3,376 | -1.6026% | -2,317 | -1.1054% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 170,257 | 169,573 | 167,952 | -2,305 | -1.3538% | -1,621 | -0.9559% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 199,495 | 197,347 | 196,639 | -2,856 | -1.4316% | -708 | -0.3588% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 215,387 | 211,799 | 210,773 | -4,614 | -2.1422% | -1,026 | -0.4844% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 810,225 | 806,684 | 796,764 | -13,461 | -1.6614% | -9,920 | -1.2297% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 38,577 | 38,577 | -1,274 | -3.1969% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,646 | 36,646 | +76 | +0.2078% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 754,349 | 748,579 | -5,597 | -0.7421% | -5,770 | -0.7649% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,823 | 659,053 | -5,588 | -0.8408% | -5,770 | -0.8679% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 48,640 | 47,366 | 47,366 | -1,274 | -2.6192% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 39,912 | 38,638 | 38,638 | -1,274 | -3.1920% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 39,561 | 38,282 | 38,282 | -1,279 | -3.2330% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,410 | 355,959 | 353,392 | -2,018 | -0.5678% | -2,567 | -0.7212% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 228,250 | 228,713 | 227,376 | -874 | -0.3829% | -1,337 | -0.5846% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 91,146 | 91,513 | 91,488 | +342 | +0.3752% | -25 | -0.0273% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,334 | 119,699 | 119,374 | +40 | +0.0335% | -325 | -0.2715% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,584 | 135,961 | 135,472 | -112 | -0.0826% | -489 | -0.3597% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,126 | 357,659 | 355,038 | -2,088 | -0.5847% | -2,621 | -0.7328% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,276 | 65,577 | 65,580 | +304 | +0.4657% | +3 | +0.0046% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,380 | 356,929 | 354,362 | -2,018 | -0.5662% | -2,567 | -0.7192% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 227,641 | 228,104 | 226,767 | -874 | -0.3839% | -1,337 | -0.5861% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,225 | 91,592 | 91,567 | +342 | +0.3749% | -25 | -0.0273% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,712 | 119,077 | 118,752 | +40 | +0.0337% | -325 | -0.2729% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 136,152 | 136,529 | 136,040 | -112 | -0.0823% | -489 | -0.3582% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,046 | 357,579 | 354,958 | -2,088 | -0.5848% | -2,621 | -0.7330% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,321 | 64,622 | 64,625 | +304 | +0.4726% | +3 | +0.0046% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,151 | 56,452 | 56,455 | +304 | +0.5414% | +3 | +0.0053% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 75,591 | 75,456 | 75,459 | -132 | -0.1746% | +3 | +0.0040% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,053 | 74,257 | 74,260 | +207 | +0.2795% | +3 | +0.0040% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,139 | 108,512 | 108,405 | +266 | +0.2460% | -107 | -0.0986% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,531 | 93,722 | 93,725 | +194 | +0.2074% | +3 | +0.0032% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,656 | 125,111 | 125,114 | -542 | -0.4313% | +3 | +0.0024% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,414 | 56,715 | 56,718 | +304 | +0.5389% | +3 | +0.0053% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,070 | 75,935 | 75,938 | -132 | -0.1735% | +3 | +0.0040% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,157 | 73,458 | 73,461 | +304 | +0.4155% | +3 | +0.0041% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,859 | 74,063 | 74,066 | +207 | +0.2803% | +3 | +0.0041% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,049 | 108,422 | 108,315 | +266 | +0.2462% | -107 | -0.0987% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,672 | 93,863 | 93,866 | +194 | +0.2071% | +3 | +0.0032% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,458 | 149,753 | 149,756 | +298 | +0.1994% | +3 | +0.0020% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 151,082 | 150,463 | 150,466 | -616 | -0.4077% | +3 | +0.0020% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 160,852 | 160,181 | 158,680 | -2,172 | -1.3503% | -1,501 | -0.9371% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,198 | 200,152 | 197,955 | -3,243 | -1.6118% | -2,197 | -1.0977% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,226 | 209,167 | 206,850 | -3,376 | -1.6059% | -2,317 | -1.1077% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 169,838 | 169,154 | 167,533 | -2,305 | -1.3572% | -1,621 | -0.9583% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 199,333 | 197,185 | 196,477 | -2,856 | -1.4328% | -708 | -0.3591% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 215,224 | 211,636 | 210,610 | -4,614 | -2.1438% | -1,026 | -0.4848% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 784,770 | 781,229 | 771,309 | -13,461 | -1.7153% | -9,920 | -1.2698% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 117,210 | 115,266 | 114,766 | -2,444 | -2.0851% | -500 | -0.4338% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 131,666 | 131,232 | 130,075 | -1,591 | -1.2084% | -1,157 | -0.8816% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 220,505 | 215,002 | 214,811 | -5,694 | -2.5823% | -191 | -0.0888% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 658,666 | 658,450 | 653,318 | -5,348 | -0.8119% | -5,132 | -0.7794% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 681,103 | 677,618 | 668,418 | -12,685 | -1.8624% | -9,200 | -1.3577% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 772,290 | 770,143 | 768,496 | -3,794 | -0.4913% | -1,647 | -0.2139% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 39,917 | 38,643 | 38,643 | -1,274 | -3.1916% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,636 | 36,712 | 36,712 | +76 | +0.2074% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 754,198 | 754,371 | 748,601 | -5,597 | -0.7421% | -5,770 | -0.7649% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 664,823 | 659,053 | -5,588 | -0.8408% | -5,770 | -0.8679% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 48,706 | 47,432 | 47,432 | -1,274 | -2.6157% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 40,022 | 38,748 | 38,748 | -1,274 | -3.1832% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 39,627 | 38,348 | 38,348 | -1,279 | -3.2276% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 355,467 | 356,016 | 353,449 | -2,018 | -0.5677% | -2,567 | -0.7210% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 228,373 | 228,836 | 227,499 | -874 | -0.3827% | -1,337 | -0.5843% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,225 | 91,592 | 91,567 | +342 | +0.3749% | -25 | -0.0273% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,567 | 119,932 | 119,607 | +40 | +0.0335% | -325 | -0.2710% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,663 | 136,040 | 135,551 | -112 | -0.0826% | -489 | -0.3595% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 357,183 | 357,716 | 355,095 | -2,088 | -0.5846% | -2,621 | -0.7327% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,399 | 65,700 | 65,703 | +304 | +0.4648% | +3 | +0.0046% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 356,635 | 357,184 | 354,617 | -2,018 | -0.5658% | -2,567 | -0.7187% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 227,720 | 228,183 | 226,846 | -874 | -0.3838% | -1,337 | -0.5859% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,326 | 91,693 | 91,668 | +342 | +0.3745% | -25 | -0.0273% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,835 | 119,200 | 118,875 | +40 | +0.0337% | -325 | -0.2727% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 136,319 | 136,696 | 136,207 | -112 | -0.0822% | -489 | -0.3577% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 357,103 | 357,636 | 355,015 | -2,088 | -0.5847% | -2,621 | -0.7329% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,378 | 64,679 | 64,682 | +304 | +0.4722% | +3 | +0.0046% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,245 | 56,546 | 56,549 | +304 | +0.5405% | +3 | +0.0053% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,685 | 75,550 | 75,553 | -132 | -0.1744% | +3 | +0.0040% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,235 | 74,439 | 74,442 | +207 | +0.2788% | +3 | +0.0040% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,233 | 108,606 | 108,499 | +266 | +0.2458% | -107 | -0.0985% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,669 | 93,860 | 93,863 | +194 | +0.2071% | +3 | +0.0032% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 125,725 | 125,180 | 125,183 | -542 | -0.4311% | +3 | +0.0024% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,527 | 56,828 | 56,831 | +304 | +0.5378% | +3 | +0.0053% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,183 | 76,048 | 76,051 | -132 | -0.1733% | +3 | +0.0039% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,226 | 73,527 | 73,530 | +304 | +0.4152% | +3 | +0.0041% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,972 | 74,176 | 74,179 | +207 | +0.2798% | +3 | +0.0040% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,118 | 108,491 | 108,384 | +266 | +0.2460% | -107 | -0.0986% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,807 | 93,998 | 94,001 | +194 | +0.2068% | +3 | +0.0032% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,552 | 149,847 | 149,850 | +298 | +0.1993% | +3 | +0.0020% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 151,217 | 150,598 | 150,601 | -616 | -0.4074% | +3 | +0.0020% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 160,968 | 160,297 | 158,796 | -2,172 | -1.3493% | -1,501 | -0.9364% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 201,333 | 200,287 | 198,090 | -3,243 | -1.6108% | -2,197 | -1.0969% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 210,427 | 209,368 | 207,051 | -3,376 | -1.6044% | -2,317 | -1.1067% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 169,976 | 169,292 | 167,671 | -2,305 | -1.3561% | -1,621 | -0.9575% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 199,405 | 197,257 | 196,549 | -2,856 | -1.4323% | -708 | -0.3589% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 215,315 | 211,727 | 210,701 | -4,614 | -2.1429% | -1,026 | -0.4846% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 98,283 | 98,148 | 98,151 | -132 | -0.1343% | +3 | +0.0031% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 150,262 | 149,420 | 149,423 | -839 | -0.5584% | +3 | +0.0020% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 350,806 | 348,591 | 348,595 | -2,211 | -0.6303% | +4 | +0.0011% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 97,555 | 97,420 | 97,423 | -132 | -0.1353% | +3 | +0.0031% | functional budget check |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 607,866 | 602,672 | 602,675 | -5,191 | -0.8540% | +3 | +0.0005% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,967 | 97,832 | 97,835 | -132 | -0.1347% | +3 | +0.0031% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,843 | 98,708 | 98,711 | -132 | -0.1335% | +3 | +0.0030% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 614,536 | 609,351 | 609,354 | -5,182 | -0.8432% | +3 | +0.0005% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 97,267 | 97,132 | 97,135 | -132 | -0.1357% | +3 | +0.0031% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 784,864 | 781,323 | 771,403 | -13,461 | -1.7151% | -9,920 | -1.2696% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 43,634 | 42,373 | 42,373 | -1,261 | -2.8899% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,073 | 37,148 | 37,148 | +75 | +0.2023% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 776,242 | 774,278 | 768,508 | -7,734 | -0.9963% | -5,770 | -0.7452% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 685,850 | 683,903 | 678,133 | -7,717 | -1.1252% | -5,770 | -0.8437% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 52,964 | 51,695 | 51,695 | -1,269 | -2.3960% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 43,697 | 42,434 | 42,434 | -1,263 | -2.8904% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 43,885 | 42,613 | 42,613 | -1,272 | -2.8985% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 378,882 | 368,814 | 366,246 | -12,636 | -3.3351% | -2,568 | -0.6963% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 278,752 | 271,568 | 270,230 | -8,522 | -3.0572% | -1,338 | -0.4927% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 170,245 | 166,368 | 166,342 | -3,903 | -2.2926% | -26 | -0.0156% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 129,932 | 126,942 | 126,617 | -3,315 | -2.5513% | -325 | -0.2560% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 146,974 | 143,606 | 143,117 | -3,857 | -2.6243% | -489 | -0.3405% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 378,812 | 370,530 | 367,909 | -10,903 | -2.8782% | -2,621 | -0.7074% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 144,198 | 142,489 | 142,492 | -1,706 | -1.1831% | +3 | +0.0021% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 380,830 | 370,754 | 368,186 | -12,644 | -3.3201% | -2,568 | -0.6926% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 279,121 | 271,929 | 270,591 | -8,530 | -3.0560% | -1,338 | -0.4920% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 171,302 | 167,417 | 167,391 | -3,911 | -2.2831% | -26 | -0.0155% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 130,288 | 127,290 | 126,965 | -3,323 | -2.5505% | -325 | -0.2553% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 148,520 | 145,144 | 144,655 | -3,865 | -2.6023% | -489 | -0.3369% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 379,710 | 371,420 | 368,799 | -10,911 | -2.8735% | -2,621 | -0.7057% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 144,221 | 142,504 | 142,507 | -1,714 | -1.1885% | +3 | +0.0021% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 72,309 | 70,505 | 70,508 | -1,801 | -2.4907% | +3 | +0.0043% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 225,703 | 223,645 | 223,649 | -2,054 | -0.9100% | +4 | +0.0018% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 83,538 | 81,647 | 81,650 | -1,888 | -2.2600% | +3 | +0.0037% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 122,709 | 118,307 | 118,199 | -4,510 | -3.6754% | -108 | -0.0913% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 105,209 | 101,066 | 101,069 | -4,140 | -3.9350% | +3 | +0.0030% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 138,240 | 133,335 | 133,338 | -4,902 | -3.5460% | +3 | +0.0022% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 71,594 | 69,798 | 69,801 | -1,793 | -2.5044% | +3 | +0.0043% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 225,325 | 223,275 | 223,279 | -2,046 | -0.9080% | +4 | +0.0018% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 90,535 | 88,742 | 88,745 | -1,790 | -1.9771% | +3 | +0.0034% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 82,445 | 80,562 | 80,565 | -1,880 | -2.2803% | +3 | +0.0037% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 121,641 | 117,247 | 117,139 | -4,502 | -3.7011% | -108 | -0.0921% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 104,451 | 100,316 | 100,319 | -4,132 | -3.9559% | +3 | +0.0030% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 140,948 | 138,969 | 138,972 | -1,976 | -1.4019% | +3 | +0.0022% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 142,572 | 139,679 | 139,682 | -2,890 | -2.0270% | +3 | +0.0021% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 177,783 | 172,722 | 171,221 | -6,562 | -3.6910% | -1,501 | -0.8690% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 220,370 | 214,963 | 212,766 | -7,604 | -3.4506% | -2,197 | -1.0220% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 223,200 | 217,630 | 215,313 | -7,887 | -3.5336% | -2,317 | -1.0647% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 182,769 | 178,151 | 176,530 | -6,239 | -3.4136% | -1,621 | -0.9099% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 234,701 | 225,695 | 224,990 | -9,711 | -4.1376% | -705 | -0.3124% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 245,737 | 235,283 | 234,260 | -11,477 | -4.6704% | -1,023 | -0.4348% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 809,297 | 788,721 | 778,800 | -30,497 | -3.7683% | -9,921 | -1.2579% | - |

## 5. Memory match buffer

| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorAndProtocolFeeFill() | 124,804 | 125,001 | 124,674 | -130 | -0.1042% | -327 | -0.2616% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillAskFullyMatchesSingleBid() | 99,293 | 99,490 | 99,163 | -130 | -0.1309% | -327 | -0.3287% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillBidFullyMatchesSingleAsk() | 99,513 | 99,710 | 99,383 | -130 | -0.1306% | -327 | -0.3280% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorFillRestBidEmptyBook() | 150,111 | 150,971 | 150,971 | +860 | +0.5729% | 0 | 0.0000% | - |
| DeepstateV1IntegratorFeeGasTest:testGas_IntegratorRouteNetsRepeatedFeeToken() | 112,061 | 112,324 | 111,668 | -393 | -0.3507% | -656 | -0.5840% | - |
| OpportunityGasProbe:testOpportunity_RestAsk16Orders() | 157,922 | 155,457 | 155,250 | -2,672 | -1.6920% | -207 | -0.1332% | - |
| OpportunityGasProbe:testOpportunity_RestAsk64Orders() | 166,859 | 164,708 | 164,501 | -2,358 | -1.4132% | -207 | -0.1257% | - |
| OpportunityGasProbe:testOpportunity_RestAskDifferentTickLeftNonceComb() | 163,201 | 162,391 | 162,184 | -1,017 | -0.6232% | -207 | -0.1275% | - |
| OpportunityGasProbe:testOpportunity_RestAskDirtyLeftNonceComb() | 371,112 | 364,843 | 364,636 | -6,476 | -1.7450% | -207 | -0.0567% | - |
| OpportunityGasProbe:testOpportunity_RestAskLeftNonceComb() | 370,805 | 364,536 | 364,329 | -6,476 | -1.7465% | -207 | -0.0568% | - |
| OpportunityGasProbe:testOpportunity_RestAskWorseTickLeftNonceComb() | 164,094 | 163,305 | 163,098 | -996 | -0.6070% | -207 | -0.1268% | - |
| OpportunityGasProbe:testOpportunity_RestBid16Orders() | 159,811 | 156,358 | 156,151 | -3,660 | -2.2902% | -207 | -0.1324% | - |
| OpportunityGasProbe:testOpportunity_RestBid64Orders() | 169,232 | 166,093 | 165,886 | -3,346 | -1.9772% | -207 | -0.1246% | - |
| OpportunityGasProbe:testOpportunity_RestBidDifferentTickLeftNonceComb() | 164,739 | 163,012 | 162,805 | -1,934 | -1.1740% | -207 | -0.1270% | - |
| OpportunityGasProbe:testOpportunity_RestBidDirtyLeftNonceComb() | 373,318 | 366,061 | 365,854 | -7,464 | -1.9994% | -207 | -0.0565% | - |
| OpportunityGasProbe:testOpportunity_RestBidLeftNonceComb() | 373,297 | 366,040 | 365,833 | -7,464 | -1.9995% | -207 | -0.0566% | - |
| OpportunityGasProbe:testOpportunity_RestBidWorseTickLeftNonceComb() | 165,214 | 163,508 | 163,301 | -1,913 | -1.1579% | -207 | -0.1266% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 38,577 | 38,577 | -1,274 | -3.1969% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,646 | 36,646 | +76 | +0.2078% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 748,579 | 748,579 | -5,597 | -0.7421% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 659,053 | 659,053 | -5,588 | -0.8408% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelPartialBid() | 48,640 | 47,366 | 47,366 | -1,274 | -2.6192% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledAsk() | 39,912 | 38,638 | 38,638 | -1,274 | -3.1920% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_CancelUnfilledBid() | 39,561 | 38,282 | 38,282 | -1,279 | -3.2330% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,844 | 353,826 | 353,328 | -2,516 | -0.7071% | -498 | -0.1407% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskHalfNonceComb() | 253,720 | 252,846 | 252,348 | -1,372 | -0.5408% | -498 | -0.1970% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 116,616 | 116,958 | 116,460 | -156 | -0.1338% | -498 | -0.4258% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill16Orders() | 119,768 | 119,808 | 119,484 | -284 | -0.2371% | -324 | -0.2704% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFill64Orders() | 136,018 | 135,906 | 135,582 | -436 | -0.3205% | -324 | -0.2384% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,560 | 355,472 | 355,148 | -2,412 | -0.6746% | -324 | -0.0911% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyAskWholeNonceComb() | 90,746 | 91,050 | 90,726 | -20 | -0.0220% | -324 | -0.3558% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,799 | 354,781 | 354,283 | -2,516 | -0.7052% | -498 | -0.1404% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidHalfNonceComb() | 253,096 | 252,222 | 251,724 | -1,372 | -0.5421% | -498 | -0.1974% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 116,680 | 117,022 | 116,524 | -156 | -0.1337% | -498 | -0.4256% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill16Orders() | 119,131 | 119,171 | 118,847 | -284 | -0.2384% | -324 | -0.2719% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFill64Orders() | 136,571 | 136,459 | 136,135 | -436 | -0.3192% | -324 | -0.2374% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,465 | 355,377 | 355,053 | -2,412 | -0.6748% | -324 | -0.0912% | - |
| RadixMatchingEngineFeeGasTest:testGas_DirtyBidWholeNonceComb() | 89,776 | 90,080 | 89,756 | -20 | -0.0223% | -324 | -0.3597% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,570 | 56,874 | 56,550 | -20 | -0.0354% | -324 | -0.5697% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskConsumesFullDepthBidComb() | 101,046 | 100,914 | 100,397 | -649 | -0.6423% | -517 | -0.5123% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,472 | 74,679 | 74,352 | -120 | -0.1611% | -327 | -0.4379% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,558 | 108,824 | 108,326 | -232 | -0.2137% | -498 | -0.4576% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,950 | 94,144 | 93,817 | -133 | -0.1416% | -327 | -0.3473% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 126,090 | 125,548 | 125,221 | -869 | -0.6892% | -327 | -0.2605% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,848 | 57,152 | 56,828 | -20 | -0.0352% | -324 | -0.5669% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,504 | 76,372 | 75,855 | -649 | -0.8483% | -517 | -0.6769% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,591 | 73,895 | 73,571 | -20 | -0.0272% | -324 | -0.4385% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidFullyMatchesSingleAsk() | 74,293 | 74,500 | 74,173 | -120 | -0.1615% | -327 | -0.4389% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,483 | 108,749 | 108,251 | -232 | -0.2139% | -498 | -0.4579% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 94,106 | 94,300 | 93,973 | -133 | -0.1413% | -327 | -0.3468% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestAskEmptyBook() | 149,620 | 149,918 | 149,918 | +298 | +0.1992% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_FillRestBidEmptyBook() | 151,245 | 150,629 | 150,629 | -616 | -0.4073% | 0 | 0.0000% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 161,271 | 159,099 | 158,772 | -2,499 | -1.5496% | -327 | -0.2055% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,632 | 198,389 | 198,062 | -3,570 | -1.7706% | -327 | -0.1648% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,660 | 207,284 | 206,957 | -3,703 | -1.7578% | -327 | -0.1578% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookPartialFillsBid() | 170,257 | 167,952 | 167,625 | -2,632 | -1.5459% | -327 | -0.1947% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsAsk() | 199,495 | 196,639 | 196,386 | -3,109 | -1.5584% | -253 | -0.1287% | - |
| RadixMatchingEngineFeeGasTest:testGas_LargeRandomBookRestsBid() | 215,387 | 210,773 | 210,520 | -4,867 | -2.2597% | -253 | -0.1200% | - |
| RadixMatchingEngineFeeGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 810,225 | 796,764 | 796,263 | -13,962 | -1.7232% | -501 | -0.0629% | - |
| RadixMatchingEngineGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 39,851 | 38,577 | 38,577 | -1,274 | -3.1969% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFilledBidClaim() | 36,570 | 36,646 | 36,646 | +76 | +0.2078% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelFullDepthBidCombRightmost() | 754,176 | 748,579 | 748,579 | -5,597 | -0.7421% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 659,053 | 659,053 | -5,588 | -0.8408% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelPartialBid() | 48,640 | 47,366 | 47,366 | -1,274 | -2.6192% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledAsk() | 39,912 | 38,638 | 38,638 | -1,274 | -3.1920% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_CancelUnfilledBid() | 39,561 | 38,282 | 38,282 | -1,279 | -3.2330% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskCrossLeafNonceComb() | 355,410 | 353,392 | 352,894 | -2,516 | -0.7079% | -498 | -0.1409% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskHalfNonceComb() | 228,250 | 227,376 | 226,878 | -1,372 | -0.6011% | -498 | -0.2190% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 91,146 | 91,488 | 90,990 | -156 | -0.1712% | -498 | -0.5443% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill16Orders() | 119,334 | 119,374 | 119,050 | -284 | -0.2380% | -324 | -0.2714% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFill64Orders() | 135,584 | 135,472 | 135,148 | -436 | -0.3216% | -324 | -0.2392% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskSmallFillNonceComb() | 357,126 | 355,038 | 354,714 | -2,412 | -0.6754% | -324 | -0.0913% | - |
| RadixMatchingEngineGasTest:testGas_DirtyAskWholeNonceComb() | 65,276 | 65,580 | 65,256 | -20 | -0.0306% | -324 | -0.4941% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidCrossLeafNonceComb() | 356,380 | 354,362 | 353,864 | -2,516 | -0.7060% | -498 | -0.1405% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidHalfNonceComb() | 227,641 | 226,767 | 226,269 | -1,372 | -0.6027% | -498 | -0.2196% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 91,225 | 91,567 | 91,069 | -156 | -0.1710% | -498 | -0.5439% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill16Orders() | 118,712 | 118,752 | 118,428 | -284 | -0.2392% | -324 | -0.2728% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFill64Orders() | 136,152 | 136,040 | 135,716 | -436 | -0.3202% | -324 | -0.2382% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidSmallFillNonceComb() | 357,046 | 354,958 | 354,634 | -2,412 | -0.6755% | -324 | -0.0913% | - |
| RadixMatchingEngineGasTest:testGas_DirtyBidWholeNonceComb() | 64,321 | 64,625 | 64,301 | -20 | -0.0311% | -324 | -0.5014% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,151 | 56,455 | 56,131 | -20 | -0.0356% | -324 | -0.5739% | - |
| RadixMatchingEngineGasTest:testGas_FillAskConsumesFullDepthBidComb() | 75,591 | 75,459 | 74,942 | -649 | -0.8586% | -517 | -0.6851% | - |
| RadixMatchingEngineGasTest:testGas_FillAskFullyMatchesSingleBid() | 74,053 | 74,260 | 73,933 | -120 | -0.1620% | -327 | -0.4403% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,139 | 108,405 | 107,907 | -232 | -0.2145% | -498 | -0.4594% | - |
| RadixMatchingEngineGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 93,531 | 93,725 | 93,398 | -133 | -0.1422% | -327 | -0.3489% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 125,656 | 125,114 | 124,787 | -869 | -0.6916% | -327 | -0.2614% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,414 | 56,718 | 56,394 | -20 | -0.0355% | -324 | -0.5712% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,070 | 75,938 | 75,421 | -649 | -0.8532% | -517 | -0.6808% | - |
| RadixMatchingEngineGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 73,157 | 73,461 | 73,137 | -20 | -0.0273% | -324 | -0.4411% | - |
| RadixMatchingEngineGasTest:testGas_FillBidFullyMatchesSingleAsk() | 73,859 | 74,066 | 73,739 | -120 | -0.1625% | -327 | -0.4415% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,049 | 108,315 | 107,817 | -232 | -0.2147% | -498 | -0.4598% | - |
| RadixMatchingEngineGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 93,672 | 93,866 | 93,539 | -133 | -0.1420% | -327 | -0.3484% | - |
| RadixMatchingEngineGasTest:testGas_FillRestAskEmptyBook() | 149,458 | 149,756 | 149,756 | +298 | +0.1994% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_FillRestBidEmptyBook() | 151,082 | 150,466 | 150,466 | -616 | -0.4077% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 160,852 | 158,680 | 158,353 | -2,499 | -1.5536% | -327 | -0.2061% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 201,198 | 197,955 | 197,628 | -3,570 | -1.7744% | -327 | -0.1652% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsAsk() | 210,226 | 206,850 | 206,523 | -3,703 | -1.7614% | -327 | -0.1581% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookPartialFillsBid() | 169,838 | 167,533 | 167,206 | -2,632 | -1.5497% | -327 | -0.1952% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsAsk() | 199,333 | 196,477 | 196,224 | -3,109 | -1.5597% | -253 | -0.1288% | - |
| RadixMatchingEngineGasTest:testGas_LargeRandomBookRestsBid() | 215,224 | 210,610 | 210,357 | -4,867 | -2.2614% | -253 | -0.1201% | - |
| RadixMatchingEngineGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 784,770 | 771,309 | 770,808 | -13,962 | -1.7791% | -501 | -0.0650% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidCancelAfterThreePartialMatches() | 117,210 | 114,766 | 114,766 | -2,444 | -2.0851% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidPartialMatchAfterDirtySpineRest() | 131,666 | 130,075 | 129,748 | -1,918 | -1.4567% | -327 | -0.2514% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_ObservedNativeBidRestsAfterFiveLevelDirtySpine() | 220,505 | 214,811 | 214,604 | -5,901 | -2.6761% | -207 | -0.0964% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidCancelAfterThreePartialMatches() | 658,666 | 653,318 | 653,318 | -5,348 | -0.8119% | 0 | 0.0000% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidPartialMatchAfterDirtySpineRest() | 681,103 | 668,418 | 667,744 | -13,359 | -1.9614% | -674 | -0.1008% | - |
| RadixMatchingEngineGasTestNativeDirtySpine:testGas_PathologicalNativeBidRestsAfterFullDepthDirtySpine() | 772,290 | 768,496 | 768,289 | -4,001 | -0.5181% | -207 | -0.0269% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelAskSkipsPathologicalBidTree() | 39,917 | 38,643 | 38,643 | -1,274 | -3.1916% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFilledBidClaim() | 36,636 | 36,712 | 36,712 | +76 | +0.2074% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelFullDepthBidCombRightmost() | 754,198 | 748,601 | 748,601 | -5,597 | -0.7421% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelMaxValidDepthAskCombRightmost() | 664,641 | 659,053 | 659,053 | -5,588 | -0.8408% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelPartialBid() | 48,706 | 47,432 | 47,432 | -1,274 | -2.6157% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledAsk() | 40,022 | 38,748 | 38,748 | -1,274 | -3.1832% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_CancelUnfilledBid() | 39,627 | 38,348 | 38,348 | -1,279 | -3.2276% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskCrossLeafNonceComb() | 355,467 | 353,449 | 352,951 | -2,516 | -0.7078% | -498 | -0.1409% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskHalfNonceComb() | 228,373 | 227,499 | 227,001 | -1,372 | -0.6008% | -498 | -0.2189% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskNearlyWholeNonceComb() | 91,225 | 91,567 | 91,069 | -156 | -0.1710% | -498 | -0.5439% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill16Orders() | 119,567 | 119,607 | 119,283 | -284 | -0.2375% | -324 | -0.2709% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFill64Orders() | 135,663 | 135,551 | 135,227 | -436 | -0.3214% | -324 | -0.2390% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskSmallFillNonceComb() | 357,183 | 355,095 | 354,771 | -2,412 | -0.6753% | -324 | -0.0912% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyAskWholeNonceComb() | 65,399 | 65,703 | 65,379 | -20 | -0.0306% | -324 | -0.4931% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidCrossLeafNonceComb() | 356,635 | 354,617 | 354,119 | -2,516 | -0.7055% | -498 | -0.1404% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidHalfNonceComb() | 227,720 | 226,846 | 226,348 | -1,372 | -0.6025% | -498 | -0.2195% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidNearlyWholeNonceComb() | 91,326 | 91,668 | 91,170 | -156 | -0.1708% | -498 | -0.5433% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill16Orders() | 118,835 | 118,875 | 118,551 | -284 | -0.2390% | -324 | -0.2726% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFill64Orders() | 136,319 | 136,207 | 135,883 | -436 | -0.3198% | -324 | -0.2379% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidSmallFillNonceComb() | 357,103 | 355,015 | 354,691 | -2,412 | -0.6754% | -324 | -0.0913% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_DirtyBidWholeNonceComb() | 64,378 | 64,682 | 64,358 | -20 | -0.0311% | -324 | -0.5009% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 56,245 | 56,549 | 56,225 | -20 | -0.0356% | -324 | -0.5730% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskConsumesFullDepthBidComb() | 75,685 | 75,553 | 75,036 | -649 | -0.8575% | -517 | -0.6843% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskFullyMatchesSingleBid() | 74,235 | 74,442 | 74,115 | -120 | -0.1616% | -327 | -0.4393% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 108,233 | 108,499 | 108,001 | -232 | -0.2144% | -498 | -0.4590% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillAskPartiallyMatchesSingleBid() | 93,669 | 93,863 | 93,536 | -133 | -0.1420% | -327 | -0.3484% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesAskAndRestsRemainder() | 125,725 | 125,183 | 124,856 | -869 | -0.6912% | -327 | -0.2612% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 56,527 | 56,831 | 56,507 | -20 | -0.0354% | -324 | -0.5701% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesMaxValidDepthAskComb() | 76,183 | 76,051 | 75,534 | -649 | -0.8519% | -517 | -0.6798% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidConsumesSamePriceAskSubtree() | 73,226 | 73,530 | 73,206 | -20 | -0.0273% | -324 | -0.4406% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidFullyMatchesSingleAsk() | 73,972 | 74,179 | 73,852 | -120 | -0.1622% | -327 | -0.4408% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 108,118 | 108,384 | 107,886 | -232 | -0.2146% | -498 | -0.4595% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillBidPartiallyMatchesSingleAsk() | 93,807 | 94,001 | 93,674 | -133 | -0.1418% | -327 | -0.3479% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestAskEmptyBook() | 149,552 | 149,850 | 149,850 | +298 | +0.1993% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_FillRestBidEmptyBook() | 151,217 | 150,601 | 150,601 | -616 | -0.4074% | 0 | 0.0000% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookAskMatchesOneBid() | 160,968 | 158,796 | 158,469 | -2,499 | -1.5525% | -327 | -0.2059% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookBidMatchesOneAsk() | 201,333 | 198,090 | 197,763 | -3,570 | -1.7732% | -327 | -0.1651% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsAsk() | 210,427 | 207,051 | 206,724 | -3,703 | -1.7598% | -327 | -0.1579% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookPartialFillsBid() | 169,976 | 167,671 | 167,344 | -2,632 | -1.5485% | -327 | -0.1950% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsAsk() | 199,405 | 196,549 | 196,296 | -3,109 | -1.5591% | -253 | -0.1287% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_LargeRandomBookRestsBid() | 215,315 | 210,701 | 210,448 | -4,867 | -2.2604% | -253 | -0.1201% | inherited repetition |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024() | 98,283 | 98,151 | 97,634 | -649 | -0.6603% | -517 | -0.5267% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024AndRest() | 150,262 | 149,423 | 148,906 | -1,356 | -0.9024% | -517 | -0.3460% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024BurningHookAndFees() | 350,806 | 348,595 | 348,088 | -2,718 | -0.7748% | -507 | -0.1454% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024FitsOneMillionGas() | 97,555 | 97,423 | 96,906 | -649 | -0.6653% | -517 | -0.5307% | functional budget check |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep1024RestBurningHooksAndFees() | 607,866 | 602,675 | 602,168 | -5,698 | -0.9374% | -507 | -0.0841% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep256() | 97,967 | 97,835 | 97,318 | -649 | -0.6625% | -517 | -0.5284% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096() | 98,843 | 98,711 | 98,194 | -649 | -0.6566% | -517 | -0.5238% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep4096RestBurningHooksAndFees() | 614,536 | 609,354 | 608,847 | -5,689 | -0.9257% | -507 | -0.0832% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_MixedSweep64() | 97,267 | 97,135 | 96,618 | -649 | -0.6672% | -517 | -0.5322% | - |
| RadixMatchingEngineGasTestWideSweep:testGas_PathologicalOffSpinePartialFillBidComb() | 784,864 | 771,403 | 770,902 | -13,962 | -1.7789% | -501 | -0.0649% | inherited repetition |
| RadixMatchingEngineHookGasTest:testGas_CancelAskSkipsPathologicalBidTree() | 43,634 | 42,373 | 42,373 | -1,261 | -2.8899% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFilledBidClaim() | 37,073 | 37,148 | 37,148 | +75 | +0.2023% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelFullDepthBidCombRightmost() | 776,242 | 768,508 | 768,508 | -7,734 | -0.9963% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelMaxValidDepthAskCombRightmost() | 685,850 | 678,133 | 678,133 | -7,717 | -1.1252% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelPartialBid() | 52,964 | 51,695 | 51,695 | -1,269 | -2.3960% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledAsk() | 43,697 | 42,434 | 42,434 | -1,263 | -2.8904% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_CancelUnfilledBid() | 43,885 | 42,613 | 42,613 | -1,272 | -2.8985% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskCrossLeafNonceComb() | 378,882 | 366,246 | 365,756 | -13,126 | -3.4644% | -490 | -0.1338% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskHalfNonceComb() | 278,752 | 270,230 | 269,740 | -9,012 | -3.2330% | -490 | -0.1813% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskNearlyWholeNonceComb() | 170,245 | 166,342 | 165,852 | -4,393 | -2.5804% | -490 | -0.2946% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill16Orders() | 129,932 | 126,617 | 126,300 | -3,632 | -2.7953% | -317 | -0.2504% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFill64Orders() | 146,974 | 143,117 | 142,800 | -4,174 | -2.8400% | -317 | -0.2215% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskSmallFillNonceComb() | 378,812 | 367,909 | 367,592 | -11,220 | -2.9619% | -317 | -0.0862% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyAskWholeNonceComb() | 144,198 | 142,492 | 142,178 | -2,020 | -1.4009% | -314 | -0.2204% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidCrossLeafNonceComb() | 380,830 | 368,186 | 367,696 | -13,134 | -3.4488% | -490 | -0.1331% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidHalfNonceComb() | 279,121 | 270,591 | 270,101 | -9,020 | -3.2316% | -490 | -0.1811% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidNearlyWholeNonceComb() | 171,302 | 167,391 | 166,901 | -4,401 | -2.5691% | -490 | -0.2927% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill16Orders() | 130,288 | 126,965 | 126,648 | -3,640 | -2.7938% | -317 | -0.2497% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFill64Orders() | 148,520 | 144,655 | 144,338 | -4,182 | -2.8158% | -317 | -0.2191% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidSmallFillNonceComb() | 379,710 | 368,799 | 368,482 | -11,228 | -2.9570% | -317 | -0.0860% | - |
| RadixMatchingEngineHookGasTest:testGas_DirtyBidWholeNonceComb() | 144,221 | 142,507 | 142,193 | -2,028 | -1.4062% | -314 | -0.2203% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesDirtySamePriceBidSubtree() | 72,309 | 70,508 | 70,194 | -2,115 | -2.9249% | -314 | -0.4453% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskConsumesFullDepthBidComb() | 225,703 | 223,649 | 223,142 | -2,561 | -1.1347% | -507 | -0.2267% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskFullyMatchesSingleBid() | 83,538 | 81,650 | 81,333 | -2,205 | -2.6395% | -317 | -0.3882% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesOffSpineBidBranch() | 122,709 | 118,199 | 117,709 | -5,000 | -4.0747% | -490 | -0.4146% | - |
| RadixMatchingEngineHookGasTest:testGas_FillAskPartiallyMatchesSingleBid() | 105,209 | 101,069 | 100,749 | -4,460 | -4.2392% | -320 | -0.3166% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesAskAndRestsRemainder() | 138,240 | 133,338 | 133,021 | -5,219 | -3.7753% | -317 | -0.2377% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesDirtySamePriceAskSubtree() | 71,594 | 69,801 | 69,487 | -2,107 | -2.9430% | -314 | -0.4499% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesMaxValidDepthAskComb() | 225,325 | 223,279 | 222,772 | -2,553 | -1.1330% | -507 | -0.2271% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidConsumesSamePriceAskSubtree() | 90,535 | 88,745 | 88,431 | -2,104 | -2.3240% | -314 | -0.3538% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidFullyMatchesSingleAsk() | 82,445 | 80,565 | 80,248 | -2,197 | -2.6648% | -317 | -0.3935% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesOffSpineAskBranch() | 121,641 | 117,139 | 116,649 | -4,992 | -4.1039% | -490 | -0.4183% | - |
| RadixMatchingEngineHookGasTest:testGas_FillBidPartiallyMatchesSingleAsk() | 104,451 | 100,319 | 99,999 | -4,452 | -4.2623% | -320 | -0.3190% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestAskEmptyBook() | 140,948 | 138,972 | 138,972 | -1,976 | -1.4019% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_FillRestBidEmptyBook() | 142,572 | 139,682 | 139,682 | -2,890 | -2.0270% | 0 | 0.0000% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookAskMatchesOneBid() | 177,783 | 171,221 | 170,904 | -6,879 | -3.8693% | -317 | -0.1851% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookBidMatchesOneAsk() | 220,370 | 212,766 | 212,449 | -7,921 | -3.5944% | -317 | -0.1490% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsAsk() | 223,200 | 215,313 | 214,993 | -8,207 | -3.6770% | -320 | -0.1486% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookPartialFillsBid() | 182,769 | 176,530 | 176,210 | -6,559 | -3.5887% | -320 | -0.1813% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsAsk() | 234,701 | 224,990 | 224,736 | -9,965 | -4.2458% | -254 | -0.1129% | - |
| RadixMatchingEngineHookGasTest:testGas_LargeRandomBookRestsBid() | 245,737 | 234,260 | 234,006 | -11,731 | -4.7738% | -254 | -0.1084% | - |
| RadixMatchingEngineHookGasTest:testGas_PathologicalOffSpinePartialFillBidComb() | 809,297 | 778,800 | 778,307 | -30,990 | -3.8292% | -493 | -0.0633% | - |
