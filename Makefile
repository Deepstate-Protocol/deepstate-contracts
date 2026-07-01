.PHONY: fmt lint test invariant invariant-deep gas-runtime snapshot-runtime snapshot-runtime-check build-size coverage slither verify verify-deep verify-security

INVARIANT_RUNS ?= 2048
INVARIANT_DEPTH ?= 64
SLITHER ?= slither

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
	forge coverage --report summary

slither:
	$(SLITHER) src/RadixMatchingEngine.sol --config-file slither.config.json --exclude-informational

verify: fmt lint test invariant snapshot-runtime-check build-size slither

verify-deep: fmt lint test invariant-deep snapshot-runtime-check build-size slither

verify-security: fmt lint test invariant-deep snapshot-runtime-check build-size slither coverage
