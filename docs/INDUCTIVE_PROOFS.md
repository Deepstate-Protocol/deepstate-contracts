# Inductive Protocol Proofs

This document supplies the base cases and preservation arguments used to lift the finite-domain
lemmas in `script/prove_protocol.py` and the production-bytecode obligations in
`test/RadixMatchingEngineFormal.t.sol` to every finite valid protocol history. “Valid” means that
the call satisfies the public preconditions, all checked arithmetic succeeds, and configured tokens
satisfy the exact-transfer assumption in `PROOF_OBLIGATIONS.md`. A terminal-epoch rotation is a
defined reverting transition and is covered by atomic rollback rather than excluded from the history.

The proof is compositional. It does not infer a universal result from fuzzing. Fuzzing remains an
independent attempt to falsify the invariants proved below. Complete-domain algebraic steps are
machine-checked by `script/prove_protocol.py`; implementation-specific transition kernels are checked
against production bytecode by Halmos; structural lifting is the explicit induction below.

## 1. Definitions

For a side `s` and leaf `l`, define:

- `P(l) = (tick(l), nonce(l))`, the raw 64-bit address path;
- `K_bid(l) = sortableTick(l) || nonce(l)`;
- `K_ask(l) = (2^32 - 1 - sortableTick(l)) || nonce(l)`;
- `Q(l)`, its positive `uint160` live quantity; and
- `N_s(t, q)`, the exact integer notional represented by production tick `t`, rounded down for an
  ask and up for a bid.

For a subtree `T`, let `Leaves(T)` be its reachable leaves, `maxP(T)` its maximum raw path, and
`sumQ(T)` the sum of its live quantities. A clean branch address is the packed word

`A(T) = pack(maxP(T), sumQ(T), correction(T))`.

The correction field is zero for a mixed-tick branch. For a uniform branch it is one plus the
difference between the aggregate-rounded notional and the sum of leaf-rounded notionals, with the
sign convention stated in the contract.

### 1.1 Clean-tree invariant `C(T)`

`C(T)` holds when:

1. every leaf has positive quantity and zero correction;
2. every branch has exactly two nonzero children;
3. the children diverge at the branch's Patricia split, every left key is smaller than every right
   key, and every descendant shares the required preceding prefix;
4. the branch quantity is `sumQ(T)` and its raw boundary is `maxP(T)`;
5. a nonzero correction denotes a uniform-tick subtree and reconstructs exactly
   `sum(N_s(t, Q(l)))`; zero denotes a leaf or mixed branch;
6. all reachable node addresses are distinct and nonzero; and
7. the rightmost leaf has maximum side sort key.

### 1.2 Dirty-tree invariant `D(T)`

`D(T)` differs from `C(T)` only on a suffix of the global right spine. A retained dirty anchor:

1. keeps its exact left child;
2. points to a right child satisfying either `C` or `D`;
3. retains a historical packed address whose quantity is at least the current subtree quantity;
4. remains distinct from every current descendant; and
5. is never used as an exact aggregate unless `_dirtyRightSpineData` reconstructs quantity and
   quote from its children.

All off-spine subtrees remain clean.

### 1.3 Book and accounting invariant `B`

For each book:

1. the ask and bid roots each satisfy `C` or `D`;
2. every live leaf has exactly one original `orderOf[keccak256(bookId, originalOrder)]` record;
3. every ownership record identifies at most one live leaf with the same tick and nonce;
4. assigned nonces are unique across both sides and strictly decrease;
5. the two sides are uncrossed after every completed fill; and
6. exact-transfer ERC20 collateral equals the sum of all cancelable and claimable ERC20
   liabilities, while native ETH collateral satisfies Section 1.4.

### 1.4 Native liability and surplus

For an active maker order in any book with native ETH as token0, let `q0` be its original quantity
and let `q` be its live remaining quantity, taking `q = 0` when its leaf has fully filled. Define

`L_ask = q` and `L_bid = q0 - q`.

The first term is unfilled ask collateral owed back to the maker. The second is filled base owed to
a bid maker at claim time. Let `L_ETH` be the sum over every native pair, book, and active order.
For engine balance `E`, define native surplus `S = E - L_ETH`.

An unsolicited native credit is ETH delivered outside the settlement amount required by the current
protocol call, including ETH forced by `SELFDESTRUCT`, a withdrawal credit, or ETH returned by a
recipient callback. Such a credit can increase `E` without creating an order liability. The native
solvency invariant is `S >= 0`. Exact equality `S = 0` is the stronger invariant for histories with
no unsolicited native credits.

## 2. Arithmetic Preservation

### 2.1 Represented price and quotes

