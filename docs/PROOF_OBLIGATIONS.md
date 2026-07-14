# Protocol Proof Obligations

This document states the protocol claims as precise theorems. It separates unconditional properties
of the reviewed contract from properties that necessarily depend on the EVM, cryptographic, token,
or transaction-gas environment. A claim is not promoted to **proved** merely because a fuzz campaign
or sampled differential test passes.

## Evidence Labels

| Label | Meaning |
|---|---|
| `BYTECODE` | Symbolic execution of production-compiled Solidity/EVM code. |
| `SMT` | Complete-domain solver proof of the stated mathematical transition or encoding lemma. |
| `INDUCTION` | Base case plus local preservation lemmas imply the property for every finite valid history. |
| `EXHAUSTIVE` | Every member of a finite reduced domain is checked, with a proved reduction from the full domain. |
| `CONDITIONAL` | The theorem is valid only under the assumptions named in its statement. |
| `TESTED` | Strong regression evidence, but not a universal proof. |

## Arithmetic

### A1. Tick decomposition

For every `t` in the signed 32-bit domain, let `s = 3t`,
`e = floor(s / 2^26)`, and `f = s - e 2^26`. Then `0 <= f < 2^26`. After the
nearest-exponent adjustment used by `TickMath32`, `-96 <= e <= 96` and the production divisor
`d = 128 - e` satisfies `32 <= d <= 224`.

**Evidence:** `SMT`, plus production-bytecode Halmos coverage in
`testFuzz_FormalTickDecompositionBounds`.

### A2. Tick factor accuracy and monotonicity

For every signed 32-bit tick, the represented rational factor/divisor price is strictly increasing
with the tick and differs from `2^(96t/2^31)` by the certified Q128 error bound reported by
`script/check_tick_math.py`.

**Evidence:** `CONDITIONAL` on the correctness of Python `Decimal` directed high-precision
evaluation. Every table constant is checked independently; a global composition bound and the
minimum adjacent-tick separation lift those constant checks to the full tick domain.

### A3. Exact represented-price quote arithmetic

For every factor emitted by `TickMath32`, every divisor in `[32, 224]`, every `uint160` quantity,
and both rounding directions, `_quoteValue` returns respectively

`floor(quantity * factor / 2^divisor)` and
`ceil(quantity * factor / 2^divisor)`.

The result is less than `2^256`. Production's one-word multiplication shortcut and two-word
Mersenne-modulus reconstruction produce the same high and low product limbs as full 512-bit
multiplication.

**Evidence:** `SMT` product-high and quotient/remainder lemmas, `BYTECODE` limb and rounding proofs,
and production/oracle differential checks. This proves equivalence for all `2^32` ticks by composing
A1-A2 with factor-domain arithmetic; it does not ask the solver to fork through all tick-table switch
arms in one query.

### A4. Partial-fill telescoping

For any fixed tick and rounding direction, define its rounded notional as `N(q)`. For every
`q0 >= q1 >= ... >= qn`, the sum of partial settlements is

`sum_i (N(q_i) - N(q_(i+1))) = N(q0) - N(qn)`.

Consequently, fill partitioning cannot create or destroy quote units.

**Evidence:** `SMT` and `INDUCTION`.

### A5. Uniform-subtree correction

For `n` same-tick leaves, the encoded correction reconstructs the exact sum of independently rounded
leaf notionals from the rounded aggregate notional. Its magnitude is at most `n - 1`; since a book
admits at most `2^32 - 2` leaves, `correction + 1` fits in `uint32`.

**Evidence:** `SMT` binary-merge and inductive-capacity lemmas, plus `BYTECODE` correction proofs.

### A6. Fees

For `0 <= amount <= int256.max` and `0 <= feeBps <= 100`, `_feeAmount` equals
`floor(amount * feeBps / 10_000)`, cannot overflow, and satisfies
`0 <= fee <= amount`. Applying the fee preserves `grossOutput = netOutput + fee` and never charges
an input or an unmatched resting remainder.

**Evidence:** `SMT`, `INDUCTION` for route accumulation, and production behavioral tests.

## Radix Structure

