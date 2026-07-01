.PHONY: fmt lint test invariant invariant-deep gas-runtime snapshot-runtime snapshot-runtime-check build-size coverage slither formal-halmos formal-kevm-build formal-kevm verify verify-deep verify-security

INVARIANT_RUNS ?= 2048
INVARIANT_DEPTH ?= 64
SLITHER ?= slither
HALMOS ?= uv tool run --from halmos halmos
HALMOS_ARGS ?= --match-contract RadixMatchingEngineFormalTest --match-test '^(testFuzz_FormalBidAgainstAskConservesAndClaims|testFuzz_FormalAskAgainstBidConservesAndClaims)' --solver-timeout-assertion 5000 --no-status
KONTROL_IMAGE ?= runtimeverificationinc/kontrol:ubuntu-jammy-1.0.255
KONTROL ?= docker run --rm --platform linux/amd64 -v "$(CURDIR):/workspace" -w /workspace $(KONTROL_IMAGE) kontrol
KONTROL_TEST ?= 'RadixMatchingEngineFormalTest.testFuzz_FormalBidAgainstAskConservesAndClaims(uint8,uint8,uint8)'

fmt:
	forge fmt --check

lint:
	forge lint

test:
	forge test --force -vv

invariant:
	forge test --force --match-contract '.*RadixMatchingEngineInvariantTest.*' --match-test 'invariant_.*'

invariant-deep:
	FOUNDRY_INVARIANT_RUNS=$(INVARIANT_RUNS) FOUNDRY_INVARIANT_DEPTH=$(INVARIANT_DEPTH) forge test --force --match-contract '.*RadixMatchingEngineInvariantTest.*' --match-test 'invariant_.*'

gas-runtime:
	forge test --force --match-contract RadixMatchingEngineGasTest --gas-report

snapshot-runtime:
	forge snapshot --force --match-contract RadixMatchingEngineGasTest --snap .gas-snapshot.runtime

snapshot-runtime-check:
	forge snapshot --force --match-contract RadixMatchingEngineGasTest --check .gas-snapshot.runtime

build-size:
	forge build --sizes

coverage:
	forge coverage --report summary --no-match-coverage 'test|script'

slither:
	$(SLITHER) src/RadixMatchingEngine.sol --config-file slither.config.json --exclude-informational

formal-halmos:
	$(HALMOS) $(HALMOS_ARGS)

formal-kevm-build:
	$(KONTROL) build --foundry-project-root /workspace --no-metadata

formal-kevm:
	$(KONTROL) prove --foundry-project-root /workspace --match-test $(KONTROL_TEST) --schedule CANCUN --no-gas

verify: fmt lint test invariant snapshot-runtime-check build-size slither

verify-deep: fmt lint test invariant-deep snapshot-runtime-check build-size slither

verify-security: fmt lint test invariant-deep snapshot-runtime-check build-size slither coverage formal-halmos