The tick checker establishes a global factor error envelope and strict adjacent-tick separation.
Settlement itself does not use the real exponential; it uses the represented rational
`factor / 2^shift`. The SMT quotient/remainder obligations prove that production returns exactly
`floor(q * factor / 2^shift)` or `ceil(q * factor / 2^shift)` for every valid quantity and tick.

The factor/shift coupling is essential. At `shift = 32`, the rounded exponent is 96 and the
nonzero complementary fraction produces `factor < 2^128`. At every larger shift,
`factor < 2^129`. Therefore `q * factor < 2^(256 + shift)`, and the assembly quotient cannot discard
a high bit. In addition, every rounded leaf quote is at most `q * 2^96`. If child quantities sum to
at most `uint160.max`, child quote sums are strictly below `2^256`; this proves safety of the
deliberately unchecked recursive quote additions.

### 2.2 Partial fills

Fix a side and tick and write `N(q)` for its rounded notional. A partial fill from `q0` to `q1`
settles `N(q0) - N(q1)`. Monotonicity of integer floor and ceiling makes the difference nonnegative.
For any partition `q0 >= q1 >= ... >= qn`, cancellation of adjacent terms gives

`sum_i (N(q_i) - N(q_(i+1))) = N(q0) - N(qn)`.

Thus fill partitioning and transaction ordering do not alter the total integer liability. The event
correction is also exact: a floor difference is either the independent floor of the filled quantity
or one greater; a ceiling difference is either the independent ceiling or one less. The encoded
zero/one correction covers precisely those cases.

### 2.3 Uniform aggregates

For two child products, writing each remainder in `[0, d)`, their remainder sum crosses `d` at most
once. Therefore:

- `floor(x + y) - floor(x) - floor(y)` is zero or one; and
- `ceil(x) + ceil(y) - ceil(x + y)` is zero or one.

Assuming child corrections are exact, adding this local zero/one term yields the exact parent
correction. If child subtrees contain `m` and `n` leaves, the result is at most
`(m - 1) + (n - 1) + 1 = m + n - 1`. One book can assign at most `2^32 - 2` leaves, so the stored
`correction + 1` fits in `uint32`. This is structural induction on uniform-subtree height.

## 3. Radix Preservation

### 3.1 Empty and leaf bases

An empty root satisfies every tree clause vacuously. A newly packed leaf has positive validated
quantity, zero caller-supplied correction and nonce bits, and a contract-assigned nonce in
`[2, 2^32 - 1]`; it therefore satisfies `C`.

### 3.2 Insertion

Assume `C(T)` after any required dirty-spine materialization.

1. **Empty root:** the new leaf becomes the root.
2. **Leaf root:** unequal nonces make the side keys unequal. `_storeBranch` finds their first
   differing bit and places bit zero left and bit one right.
3. **Divergence above the root split:** the new parent partitions the new key from every existing
   descendant because all old descendants share the old prefix.
4. **Divergence below the root split:** recursion enters exactly one child. By induction that child
   remains clean; rebuilding the parent restores exact quantity, boundary and correction.

The depth increases before every recursive call and is at most 64. The SMT split obligations cover
every possible depth.

### 3.3 Removal and branch collapse

Search follows the same Patricia split predicate as insertion. A prefix mismatch proves absence. At
the target leaf, removal returns empty. On unwind:

- zero children produce empty;
- one child is promoted without changing its invariant; and
- two children are repacked from their exact summaries.

For an off-spine path this proves `C` directly. On the global right path, the optimization may retain
the old branch address and update only its right pointer, producing `D` as proved in Section 4.

### 3.4 Live-node uniqueness

Leaf raw paths are unique because nonce assignment is global to the book. For two disjoint
subtrees, their maximum raw paths are therefore different, so their branch words differ in the path
fields. If two live subtrees share their maximum leaf, rooted-tree structure makes them nested. The
ancestor contains at least one additional positive sibling, so its checked aggregate quantity is
strictly greater than the descendant quantity. The same argument separates a branch from its
maximum leaf. Bid and ask subtrees are disjoint but use the same globally unique nonce sequence, so
the disjoint-subtree argument also applies across sides. Positive quantity separates every live node
from root zero.

These cases exhaust leaf/branch and same-side/cross-side pairs. The exact packing-field injectivity
and strict-sum steps are SMT obligations.

## 4. Dirty Right-Spine Preservation

Assume `D(T)` and modify only the rightmost path.

1. The left child is unchanged and remains clean.
2. A fill or removal only decreases descendant quantities. A retained anchor's historical quantity
   was strictly greater than every old proper descendant and is therefore still strictly greater
   than every new descendant. It cannot alias one. Production additionally falls back to a rebuilt
   branch if a replacement child equals the anchor or its sibling.
3. Updating the right pointer preserves reachability and key order because the replacement is the
   result of recursively modifying the old right subtree.
