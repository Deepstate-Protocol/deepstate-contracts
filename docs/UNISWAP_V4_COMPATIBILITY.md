# Uniswap V4 Swap-Manager Compatibility Boundary

`DeepstateV1` implements the Uniswap V4 manager ABI used by swap routers at v4-core commit
`e50237c43811bd9b526eff40f26772152a42daba` (`v4.0.0`). The pinned submodule is not patched.
This is a swap-manager compatibility profile, not a concentrated-liquidity PoolManager
implementation.

## Compatible Lifecycle

The contract implements these V4 entrypoints with their canonical selectors and tuple encodings:

- `unlock(bytes)`;
- `swap(PoolKey, SwapParams, bytes)`;
- `sync(Currency)`;
- `settle()` and `settleFor(address)`;
- `take(Currency,address,uint256)`;
- `clear(Currency,uint256)`;
- both `exttload` overloads.

The unlock flag, nonzero-delta count, synced currency and reserve, and
`keccak256(abi.encode(account, currency))` delta slots match V4's transient-storage layout. A router
may execute several swaps during one callback, net intermediate currencies, and settle only each
final nonzero delta. The callback must return with the canonical nonzero-delta count equal to zero.

All lifecycle mutations are restricted to the contract that opened the current unlock session.
This is stronger than the V4 PoolManager's unlocked-only check and prevents token callbacks or
Deepstate top-of-book hooks from mutating the session. Standard V4 routers call the manager from
their own unlock callback and satisfy this restriction without modification.

### Runtime module boundary

Routers always call the `DeepstateV1` address. The engine implements `swap` directly. To preserve
EIP-170 headroom, its constructor deploys one immutable `V4SwapManagerModule`, and the engine
fallback executes the other listed V4 lifecycle selectors from that fixed module in the engine's
context. This is necessary for transient deltas and token balances to remain attached to the manager
address. The module contains no `SSTORE`, has no upgrade target or persistent configuration, and
rejects its internal price-math selectors when reached through the engine fallback. Radix traversal,
matching, hook dispatch, fee calculation, and persistent book state never execute in the module.

## Swap Semantics

The compatibility key is
`(currency0, currency1, fee = 0, tickSpacing = 1, hooks = address(0))`, with strictly sorted
currencies. It resolves to the active Deepstate epoch for that pair. The active book must already be
initialized by a native Deepstate order. Every V4-shaped swap is no-rest.

| Surface | Deepstate behavior |
|---|---|
| Signed amount convention | Negative is exact input; positive is exact output |
| Direction | Both `zeroForOne` values |
| Specified currency | All four direction and exactness combinations |
| Return encoding | Canonical packed `BalanceDelta` with caller-relative `int128` deltas |
| Price limit | Q64.96 limit converted conservatively to an executable Deepstate tick |
| Partial execution | Stops at the amount, price limit, or available resting liquidity |
| No liquidity | Returns a zero delta for an initialized canonical book |
| Native ETH | Currency address zero, settled through payable `settle` and `take` |
| Canonical errors | V4 errors for lock state, settlement, currency order, zero amount, key initialization, price bounds, and delta overflow |

`swap` mutates the radix book and records two transient currency deltas. It does not transfer user
tokens. The router pays negative deltas through `sync` plus `settle` for ERC20s, or payable `settle`
for native ETH, and withdraws positive deltas through `take`. Protocol output fees are included in
exact-output gross-up and in the returned net delta. Fees from all swaps in one unlock are condensed
by currency and transferred after the user's deltas are settled and the manager is locked.

Deepstate's signed 32-bit logarithmic ticks are not V4's signed 24-bit ticks. The `tickSpacing = 1`
key field identifies the compatibility profile; it does not change Deepstate's radix price domain.
The Q64.96 price limit is mapped to the conservative boundary tick, preserving the caller's limit.

## Deliberate Omissions

The contract does not claim the complete `IPoolManager` surface. These V4 features have no
equivalent in the order-book model and are not implemented:

- `initialize`, `modifyLiquidity`, and `donate`;
- concentrated-liquidity positions or V3/V4 liquidity equivalence;
- ERC-6909 `mint` and `burn` claims;
- V4 hooks, dynamic LP fees, and LP protocol fees;
- `extsload` access to V4 pool state;
- V4 `Initialize`, `ModifyLiquidity`, `Swap`, and `Donate` events.

Deepstate protocol fees and top-of-book hooks remain independent engine configuration. The canonical
compatibility key rejects V4 hooks, so `hookData` has no consumer. Historical-book routing remains
available only through the native Deepstate interface.

## Test Provenance

`make uniswap-v4` runs two independent checks:

1. `uniswap-v4-conformance` executes the Deepstate lifecycle, amount-mode, price-limit, fee, native
   ETH, multi-pool netting, and reentrancy tests. It also deploys the pinned v4-core
   `SwapRouterNoChecks` unchanged and settles a swap through `DeepstateV1`.
2. `uniswap-v4-upstream` verifies the exact pinned submodule commit, rejects tracked modifications,
   and runs the complete upstream v4-core test suite with its own Foundry configuration and Foundry
   `v0.3.0`. That historical toolchain is required because newer Foundry releases removed the
   upstream suite's `testFail*` convention and changed low-level revert-expectation behavior. Gas
   snapshot enforcement is not enabled because those snapshots depend on the exact historical
   nightly.

No upstream test source is copied, edited, subclassed, or conditionally disabled. The unchanged
router test proves the shared lifecycle surface against Deepstate; the complete upstream suite is
independent evidence for the pinned V4 reference implementation.