### R1. Key injectivity and priority

Within one book, `(tick, nonce)` maps injectively to a 64-bit key. Bid ordering is descending tick
then descending nonce. Ask ordering is ascending tick then descending nonce. Therefore the rightmost
leaf is always the best price, with the earliest assigned nonce first at equal price.

**Evidence:** `SMT` over every signed tick and nonce.

### R2. Patricia split correctness

At every depth from 0 through 63, two keys sharing the preceding prefix and differing at that depth
are partitioned into a zero-bit left child and a one-bit right child. Every left key is less than every
right key. Recursive insertion and removal advance the split depth, so a key walk terminates within
64 levels.

**Evidence:** 64 complete-domain `SMT` split lemmas and `INDUCTION` on subtree height.

### R3. Live-node address uniqueness

Assume every live leaf has a unique nonce and every branch quantity sum is representable. Two
disjoint branches have different maximum descendant path keys. An ancestor and descendant that
share a maximum path have strictly different positive aggregate quantities. A branch and one of its
live leaves likewise differ in quantity. Thus no two simultaneously live tree nodes share a
`bytes32` mapping key. Original order ownership keys may equal historical branch words without
aliasing because ownership is stored in `orderOf`, not `tree`.

**Evidence:** `SMT` local strict-sum lemmas and `INDUCTION` over the tree. Keccak-scoped ownership is
covered separately by N1.

### R4. Aggregate quantity and quote correctness

Every clean branch quantity equals the sum of its leaves. Every uniform branch quote equals the sum
of leaf-rounded quotes by A5. Every mixed subtree quote equals the recursive sum of its children.
Insertion, partial fill, full removal, cancellation, and branch collapse preserve these statements.

**Evidence:** local arithmetic `SMT` lemmas, `INDUCTION` on subtree height, production symbolic
one/two-maker paths, and stateful model invariants.

### R5. Dirty right-spine safety

Only right-child rewrites can make a right-spine anchor stale. Its child pointers remain valid, every
left subtree remains exact, and matching never treats a stale mixed-price aggregate as exact. The
dirty same-tick recovery recursively adds exact left summaries and the right suffix. Materialization
rebuilds the right child before its parent. Hence dirty execution preserves membership, priority,
quantity, and quote accounting; same-side insertion restores clean aggregates first.

**Evidence:** `INDUCTION` over the dirty suffix length, production formal dirty-spine paths, corruption
regressions, and stateful right-spine invariants.

### R6. Best-price matching

Every matcher visits the right child before the left child. By R1-R2, that child contains only keys
at least as good as those in the left child. A whole subtree is consumed only if its worst (leftmost)
price crosses the incoming limit. Therefore no worse-priced maker fills while a better crossing maker
remains, and equal-price makers fill in descending nonce order.

**Evidence:** `INDUCTION` on matcher recursion plus production symbolic and stateful priority checks.

## Ownership, Epochs, And Routing

### N1. Namespace isolation

Pool, book, and order state are isolated by `keccak256` domain inputs. Transient user-delta, fee,
hook, match-buffer, and reentrancy slots are pairwise disjoint by bit domain or full constant value.

**Evidence:** transient namespaces are `SMT` proved. Persistent namespaces are `CONDITIONAL` on
Keccak-256 collision resistance; unconditional injectivity of a 256-bit hash over larger input
domains is mathematically impossible.

### N2. Nonce uniqueness and exhaustion

An initialized book assigns strictly decreasing nonces from `2^32 - 1` through `2`, never assigns
zero or one, and rotates immediately after assigning nonce two. A nonce-one book stays matchable and
cancelable but cannot rest an unmatched taker remainder. For every epoch below `2^254 - 1`, rotation
increments the epoch without altering either packed hook bit. At `2^254 - 1`, rotation reverts with
`EpochExhausted`; EVM rollback leaves the book, owner, collateral, nonce, roots, and pool state
unchanged.

**Evidence:** `SMT`, production epoch `BYTECODE` proofs, a direct terminal-epoch rollback regression,
and multi-epoch invariants.

### N3. Arbitrary finite histories