4. Dirty aggregate words are never trusted for mixed-price consumption. `_dirtyRightSpineData`
   accepts a frame only when the exact left child and recursively reconstructed right suffix are
   uniform at the same tick; it then adds exact quantities and exact corrected quotes.
5. `_materializeRightSpine` recursively materializes the right child before rebuilding its parent,
   so induction on suffix length yields a clean exact root.

Thus optimized matching/removal maps `C or D` to `C or D`, and a later same-side insertion maps it
back to `C`.

## 5. Matching Priority And Accounting

Both side keys order the best maker to the right: bids by descending tick and nonce, asks by
ascending tick and descending nonce. Every matching frame visits the right child before the left.

A subtree fast path is taken only when:

1. its full quantity fits in the taker remainder; and
2. its worst, leftmost leaf crosses the taker limit.

If the worst leaf crosses, every better leaf crosses. If either condition fails, recursion processes
the right subtree first and reaches the left subtree only with remaining quantity. Induction on
subtree height proves that no worse maker fills while a better crossing maker remains. Strict nonce
ordering proves time priority at equal tick.

Leaf partial fill preserves the same key with smaller positive quantity. Full leaf or subtree fill
uses the removal cases above. Base filled is bounded by incoming remainder, and quote settlement is
the exact leaf-rounded sum by Section 2. Consequently matching preserves `B` and leaves the two
sides uncrossed: any unmatched remainder either rests only after all crossing opposite liquidity was
consumed or is discarded by `noRest`.

## 6. Ownership, Cancel, And Claims

Rest writes ownership under `keccak256(bookId, originalOrder)` before insertion; any later revert
rolls that write back. Partial fills rewrite only the live tree leaf quantity, so the original owner
key remains stable. Cancel searches by tick and nonce:

- if the leaf remains, it returns remaining collateral plus proceeds for `original - remaining`;
- if absent, the order fully filled and it returns all proceeds; and
- if present at full quantity, it returns all collateral.

Section 2's telescoping identity makes each payout equal the original liability minus amounts already
paid to takers. The owner record is deleted before external transfer, while the global transient
guard is held. A failed transfer reverts both deletion and tree mutation atomically.

## 7. Nonces And Epochs

An initialized book starts at nonce `2^32 - 1`. Rest assigns the current nonce and stores one less;
therefore assignments are exactly `2^32 - 1, ..., 2`, with no repetition. Assigning two leaves one,
which is the non-restable sentinel, and rotates the active pool epoch.

For `epoch < 2^254 - 1`, increment is exact and cannot overlap either hook bit. At the terminal epoch,
the explicit `EpochExhausted` guard reverts the entire attempted rest, so no wrapped epoch, owner,
root, nonce or collateral change survives. An epoch whose nonce is one remains matchable and
cancelable, but `_executeFill` forces its unmatched remainder to `noRest`. An empty book can initialize
only when its requested epoch equals the current pool epoch. These cases prevent stale-book rests
and crossed liquidity between epochs.

## 8. Native ETH Solvency

The empty-state base has `E = L_ETH = S = 0`. Assume before one transition that `S >= 0`.

### 8.1 Incoming bid

If an incoming bid consumes `f` native-denominated ask quantity, existing ask liabilities decrease
by `f`. A resting bid remainder creates no native liability because its collateral is quote. Before
fees the caller's native output is `f`; for native fee `g`, A6 gives `0 <= g <= f`, the caller
receives `f - g`, and the fee recipient receives `g`. Therefore

`Delta(E) = -(f - g) - g = -f = Delta(L_ETH)`.

This covers underfill, exact fill, aggregate fill, a partially retained ask, and any bid remainder.

### 8.2 Incoming ask

If an incoming ask fills `f` bid quantity, bid-maker native liabilities increase by `f`. If
unmatched quantity `r` rests as a new ask, that order creates another native liability `r`. The
production delta is `-(f + r)`. For supplied value `V >= f + r`, `_nativeRefund` computes
`R = V - (f + r)` and the outer entrypoint returns `R` after settlement and fees. An ask's outgoing
asset is token1, so its fill fee is not native. Hence

`Delta(E) = V - R = f + r = Delta(L_ETH)`.

Setting `r = 0` covers `noRest`, full matching, and historical-book fills.

### 8.3 Cancel and claim

Canceling an ask with remaining quantity `q` removes liability `q` and pays exactly `q` native.
Canceling or claiming a bid with original quantity `q0` and remaining quantity `q` removes liability
`q0 - q` and pays exactly that amount. Fully filled and wholly unfilled orders are the endpoint
cases `q = 0` and `q = q0`. Thus both transitions preserve `S`.

### 8.4 Routes and external credits

For each route leg `i`, Sections 8.1-8.2 prove

