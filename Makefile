.PHONY: fmt lint test invariant invariant-deep gas-runtime snapshot-runtime snapshot-runtime-check build-size coverage coverage-check slither formal-halmos formal-kevm-build formal-kevm verify verify-deep verify-security

INVARIANT_RUNS ?= 2048
INVARIANT_DEPTH ?= 64
COVERAGE_FILE ?= src/RadixMatchingEngine.sol
COVERAGE_MIN_LINES ?= 100
COVERAGE_MIN_STATEMENTS ?= 100
COVERAGE_MIN_BRANCHES ?= 100
COVERAGE_MIN_FUNCS ?= 100
SLITHER ?= uv tool run --from slither-analyzer slither
HALMOS ?= uv tool run --from halmos halmos
HALMOS_ARGS ?= --match-contract RadixMatchingEngineFormalTest --match-test '^testFuzz_Formal' --solver z3 --solver-timeout-assertion 120s --no-status
KONTROL_IMAGE ?= runtimeverificationinc/kontrol:ubuntu-jammy-1.0.255
KONTROL ?= docker run --rm --platform linux/amd64 -v "$(CURDIR):/workspace" -w /workspace $(KONTROL_IMAGE) kontrol
KONTROL_BUILD_ARGS ?= --foundry-project-root /workspace --no-metadata --no-O2 --no-keccak-lemmas
KONTROL_PROVE_ARGS ?= --foundry-project-root /workspace --match-test $(KONTROL_TEST) --schedule CANCUN --no-gas
KONTROL_TEST ?= 'RadixMatchingEngineFormalTest.testFuzz_FormalBidAgainstAskConservesAndClaims(uint8,uint8,uint8)'

fmt:
	forge fmt --check

lint:
	forge lint

test:
	forge test --force -vv --no-match-contract '.*RadixMatchingEngineInvariantTest.*'

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
	forge coverage --report summary --no-match-coverage 'test|script' --no-match-contract 'RadixMatchingEngineInvariantTest'

coverage-check:
	@set -e; \
	tmp="$$(mktemp)"; \
	if ! NO_COLOR=1 forge coverage --report summary --no-match-coverage 'test|script' --no-match-contract 'RadixMatchingEngineInvariantTest' > "$$tmp" 2>&1; then \
		cat "$$tmp"; \
		rm -f "$$tmp"; \
		exit 1; \
	fi; \
	cat "$$tmp"; \
	python3 script/check_forge_coverage.py "$$tmp" \
		--file "$(COVERAGE_FILE)" \
		--min-lines "$(COVERAGE_MIN_LINES)" \
		--min-statements "$(COVERAGE_MIN_STATEMENTS)" \
		--min-branches "$(COVERAGE_MIN_BRANCHES)" \
		--min-funcs "$(COVERAGE_MIN_FUNCS)"; \
	rm -f "$$tmp"

slither:
	$(SLITHER) src/RadixMatchingEngine.sol --config-file slither.config.json --exclude-informational

formal-halmos:
	$(HALMOS) $(HALMOS_ARGS)

formal-kevm-build:
	$(KONTROL) build $(KONTROL_BUILD_ARGS)

formal-kevm:
	$(KONTROL) prove $(KONTROL_PROVE_ARGS)

verify: fmt lint test invariant snapshot-runtime-check build-size slither

verify-deep: fmt lint test invariant-deep snapshot-runtime-check build-size slither

verify-security: fmt lint test invariant-deep snapshot-runtime-check build-size slither coverage-check formal-halmos