Starting from empty state, every successful finite sequence of fills, routes, rests, matches,
partial fills, cancels, claims, hook updates, fee updates, and epoch rotations preserves R1-R6 and
the accounting properties below. A history that attempts to rotate beyond the finite epoch namespace
reverts atomically and therefore also preserves the pre-state invariant.

**Evidence:** `INDUCTION` from the empty base case and the operation-local preservation theorems.
The current 254-bit epoch encoding necessarily places a finite upper bound on rotations; no finite
storage encoding can provide an injective namespace for an actually infinite history.

### N4. Route netting

For every finite route, the transient delta for a token equals the algebraic sum of that token's leg
deltas, independent of token repetition or leg grouping. Positive user deltas are paid, negative user
deltas are pulled, and fees are transferred afterward. With exact-transfer tokens, the engine balance
change equals the negative user net minus paid fees.

**Evidence:** `SMT` additive induction, production route tests, and multi-pool model invariants.

### N5. Multi-pool noninterference

An operation can mutate only the derived books, order ids, pool state, and transient token slots named
by its inputs. Operations on distinct hash ids commute except where they intentionally share a token
settlement accumulator or global fee configuration.

**Evidence:** `INDUCTION` over mapping updates and `CONDITIONAL` on N1's Keccak assumption, with
multi-pool stateful model evidence.

## External Calls And Liveness

### E1. Reentrancy exclusion

Every public fill, route, and cancel acquires the same transient guard before any callback-capable
token or hook call. A callback into any guarded mutator reverts. Success clears the guard; failure
reverts the complete EVM frame, including transient and persistent writes.

**Evidence:** `SMT` guard-state transition lemmas, EVM transaction semantics, production guard
inspection, and adversarial callback tests.

Owner-only configuration remains callable from a hook only if governance deliberately assigns the
hook contract as owner; that is an administrative trust choice, not a reentrancy bypass.

### E2. Hook isolation

Hook calls occur after the relevant book mutation, forward at most 200,000 gas, and are wrapped in
`try/catch`. Hook return data is unused. Consequently any revert or hook-local out-of-gas cannot
change matching results or revert the outer operation, assuming Cancun call semantics.

**Evidence:** `CONDITIONAL` on EVM call isolation, plus reverting and reentrant hook tests.

### E3. Token accounting

If every configured token implements exact-transfer ERC20 semantics, successful settlement preserves
collateral equality and every failed transfer reverts the complete operation atomically. Tokens that
return success while lying about balances, rebase, charge transfer fees, or invoke arbitrary privileged
state changes are outside this theorem.

**Evidence:** `CONDITIONAL` on exact-transfer semantics, production safe-transfer behavior, and token
failure/reentrancy tests. Correct accounting against an arbitrarily malicious external contract is not
an implementable unconditional property.

### E4. Termination and gas-bounded liveness

Pure radix walks are bounded by 64 key bits. Partial matching visits at most one unresolved path per
level while whole uniform subtrees are O(1). Exact quote calculation for a fully consumed mixed-price
subtree is O(number of mixed descendants), route execution is additive over legs, and touched-token
deduplication is quadratic in the number of distinct route tokens. Thus every finite call terminates
in the unmetered model, but a sufficiently large mixed tree or route may exceed a particular block gas
limit and revert.

**Evidence:** `INDUCTION` on key depth, subtree size, and route length; isolated gas benchmarks for
concrete limits. “Live under every block gas limit” is false for every nontrivial EVM contract and is
not claimed.

## Proof Boundary

The remaining trusted bases are Solidity/EVM compiler correctness, Cancun EVM semantics, the SMT
solver, high-precision directed transcendental evaluation used for table constants, Keccak collision
resistance, and deployment exclusion of inexact tokens. These assumptions are explicit because
silently calling them “proved” would overstate the assurance result.

The base cases and preservation arguments that lift the local complete-domain obligations to every
finite history are written in [INDUCTIVE_PROOFS.md](INDUCTIVE_PROOFS.md). Under the assumptions above,
the registry has no remaining open property. Claims outside those assumptions are not relabeled as
protocol theorems.