`Delta(L_i) = -Delta(user_i) - fee_i`.

Summing over a finite route gives

`Delta(L_ETH) = -D_ETH - F_ETH`,

where `D_ETH` is the net caller-relative native delta and `F_ETH` is the accumulated native fee.
Let `V >= max(-D_ETH, 0)` be supplied `msg.value` and
`R = V - max(-D_ETH, 0)` its refund. Settlement receives `V`, pays `max(D_ETH, 0)`, then pays
`F_ETH`, and finally returns `R`. The identity
`V - R - max(D, 0) = -D` proves `Delta(E) = Delta(L_ETH)`.

Tree restructuring, nonce/epoch changes, fee configuration, and hook configuration do not themselves
move ETH or change native order quantities. A failed operation preserves both values by atomic
rollback. A successful recipient or hook callback may force an unsolicited credit `c >= 0`; this
changes `S` to `S + c` and therefore cannot violate solvency.

These cases exhaust every public transition. Induction on history length proves `E >= L_ETH` for
every finite reachable history, including arbitrary unsolicited credits. In the restricted history
class with no such credits, the same induction proves the stronger equality `E = L_ETH`.

## 9. Routes, Fees, And Multiple Pools

For token `x`, let `Delta_i(x)` be leg `i`'s caller-relative delta. `_addDelta` implements the
induction

`D_(i+1)(x) = D_i(x) + Delta_i(x)`.

Checked signed addition either stores the exact mathematical prefix sum or reverts the whole route.
Deduplicated touched lists affect only how many times a slot is settled, not its value. Positive
deltas are paid, negative deltas are pulled, and fee slots are paid afterward. Under exact-transfer
semantics, engine balance change is `-D(x)-F(x)` and user plus engine plus fee-recipient balances are
conserved.

For every legal basis-point rate, the fee proof establishes

`fee = floor(grossOutput * bps / 10_000)` and `grossOutput = netOutput + fee`.

Only a positive matched taker output reaches `_applyFillFee`; unmatched/resting input and every
cancel/claim bypass it. Resting a remainder therefore cannot defer or evade the fee on the portion
already filled.

Books, pool state and owner records are keyed by their derived hashes. Subject to Keccak collision
resistance, updates to distinct ids modify disjoint persistent slots. Operations on distinct pools
therefore commute except for intentionally shared token delta/fee accumulators inside one route and
owner-controlled global fee configuration.

## 10. Hooks And Reentrancy

The modifier checks the single transient guard, sets it before the body, and clears it only after the
body. Every token transfer and hook callback occurs while it is set. A callback to `fill`,
`fillRoute`, or `cancel` therefore reverts before mutation. On any outer revert, EVM frame rollback
restores the prior transient and persistent state.

Top-order tracking follows the same rightmost induction as matching:

- insertion records only when an empty side gains a top or the new key exceeds the old maximum;
- partial top fill records the retained nonce and outgoing amount;
- full top removal records the rightmost nonce of the rebuilt replacement, or zero for empty; and
- left-side changes disable hook propagation because they cannot change the maximum key.

The router consumes these transient values after book mutation. It calls the configured hook with a
200,000-gas cap and ignores success data. Under Cancun call isolation, a hook revert rolls back the
hook frame and is caught, leaving book and settlement state unchanged. This is a safety theorem, not
a delivery theorem: insufficient outer gas can still revert the transaction, and a failed hook may
miss a notification.

## 11. Termination And Liveness Boundary

Every radix recursion increases depth and has at most 64 key bits. Every subtree quote recursion
enters a strict child with fewer nodes. Every route loop increases its index toward a finite calldata
length, and every touched-list scan increases its index toward a finite in-memory count. These
well-founded measures prove termination for every finite valid input in the unmetered semantics.

They do not provide a state-independent block-gas bound. A mixed subtree quote can visit every mixed
descendant, route work is additive in legs, and touched-token deduplication is quadratic in distinct
route tokens. Thus for each concrete successful call there exists finite required gas, but a caller
supplying less gas or constructing work above a chain's block limit reverts atomically. No stronger
unconditional EVM liveness claim is possible.

## 12. History Theorem

The empty protocol state satisfies `B`. Sections 2 through 10 prove that every successful primitive
transition preserves `B`; failed transitions preserve it by EVM atomic rollback. Induction on history
length therefore proves `B` for every finite valid history within the guarded epoch namespace.

The theorem is conditional only where unavoidable: compiler/EVM semantics, Keccak collision
resistance, exact-transfer configured tokens, and the explicitly trusted transcendental reference
used to certify the tick table. Arbitrarily malicious token accounting, guaranteed hook delivery,
an actually infinite injective namespace, and execution under every block gas limit are not claimed.
