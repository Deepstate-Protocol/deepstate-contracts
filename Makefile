.PHONY: fmt lint test invariant invariant-deep invariant-deep-shard invariant-deep-shards gas-runtime gas-access-list snapshot-runtime snapshot-runtime-check build-size tick-reference coverage coverage-check toolchain-lock-check slither formal-smt formal-halmos formal-kevm-build formal-kevm verify verify-deep verify-security

INVARIANT_RUNS ?= 2048
INVARIANT_DEPTH ?= 64
INVARIANT_SHARDS ?= 8
INVARIANT_SHARD ?= 1
INVARIANT_CONTRACTS ?= .*(RadixMatchingEngineInvariantTest|DeepstateV1MultiPoolInvariantTest|DeepstateV1NativeETHInvariantTest).*
GAS_CONTRACTS ?= (RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)
COVERAGE_FILES ?= src/DeepstateV1.sol,src/libraries/TickMath32.sol
COVERAGE_EXCLUSIONS ?= coverage.exclusions.json
# Coverage runs every behavioral, routing, boundary, and math test. Formal proofs, stateful
# invariants, and benchmarks retain dedicated targets because they do not add source coverage.
COVERAGE_SKIP_ARGS ?= --skip RadixMatchingEngineInvariant.t.sol --skip DeepstateV1Invariant.t.sol --skip DeepstateV1NativeETHInvariant.t.sol --skip RadixMatchingEngineGas.t.sol --skip RadixMatchingEngineAccessList.t.sol --skip RadixMatchingEngineFormal.t.sol
COVERAGE_MIN_LINES ?= 100
COVERAGE_MIN_STATEMENTS ?= 100
COVERAGE_MIN_BRANCHES ?= 100
COVERAGE_MIN_FUNCS ?= 100
UV ?= uv
SLITHER ?= $(UV) run --locked --only-group static slither
HALMOS ?= $(UV) run --locked --only-group formal halmos
SMT ?= $(UV) run --locked --only-group formal python
HALMOS_BUILD_OUT ?= out-halmos
HALMOS_ARGS ?= --forge-build-out $(HALMOS_BUILD_OUT) --match-contract '.*FormalTest' --match-test '^testFuzz_Formal' --solver yices --solver-timeout-assertion 30s --no-status
KONTROL_IMAGE ?= runtimeverificationinc/kontrol:ubuntu-jammy-1.0.255
KONTROL ?= docker run --rm --platform linux/amd64 -v "$(CURDIR):/workspace" -w /workspace $(KONTROL_IMAGE) kontrol
KONTROL_BUILD_ARGS ?= --foundry-project-root /workspace --no-metadata --no-O2 --no-keccak-lemmas
KONTROL_PROVE_ARGS ?= --foundry-project-root /workspace --match-test $(KONTROL_TEST) --schedule CANCUN --no-gas
KONTROL_TEST ?= 'RadixMatchingEngineFormalTest.testFuzz_FormalBidAgainstAskConservesAndClaims(uint8,uint8)'

fmt:
	forge fmt --check

lint:
	forge lint

test:
	forge test --force -vv --no-match-contract '$(INVARIANT_CONTRACTS)'

invariant:
	forge test --force --match-contract '$(INVARIANT_CONTRACTS)' --match-test 'invariant_.*'

invariant-deep:
	FOUNDRY_INVARIANT_RUNS=$(INVARIANT_RUNS) FOUNDRY_INVARIANT_DEPTH=$(INVARIANT_DEPTH) forge test --force --match-contract '$(INVARIANT_CONTRACTS)' --match-test 'invariant_.*'

invariant-deep-shard:
	python3 script/run_invariant_shards.py --runs "$(INVARIANT_RUNS)" --depth "$(INVARIANT_DEPTH)" --shards "$(INVARIANT_SHARDS)" --shard "$(INVARIANT_SHARD)"

invariant-deep-shards:
	python3 script/run_invariant_shards.py --runs "$(INVARIANT_RUNS)" --depth "$(INVARIANT_DEPTH)" --shards "$(INVARIANT_SHARDS)" --all

gas-runtime:
	forge test --isolate --force --match-contract '$(GAS_CONTRACTS)' --gas-report

gas-access-list:
	forge test --force --match-contract RadixMatchingEngineAccessListBenchmark -vv

snapshot-runtime:
	forge snapshot --isolate --force --match-contract '$(GAS_CONTRACTS)' --snap .gas-snapshot.runtime

snapshot-runtime-check:
	forge snapshot --isolate --force --match-contract '$(GAS_CONTRACTS)' --check .gas-snapshot.runtime

build-size:
	forge build --sizes src/DeepstateV1.sol

tick-reference:
	python3 script/check_tick_math.py --check test/TickMath32.t.sol

coverage:
	forge coverage --ir-minimum $(COVERAGE_SKIP_ARGS) --report lcov --report summary --no-match-coverage 'test|script' --no-match-contract '$(INVARIANT_CONTRACTS)'

coverage-check:
	@set -e; \
	tmp="$$(mktemp)"; \
	if ! NO_COLOR=1 forge coverage --ir-minimum $(COVERAGE_SKIP_ARGS) --report lcov --report summary --no-match-coverage 'test|script' --no-match-contract '$(INVARIANT_CONTRACTS)' > "$$tmp" 2>&1; then \
		cat "$$tmp"; \
		rm -f "$$tmp"; \
		exit 1; \
	fi; \
	cat "$$tmp"; \
	python3 script/check_forge_coverage.py "$$tmp" \
		--files "$(COVERAGE_FILES)" \
		--lcov lcov.info \
		--exclude "$(COVERAGE_EXCLUSIONS)" \
		--min-lines "$(COVERAGE_MIN_LINES)" \
		--min-statements "$(COVERAGE_MIN_STATEMENTS)" \
		--min-branches "$(COVERAGE_MIN_BRANCHES)" \
		--min-funcs "$(COVERAGE_MIN_FUNCS)"; \
	rm -f "$$tmp"

toolchain-lock-check:
	$(UV) lock --check

slither:
	$(SLITHER) src/DeepstateV1.sol --config-file slither.config.json --exclude-informational

formal-halmos:
	forge build --force --build-info --out $(HALMOS_BUILD_OUT) test/RadixMatchingEngineFormal.t.sol
	$(HALMOS) $(HALMOS_ARGS)

formal-smt:
	$(SMT) script/prove_protocol.py

formal-kevm-build:
	$(KONTROL) build $(KONTROL_BUILD_ARGS)

formal-kevm:
	$(KONTROL) prove $(KONTROL_PROVE_ARGS)

verify: toolchain-lock-check fmt lint tick-reference test invariant snapshot-runtime-check build-size slither

verify-deep: toolchain-lock-check fmt lint tick-reference test invariant-deep-shards snapshot-runtime-check build-size slither

verify-security: toolchain-lock-check fmt lint test invariant-deep-shards snapshot-runtime-check build-size slither tick-reference coverage-check formal-smt formal-halmos
