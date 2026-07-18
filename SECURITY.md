# Security Policy

## Status

The matching and routing contracts are under active development. The repository exercises unit,
fuzz, stateful-invariant, symbolic, static-analysis, gas-snapshot, bytecode-size, and independent
tick-reference gates, but those controls do not replace an independent external audit. Production
deployment should wait for an audit of the exact commit and compiler profile being deployed.

## Reporting

Report suspected vulnerabilities privately through a GitHub security advisory for
this repository. Do not open a public issue containing an exploit or affected user
data. Include the affected commit, reproduction steps, impact, and any proposed mitigation.

## Trust Model

- `DeepstateV1.owner()` may configure the protocol fee recipient/rate and pool hook contracts.
  Use a reviewed multisig or governance executor, verify ownership after deployment, and protect its
  signers. Renouncing ownership permanently freezes fee and hook configuration.
- Fees are capped at 100 bps and are charged only against matched taker output. Cancels and maker
  claims are not charged.
- Hooks are untrusted, optional, gas-capped, best-effort notifications. Hook failure does not revert
  matching. Hook consumers must tolerate dropped or stale notifications and reconcile independently.
- The engine does not validate token code or balance deltas. Deployment policy must restrict pools to
  exact-transfer ERC20s. Fee-on-transfer, rebasing, callback-dependent, mint-on-transfer, and other
  nonstandard balance semantics are unsupported.
- `address(0)` denotes native ETH and is accepted only as sorted token0. Native fills and routes
  require `msg.value` at least equal to the net debit; excess is refunded after outputs and fees,
  while insufficient value reverts. ETH forced into the engine outside a call is not attributable
  to a sender and remains surplus, but cannot reduce collateral available to makers.
- Traders and routers choose token pairs, epochs, limits, `noRest`, and `fillOrKill`. Integrators must
  validate those values and should use `fillOrKill` when later route legs depend on earlier execution.

## Deployment Checklist

1. Check out the exact release commit with recursive submodules and use the Foundry/Solidity versions
   pinned by CI and `foundry.toml`.
2. Run `make verify-security`. Review any gas-snapshot change instead of regenerating the baseline
   automatically.
3. Confirm the target chain supports Cancun transient-storage opcodes (`TLOAD` and `TSTORE`).
4. Obtain an external audit of the exact runtime bytecode and resolve or explicitly accept every
   finding.
5. Review and allowlist each supported token address and its deployed implementation. Test transfer,
   transfer-from, return-value, proxy-upgrade, pause, blacklist, and supply-change behavior.
6. Deploy from the intended owner or immediately transfer ownership to the production multisig.
   Verify `owner()`, runtime bytecode, constructor transaction, and source metadata on the explorer.
7. Configure fees and hooks only after verifying recipient and hook bytecode. Confirm emitted
   configuration events and read the configuration back on-chain.
8. Exercise small bid, ask, partial fill, full fill, cancel, claim, native ETH, and multi-pool route
   transactions before enabling meaningful value.
9. Monitor configuration events, failed hook calls off-chain, book rotations, token upgrades, and
   collateral balances. Maintain a public incident-response and migration plan.

## Build Reproducibility

The supported profile is Solidity `0.8.28`, optimizer enabled with 200 runs, `via_ir = true`, and
`evm_version = "cancun"`. A different compiler, optimizer, EVM target, dependency revision, or source
commit is a different security artifact and requires the complete verification and audit process.
