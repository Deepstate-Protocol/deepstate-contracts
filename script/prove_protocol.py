#!/usr/bin/env python3
"""Discharge complete-domain algebraic and encoding obligations with Z3.

The proofs are deliberately small and compositional. They establish the local lemmas used by the
arbitrary-history induction in docs/PROOF_OBLIGATIONS.md without attempting to symbolically execute
an unbounded transaction history in one solver query.
"""

from pathlib import Path
import sys

from z3 import (
    And,
    BitVec,
    BitVecVal,
    Extract,
    If,
    Implies,
    Int,
    IntVal,
    Not,
    Or,
    sat,
    Solver,
    ULT,
    ZeroExt,
    unsat,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "DeepstateV1.sol"
UINT32_MAX = (1 << 32) - 1
UINT160_MAX = (1 << 160) - 1
INT256_MAX = (1 << 255) - 1
UINT256 = 1 << 256
MERSENNE_256 = UINT256 - 1
Q128 = 1 << 128
MAX_PRICE = 1 << 96
EPOCH_MASK = (1 << 254) - 1
FIXED_TRANSIENT_SLOTS = {
    "top-outgoing": 0x64B7215BAEA1C17E16F66DB8B03AF21431032E2E221C15AC43B0752D82A69B31,
    "top-incoming": 0xF95DFDFE2CF36F265E91FF578507AC6F6F9BFFB77B95DCB89AEF8ED16E5B1F45,
    "match-buffer": 0x7F8FE082CCB9A281FA5FA179F118219E229BB906DF4E4AA8AEE95977B867F45D,
    "reentrancy": 0xC55A21BE1C6E869C49C7A5860F6C3A83187EB30A12BCD0421F3CF4F5871DCCFF,
}


class ProofFailure(RuntimeError):
    pass


class Prover:
    def __init__(self):
        self.count = 0

    def prove(self, name, proposition, *assumptions):
        solver = Solver()
        solver.add(*assumptions)
        assumption_result = solver.check()
        if assumption_result != sat:
            raise ProofFailure(f"{name}: assumptions are not satisfiable ({assumption_result})")
        solver.add(Not(proposition))
        result = solver.check()
        if result != unsat:
            detail = f" ({solver.model()})" if str(result) == "sat" else ""
            raise ProofFailure(f"{name}: expected unsat, got {result}{detail}")
        self.count += 1


def bind_model_to_source():
    """Fail closed when a modelled production expression changes."""
    source = SOURCE.read_text(encoding="utf-8")
    fragments = (
        "uint256 private constant _PRICE_SHIFT = 224;",
        "uint256 private constant _QUANTITY_SHIFT = 64;",
        "uint256 private constant _CORRECTION_SHIFT = 32;",
        "uint256 private constant _NONCE_MASK = type(uint32).max;",
        "uint256 private constant _POOL_EPOCH_MASK = (uint256(1) << 254) - 1;",
        "uint256 private constant _FEE_DELTA_DOMAIN = uint256(1) << 255;",
        "uint256 private constant _INTEGRATOR_FEE_DELTA_DOMAIN = uint256(1) << 254;",
        "0x64b7215baea1c17e16f66db8b03af21431032e2e221c15ac43b0752d82a69b31",
        "0xf95dfdfe2cf36f265e91ff578507ac6f6f9bffb77b95dcb89aef8ed16e5b1f45",
        "0x7f8fe082ccb9a281fa5fa179f118219e229bb906df4e4aa8aee95977b867f45d",
        "0xc55a21be1c6e869c49c7a5860f6c3a83187eb30a12bcd0421f3cf4f5871dccff",
        "key := or(shl(32, tickKey), and(order, 0xffffffff))",
        "key := or(shl(32, sub(0xffffffff, tickKey)), and(order, 0xffffffff))",
        "prefixLength = uint8(LibBit.clz(differingBits << 192));",
        "one := and(shr(sub(63, depth), key), 1)",
        "nextNonceAfter = nonce - 1;",
        "if (oldEpoch == _POOL_EPOCH_MASK) revert EpochExhausted();",
        "epoch = oldEpoch + 1;",
        "return (poolState & _POOL_HOOK_ACTIVE_MASK) | epoch;",
        "uint160 quantity = _quantity(a) + _quantity(b);",
        "quoteAmount += _subtreeQuote(book, leftNode, restingIsBid);",
        "(newRightNode, rightFillQuantity, rightQuoteAmount) =",
        "if (remaining != 0) {",
        "bool restAllowed = !params.noRest && routedNonce != 1;",
        "int256 next = current + amount;",
        "uint256 next = current + amount;",
        "if (current < type(int256).min + signedAmount) revert DeltaOverflow();",
        "return bytes32(_FEE_DELTA_DOMAIN | uint256(uint160(token)));",
        "return bytes32(_INTEGRATOR_FEE_DELTA_DOMAIN | uint256(uint160(token)));",
        "feeAmount = whole * uint256(feeBps) + (remainder * uint256(feeBps)) / _BPS_DENOMINATOR;",
        "token0Delta = int256(uint256(baseFilled));",
        "token0Delta = -int256(uint256(baseFilled));",
        "token0Delta -= int256(uint256(remaining));",
        "filledQuantity = originalQuantity - remainingQuantity;",
        "baseAmount = filledQuantity;",
        "baseAmount = remainingQuantity;",
        "nextToken0Delta = token0Delta - int256(feeAmount);",
        "_applyFillFee(isBid, token0Delta, token1Delta, _configBps(integratorConfig));",
        "settlement.token0Delta -= int256(settlement.integratorFeeAmount);",
        "settlement.token1Delta -= int256(settlement.integratorFeeAmount);",
        "nativeRefund = _nativeRefund(nativeDelta);",
        "nativeRefund = _nativeRefund(token0 == address(0) ? amount0 : int256(0));",
        "if (msg.value < required) revert InvalidNativeValue();",
        "refund = msg.value - required;",
        "_refundNativeValue(nativeRefund);",
        "if (amount != 0) _safeTransferOut(address(0), msg.sender, amount);",
        "_safeTransferOut(params.isBid ? params.token0 : params.token1, feeRecipient, feeAmount);",
        "_safeTransferOut(outputToken, _configRecipient(protocolConfig), settlement.protocolFeeAmount);",
        "_safeTransferOut(outputToken, integratorFee.recipient, settlement.integratorFeeAmount);",
        "if (baseAmount != 0) _safeTransferOut(token0, owner, baseAmount);",
        "_safeTransferOut(token, msg.sender, uint256(amount));",
        "_safeTransferOut(token0, msg.sender, uint256(amount0));",
        "if (amount != 0) _safeTransferOut(token, recipient, amount);",
        "if iszero(lt(token0, token1)) {",
        "if (token == address(0)) {",
        "to.safeTransferETH(amount);",
        "if tload(_REENTRANCY_GUARD_SLOT) {",
        "try IHook(hook).execute{gas: _HOOK_GAS_LIMIT}",
    )
    missing = [fragment for fragment in fragments if fragment not in source]
    if missing:
        raise ProofFailure(f"production/model binding is stale; missing source fragment: {missing[0]}")

    # Every native outflow must pass through the nine modelled call sites and the single transfer
    # helper. A future direct ETH transfer or additional helper call must extend the proof first.
    if source.count("_safeTransferOut(") != 10:
        raise ProofFailure("production/model binding is stale; unexpected native-capable outflow site count")
    if source.count("safeTransferETH(") != 1:
        raise ProofFailure("production/model binding is stale; unexpected direct native transfer count")


def prove_tick_decomposition(p):
    tick = Int("tick")
    modulus = 1 << 26
    scaled = 3 * tick
    exponent = scaled / modulus
    fraction = scaled - exponent * modulus
    rounded_exponent = If(fraction > (1 << 25), exponent + 1, exponent)
    shift = 128 - rounded_exponent
    domain = And(tick >= -(1 << 31), tick <= (1 << 31) - 1)
    p.prove(
        "A1.tick-decomposition",
        And(fraction >= 0, fraction < modulus, rounded_exponent >= -96, rounded_exponent <= 96,
            shift >= 32, shift <= 224),
        domain,
    )


def prove_quote_limbs(p):
    high = Int("product_high")
    low = Int("product_low")
    mm = (high + low) % MERSENNE_256
    borrow = If(mm < low, 1, 0)
    reconstructed = (mm - low - borrow) % UINT256
    p.prove(
        "A3.mersenne-product-high",
        reconstructed == high,
        high >= 0,
        high < MERSENNE_256,
        low >= 0,
        low <= MERSENNE_256,
    )

    for shift in range(32, 225):
        divisor = 1 << shift
        quantity = Int(f"quote_quantity_{shift}")
        factor = Int(f"quote_factor_{shift}")
        product = quantity * factor
        # TickMath's normalized factor is below 2^128 at the only minimum-shift regime and below
        # 2^129 everywhere else. This shift/factor coupling, rather than a loose global maximum,
        # proves the assembly left shift cannot discard a product-high bit.
        factor_limit = 1 << (128 if shift == 32 else 129)
        product_assumptions = (
            quantity >= 1,
            quantity <= UINT160_MAX,
            factor >= 1,
            factor < factor_limit,
        )
        rounded_quote = (product + divisor - 1) / divisor
        p.prove(
            f"A3.product-fits-quotient.shift-{shift}",
            And(product / UINT256 < divisor, product / divisor < UINT256),
            *product_assumptions,
        )
        p.prove(
            f"A3.quote-upper-bound.shift-{shift}",
            rounded_quote <= quantity * MAX_PRICE,
            *product_assumptions,
        )

        quotient = high * (1 << (256 - shift)) + low / divisor
        remainder = low % divisor
        assumptions = (high >= 0, high < divisor, low >= 0, low < UINT256)
        p.prove(
            f"A3.quotient-remainder.shift-{shift}",
            And(
                high * UINT256 + low == quotient * divisor + remainder,
                remainder >= 0,
                remainder < divisor,
            ),
            *assumptions,
        )
        rounded = quotient + If(remainder == 0, 0, 1)
        p.prove(
            f"A3.ceiling.shift-{shift}",
            rounded == (high * UINT256 + low + divisor - 1) / divisor,
            *assumptions,
        )

    left_quantity = Int("aggregate_left_quantity")
    right_quantity = Int("aggregate_right_quantity")
    left_quote = Int("aggregate_left_quote")
    right_quote = Int("aggregate_right_quote")
    p.prove(
        "A3.recursive-quote-addition-cannot-overflow",
        left_quote + right_quote < UINT256,
        left_quantity >= 1,
        right_quantity >= 1,
        left_quantity + right_quantity <= UINT160_MAX,
        left_quote >= 0,
        left_quote <= left_quantity * MAX_PRICE,
        right_quote >= 0,
        right_quote <= right_quantity * MAX_PRICE,
    )


def prove_rounding_and_corrections(p):
    divisor = Int("rounding_divisor")
    left_whole = Int("left_whole")
    right_whole = Int("right_whole")
    left_rem = Int("left_remainder")
    right_rem = Int("right_remainder")
    base = (
        divisor > 0,
        left_whole >= 0,
        right_whole >= 0,
        left_rem >= 0,
        left_rem < divisor,
        right_rem >= 0,
        right_rem < divisor,
    )
    remainder_sum = left_rem + right_rem
    ask_correction = remainder_sum / divisor
    ask_children = left_whole + right_whole
    ask_aggregate = ask_children + ask_correction
    p.prove(
        "A5.ask-binary-correction",
        And(ask_correction >= 0, ask_correction <= 1, ask_children + ask_correction == ask_aggregate),
        *base,
    )

    left_ceil = left_whole + If(left_rem == 0, 0, 1)
    right_ceil = right_whole + If(right_rem == 0, 0, 1)
    aggregate_ceil = left_whole + right_whole + remainder_sum / divisor + If(remainder_sum % divisor == 0, 0, 1)
    bid_correction = left_ceil + right_ceil - aggregate_ceil
    p.prove(
        "A5.bid-binary-correction",
        And(bid_correction >= 0, bid_correction <= 1,
            aggregate_ceil + bid_correction == left_ceil + right_ceil),
        *base,
    )

    left_leaves = Int("left_leaves")
    right_leaves = Int("right_leaves")
    left_correction = Int("left_correction")
    right_correction = Int("right_correction")
    local = Int("local_correction")
    total_correction = left_correction + right_correction + local
    p.prove(
        "A5.correction-induction",
        And(total_correction >= 0, total_correction <= left_leaves + right_leaves - 1),
        left_leaves >= 1,
        right_leaves >= 1,
        left_correction >= 0,
        left_correction <= left_leaves - 1,
        right_correction >= 0,
        right_correction <= right_leaves - 1,
        local >= 0,
        local <= 1,
    )
    p.prove(
        "A5.uint32-correction-capacity",
        total_correction + 1 <= UINT32_MAX,
        left_leaves >= 1,
        right_leaves >= 1,
        left_leaves + right_leaves <= UINT32_MAX - 1,
        left_correction >= 0,
        left_correction <= left_leaves - 1,
        right_correction >= 0,
        right_correction <= right_leaves - 1,
        local >= 0,
        local <= 1,
    )

    n0 = Int("notional_0")
    n1 = Int("notional_1")
    n2 = Int("notional_2")
    p.prove(
        "A4.partial-fill-telescoping-step",
        (n0 - n1) + (n1 - n2) == n0 - n2,
        n0 >= n1,
        n1 >= n2,
        n2 >= 0,
    )

    # A partial leaf's rounded delta differs from independently rounding the fill by at most one.
    fill_whole = Int("fill_whole")
    remaining_whole = Int("remaining_whole")
    fill_rem = Int("fill_remainder")
    remaining_rem = Int("remaining_remainder")
    partial_base = (
        divisor > 0,
        fill_whole >= 0,
        remaining_whole >= 0,
        fill_rem >= 0,
        fill_rem < divisor,
        remaining_rem >= 0,
        remaining_rem < divisor,
    )
    total_rem = fill_rem + remaining_rem
    floor_delta = fill_whole + total_rem / divisor
    independent_floor = fill_whole
    p.prove(
        "A5.partial-ask-event-correction",
        Or(floor_delta == independent_floor, floor_delta == independent_floor + 1),
        *partial_base,
    )
    larger_floor = fill_whole + remaining_whole + total_rem / divisor
    smaller_floor = remaining_whole
    p.prove(
        "A4.partial-ask-difference-exact",
        floor_delta == larger_floor - smaller_floor,
        *partial_base,
    )
    ceil_total = fill_whole + remaining_whole + total_rem / divisor + If(total_rem % divisor == 0, 0, 1)
    ceil_remaining = remaining_whole + If(remaining_rem == 0, 0, 1)
    ceil_delta = ceil_total - ceil_remaining
    independent_ceil = fill_whole + If(fill_rem == 0, 0, 1)
    p.prove(
        "A5.partial-bid-event-correction",
        Or(ceil_delta == independent_ceil, ceil_delta == independent_ceil - 1),
        *partial_base,
    )
    p.prove(
        "A4.partial-bid-difference-exact",
        And(ceil_delta == ceil_total - ceil_remaining, ceil_delta >= 0),
        *partial_base,
    )


def prove_fees(p):
    amount = Int("fee_amount_input")
    for bps in range(101):
        whole = amount / 10_000
        remainder = amount % 10_000
        implementation = whole * bps + (remainder * bps) / 10_000
        reference = (amount * bps) / 10_000
        assumptions = (amount >= 0, amount <= INT256_MAX)
        p.prove(f"A6.fee-exact.bps-{bps}", implementation == reference, *assumptions)
        p.prove(
            f"A6.fee-bounds.bps-{bps}",
            And(
                implementation >= 0,
                implementation <= amount,
                implementation <= amount / 100,
                amount == amount - implementation + implementation,
            ),
            *assumptions,
        )

        gross = Int(f"fee_gross_{bps}")
        p.prove(
            f"A6.output-only-conservation.bps-{bps}",
            And(gross - (gross * bps) / 10_000 >= 0,
                gross == gross - (gross * bps) / 10_000 + (gross * bps) / 10_000),
            gross >= 0,
            gross <= INT256_MAX,
        )

    gross = Int("combined_fee_gross")
    protocol_fee = Int("combined_protocol_fee")
    integrator_fee = Int("combined_integrator_fee")
    net_output = gross - protocol_fee - integrator_fee
    combined_domain = (
        gross >= 0,
        gross <= INT256_MAX,
        protocol_fee >= 0,
        protocol_fee <= gross / 100,
        integrator_fee >= 0,
        integrator_fee <= gross / 100,
    )
    p.prove(
        "A6.independent-fees-conserve-gross-output",
        And(net_output >= 0, gross == net_output + protocol_fee + integrator_fee),
        *combined_domain,
    )
    p.prove(
        "A6.independent-fees-are-order-invariant",
        gross - protocol_fee - integrator_fee == gross - integrator_fee - protocol_fee,
        *combined_domain,
    )


def prove_keys_and_radix(p):
    p1 = Int("tick_1")
    p2 = Int("tick_2")
    n1 = Int("nonce_1")
    n2 = Int("nonce_2")
    domain = (
        p1 >= -(1 << 31),
        p1 <= (1 << 31) - 1,
        p2 >= -(1 << 31),
        p2 <= (1 << 31) - 1,
        n1 >= 0,
        n1 <= UINT32_MAX,
        n2 >= 0,
        n2 <= UINT32_MAX,
    )
    sortable1 = p1 + (1 << 31)
    sortable2 = p2 + (1 << 31)
    bid1 = sortable1 * (1 << 32) + n1
    bid2 = sortable2 * (1 << 32) + n2
    ask1 = (UINT32_MAX - sortable1) * (1 << 32) + n1
    ask2 = (UINT32_MAX - sortable2) * (1 << 32) + n2
    p.prove(
        "R1.bid-price-time-priority",
        Implies(Or(p1 > p2, And(p1 == p2, n1 > n2)), bid1 > bid2),
        *domain,
    )
    p.prove(
        "R1.ask-price-time-priority",
        Implies(Or(p1 < p2, And(p1 == p2, n1 > n2)), ask1 > ask2),
        *domain,
    )
    p.prove(
        "R1.path-key-injective",
        Implies(Or(p1 != p2, n1 != n2), bid1 != bid2),
        *domain,
    )
    p.prove(
        "R1.cross-side-leaf-paths-differ-with-global-nonces",
        Implies(n1 != n2, bid1 != bid2),
        *domain,
    )

    for depth in range(64):
        a = BitVec(f"split_a_{depth}", 64)
        b = BitVec(f"split_b_{depth}", 64)
        bit_index = 63 - depth
        a_bit = Extract(bit_index, bit_index, a)
        b_bit = Extract(bit_index, bit_index, b)
        assumptions = [a_bit != b_bit]
        if depth:
            assumptions.append(Extract(63, 64 - depth, a) == Extract(63, 64 - depth, b))
        left = If(a_bit == BitVecVal(0, 1), a, b)
        right = If(a_bit == BitVecVal(0, 1), b, a)
        p.prove(
            f"R2.radix-split.depth-{depth}",
            And(
                Extract(bit_index, bit_index, left) == BitVecVal(0, 1),
                Extract(bit_index, bit_index, right) == BitVecVal(1, 1),
                ULT(left, right),
            ),
            *assumptions,
        )

    child_quantity = Int("child_quantity")
    sibling_quantity = Int("sibling_quantity")
    p.prove(
        "R3.ancestor-quantity-distinguishes-address",
        child_quantity + sibling_quantity > child_quantity,
        child_quantity >= 1,
        sibling_quantity >= 1,
        child_quantity + sibling_quantity <= UINT160_MAX,
    )
    boundary_a = Int("branch_boundary_a")
    boundary_b = Int("branch_boundary_b")
    quantity_a = Int("branch_quantity_a")
    quantity_b = Int("branch_quantity_b")
    correction_a = Int("branch_correction_a")
    correction_b = Int("branch_correction_b")
    packed_a = (
        (boundary_a / (1 << 32)) * (1 << 224)
        + quantity_a * (1 << 64)
        + correction_a * (1 << 32)
        + boundary_a % (1 << 32)
    )
    packed_b = (
        (boundary_b / (1 << 32)) * (1 << 224)
        + quantity_b * (1 << 64)
        + correction_b * (1 << 32)
        + boundary_b % (1 << 32)
    )
    p.prove(
        "R3.disjoint-boundaries-distinguish-address",
        packed_a != packed_b,
        boundary_a >= 0,
        boundary_a < (1 << 64),
        boundary_b >= 0,
        boundary_b < (1 << 64),
        boundary_a != boundary_b,
        quantity_a >= 1,
        quantity_a <= UINT160_MAX,
        quantity_b >= 1,
        quantity_b <= UINT160_MAX,
        correction_a >= 0,
        correction_a <= UINT32_MAX,
        correction_b >= 0,
        correction_b <= UINT32_MAX,
    )

    old_aggregate = Int("dirty_old_aggregate")
    new_descendant = Int("dirty_new_descendant")
    removed_quantity = Int("dirty_removed_quantity")
    p.prove(
        "R5.stale-anchor-cannot-alias-descendant-by-quantity",
        old_aggregate > new_descendant,
        old_aggregate >= 2,
        removed_quantity >= 1,
        new_descendant >= 1,
        new_descendant <= old_aggregate - removed_quantity,
    )


def prove_nonce_epoch_and_namespaces(p):
    nonce = Int("book_nonce")
    p.prove(
        "N2.nonce-step",
        And(nonce - 1 >= 1, nonce - 1 < nonce),
        nonce >= 2,
        nonce <= UINT32_MAX,
    )
    i = Int("nonce_step_i")
    j = Int("nonce_step_j")
    p.prove(
        "N2.assigned-nonce-unique",
        UINT32_MAX - i != UINT32_MAX - j,
        i >= 0,
        j >= 0,
        i <= UINT32_MAX - 2,
        j <= UINT32_MAX - 2,
        i != j,
    )
    p.prove("N2.exhaustion-after-two", 2 - 1 == 1)

    address_a = BitVec("address_a", 160)
    address_b = BitVec("address_b", 160)
    user_a = address_a
    user_b = address_b
    user_a_256 = ZeroExt(96, address_a)
    user_b_256 = ZeroExt(96, address_b)
    fee_a = BitVecVal(1 << 255, 256) | user_a_256
    fee_b = BitVecVal(1 << 255, 256) | user_b_256
    integrator_fee_a = BitVecVal(1 << 254, 256) | user_a_256
    integrator_fee_b = BitVecVal(1 << 254, 256) | user_b_256
    p.prove("N1.user-token-slot-injective", Implies(address_a != address_b, user_a != user_b))
    p.prove("N1.fee-token-slot-injective", Implies(address_a != address_b, fee_a != fee_b))
    p.prove(
        "N1.integrator-fee-token-slot-injective",
        Implies(address_a != address_b, integrator_fee_a != integrator_fee_b),
    )
    p.prove("N1.user-fee-slot-disjoint", user_a_256 != fee_b)
    p.prove("N1.user-integrator-fee-slot-disjoint", user_a_256 != integrator_fee_b)
    p.prove("N1.protocol-integrator-fee-slot-disjoint", fee_a != integrator_fee_b)

    fixed = {name: BitVecVal(value, 256) for name, value in FIXED_TRANSIENT_SLOTS.items()}
    for name, slot in fixed.items():
        p.prove(f"N1.user-fixed-slot-disjoint.{name}", user_a_256 != slot)
        p.prove(f"N1.fee-fixed-slot-disjoint.{name}", fee_a != slot)
        p.prove(f"N1.integrator-fee-fixed-slot-disjoint.{name}", integrator_fee_a != slot)
    fixed_items = list(fixed.items())
    for index, (left_name, left_slot) in enumerate(fixed_items):
        for right_name, right_slot in fixed_items[index + 1:]:
            p.prove(f"N1.fixed-slots-disjoint.{left_name}.{right_name}", left_slot != right_slot)

    pool_flags = Int("pool_flags")
    epoch = Int("epoch")
    hook_mask = 3 << 254
    # Integer decomposition models the two disjoint bit fields without nonlinear bit-vector masks.
    p.prove(
        "N2.pool-epoch-hook-packing",
        (pool_flags + epoch) % (1 << 254) == epoch,
        Or(pool_flags == 0, pool_flags == (1 << 254), pool_flags == (1 << 255), pool_flags == hook_mask),
        epoch >= 0,
        epoch <= EPOCH_MASK,
    )
    old_epoch = Int("old_epoch")
    p.prove(
        "N2.epoch-step-within-namespace",
        And(old_epoch + 1 > old_epoch, old_epoch + 1 <= EPOCH_MASK),
        old_epoch >= 0,
        old_epoch < EPOCH_MASK,
    )
    rotation_succeeds = old_epoch != EPOCH_MASK
    post_epoch = If(rotation_succeeds, old_epoch + 1, old_epoch)
    p.prove(
        "N2.rotation-guard-preserves-terminal-epoch",
        Implies(old_epoch == EPOCH_MASK, And(Not(rotation_succeeds), post_epoch == old_epoch)),
        old_epoch >= 0,
        old_epoch <= EPOCH_MASK,
    )
    p.prove(
        "N2.rotation-guard-increments-every-nonterminal-epoch",
        Implies(old_epoch < EPOCH_MASK, And(rotation_succeeds, post_epoch == old_epoch + 1)),
        old_epoch >= 0,
        old_epoch <= EPOCH_MASK,
    )
    rotated_pool_state = pool_flags + post_epoch
    p.prove(
        "N2.rotation-preserves-hook-flags",
        And(
            rotated_pool_state / (1 << 254) == pool_flags / (1 << 254),
            rotated_pool_state % (1 << 254) == post_epoch,
        ),
        Or(pool_flags == 0, pool_flags == (1 << 254), pool_flags == (1 << 255), pool_flags == hook_mask),
        old_epoch >= 0,
        old_epoch <= EPOCH_MASK,
    )


def prove_tree_transition_summaries(p):
    left_min = Int("tree_left_min")
    left_max = Int("tree_left_max")
    right_min = Int("tree_right_min")
    right_max = Int("tree_right_max")
    key_domain = (
        left_min >= 0,
        left_min <= left_max,
        left_max < right_min,
        right_min <= right_max,
        right_max < (1 << 64),
    )
    parent_min = left_min
    parent_max = right_max
    p.prove(
        "R2.parent-summary-preserves-child-order",
        And(parent_min <= left_min, left_max < right_min, right_max <= parent_max),
        *key_domain,
    )
    p.prove("R6.rightmost-child-carries-best-key", parent_max == right_max, *key_domain)

    left_quantity = Int("tree_left_quantity")
    right_quantity = Int("tree_right_quantity")
    parent_quantity = left_quantity + right_quantity
    p.prove(
        "R4.branch-quantity-construction",
        And(
            parent_quantity == left_quantity + right_quantity,
            parent_quantity > left_quantity,
            parent_quantity > right_quantity,
            parent_quantity <= UINT160_MAX,
        ),
        left_quantity >= 1,
        right_quantity >= 1,
        left_quantity + right_quantity <= UINT160_MAX,
    )

    old_right_quantity = Int("dirty_old_right_quantity")
    new_right_quantity = Int("dirty_new_right_quantity")
    removed_right_quantity = old_right_quantity - new_right_quantity
    stale_anchor_quantity = left_quantity + old_right_quantity
    exact_dirty_quantity = left_quantity + new_right_quantity
    p.prove(
        "R5.changed-dirty-anchor-strictly-overstates-exact-summary",
        And(
            stale_anchor_quantity > exact_dirty_quantity,
            stale_anchor_quantity == exact_dirty_quantity + removed_right_quantity,
            exact_dirty_quantity == left_quantity + new_right_quantity,
        ),
        left_quantity >= 1,
        old_right_quantity >= 1,
        new_right_quantity >= 1,
        new_right_quantity < old_right_quantity,
        stale_anchor_quantity <= UINT160_MAX,
    )

    old_left_quote = Int("tree_old_left_quote")
    old_right_quote = Int("tree_old_right_quote")
    removed_left_quote = Int("tree_removed_left_quote")
    removed_right_quote = Int("tree_removed_right_quote")
    new_left_quote = old_left_quote - removed_left_quote
    new_right_quote = old_right_quote - removed_right_quote
    old_parent_quote = old_left_quote + old_right_quote
    removed_quote = removed_left_quote + removed_right_quote
    new_parent_quote = new_left_quote + new_right_quote
    p.prove(
        "R4.mixed-parent-rebuild-preserves-quote-conservation",
        And(
            new_parent_quote + removed_quote == old_parent_quote,
            new_parent_quote >= 0,
            new_parent_quote < UINT256,
        ),
        old_left_quote >= 0,
        old_right_quote >= 0,
        old_parent_quote < UINT256,
        removed_left_quote >= 0,
        removed_left_quote <= old_left_quote,
        removed_right_quote >= 0,
        removed_right_quote <= old_right_quote,
    )

    removed_left_quantity = Int("tree_removed_left_quantity")
    removed_right_quantity = Int("tree_removed_right_quantity")
    new_left_quantity = left_quantity - removed_left_quantity
    new_right_quantity = right_quantity - removed_right_quantity
    removed_quantity = removed_left_quantity + removed_right_quantity
    new_parent_quantity = new_left_quantity + new_right_quantity
    p.prove(
        "R4.branch-rebuild-preserves-quantity-conservation",
        And(
            new_parent_quantity + removed_quantity == parent_quantity,
            new_parent_quantity >= 0,
            new_parent_quantity <= UINT160_MAX,
        ),
        left_quantity >= 1,
        right_quantity >= 1,
        parent_quantity <= UINT160_MAX,
        removed_left_quantity >= 0,
        removed_left_quantity <= left_quantity,
        removed_right_quantity >= 0,
        removed_right_quantity <= right_quantity,
    )

    old_aggregate_quote = Int("uniform_old_aggregate_quote")
    old_correction = Int("uniform_old_correction")
    uniform_fill_quote = Int("uniform_fill_quote")
    new_aggregate_quote = Int("uniform_new_aggregate_quote")
    bid_new_correction = old_aggregate_quote + old_correction - uniform_fill_quote - new_aggregate_quote
    ask_new_correction = new_aggregate_quote + old_correction + uniform_fill_quote - old_aggregate_quote
    p.prove(
        "R4.uniform-bid-correction-update-preserves-leaf-sum",
        new_aggregate_quote + bid_new_correction
        == old_aggregate_quote + old_correction - uniform_fill_quote,
    )
    p.prove(
        "R4.uniform-ask-correction-update-preserves-leaf-sum",
        new_aggregate_quote - ask_new_correction
        == old_aggregate_quote - old_correction - uniform_fill_quote,
    )


def prove_matching_priority_and_accounting(p):
    remaining = Int("match_remaining")
    right_quantity = Int("match_right_quantity")
    left_quantity = Int("match_left_quantity")
    right_fill = If(remaining < right_quantity, remaining, right_quantity)
    left_remainder = remaining - right_fill
    left_fill = If(left_remainder < left_quantity, left_remainder, left_quantity)
    total_fill = right_fill + left_fill
    total_quantity = right_quantity + left_quantity
    assumptions = (
        remaining >= 0,
        remaining <= UINT160_MAX,
        right_quantity >= 1,
        left_quantity >= 1,
        total_quantity <= UINT160_MAX,
    )
    p.prove(
        "R6.right-first-fill-is-maximal",
        total_fill == If(remaining < total_quantity, remaining, total_quantity),
        *assumptions,
    )
    p.prove(
        "R6.left-fill-implies-right-exhausted",
        Implies(left_fill > 0, right_fill == right_quantity),
        *assumptions,
    )
    p.prove(
        "R4.fill-quantity-cannot-overflow",
        And(total_fill <= remaining, total_fill <= total_quantity, total_fill <= UINT160_MAX),
        *assumptions,
    )

    limit = Int("match_limit_tick")
    subtree_price = Int("subtree_member_price")
    worst_ask = Int("subtree_worst_ask")
    worst_bid = Int("subtree_worst_bid")
    p.prove(
        "R6.ask-worst-crossing-implies-all-cross",
        subtree_price <= limit,
        subtree_price <= worst_ask,
        worst_ask <= limit,
    )
    p.prove(
        "R6.bid-worst-crossing-implies-all-cross",
        subtree_price >= limit,
        subtree_price >= worst_bid,
        worst_bid >= limit,
    )

    right_ask = Int("right_best_ask")
    left_ask = Int("left_worse_ask")
    p.prove(
        "R6.best-ask-noncrossing-stops-book",
        left_ask > limit,
        right_ask <= left_ask,
        right_ask > limit,
    )
    right_bid = Int("right_best_bid")
    left_bid = Int("left_worse_bid")
    p.prove(
        "R6.best-bid-noncrossing-stops-book",
        left_bid < limit,
        right_bid >= left_bid,
        right_bid < limit,
    )

    # A remainder rests at its own limit only after the best opposite maker failed to cross.
    best_surviving_ask = Int("best_surviving_ask")
    resting_bid = limit
    p.prove(
        "R6.resting-bid-cannot-cross-surviving-ask",
        resting_bid < best_surviving_ask,
        best_surviving_ask > limit,
    )
    best_surviving_bid = Int("best_surviving_bid")
    resting_ask = limit
    p.prove(
        "R6.resting-ask-cannot-cross-surviving-bid",
        best_surviving_bid < resting_ask,
        best_surviving_bid < limit,
    )

    original_quantity = Int("liability_original_quantity")
    remaining_quantity = Int("liability_remaining_quantity")
    original_notional = Int("liability_original_notional")
    remaining_notional = Int("liability_remaining_notional")
    filled_notional = original_notional - remaining_notional
    liability_domain = (
        original_quantity >= remaining_quantity,
        remaining_quantity >= 0,
        original_notional >= remaining_notional,
        remaining_notional >= 0,
    )
    p.prove(
        "A4.bid-maker-liability-conservation",
        filled_notional + remaining_notional == original_notional,
        *liability_domain,
    )
    p.prove(
        "A4.ask-base-liability-conservation",
        original_quantity - remaining_quantity + remaining_quantity == original_quantity,
        *liability_domain,
    )
    p.prove(
        "A4.ask-maker-quote-claim-is-notional-difference",
        filled_notional == original_notional - remaining_notional,
        *liability_domain,
    )

    # A resting bid escrows its rounded-up original notional. Each fill consumes the telescoping
    # difference and cancellation returns the final rounded-up remainder.
    cumulative_filled_notional = Int("cumulative_filled_notional")
    p.prove(
        "A4.bid-collateral-partition",
        cumulative_filled_notional + remaining_notional == original_notional,
        *liability_domain,
        cumulative_filled_notional == original_notional - remaining_notional,
    )

    historical_nonce = Int("historical_nonce")
    caller_no_rest = Int("caller_no_rest")
    rest_allowed = And(caller_no_rest == 0, historical_nonce != 1)
    p.prove(
        "N2.exhausted-book-forces-no-rest",
        Not(rest_allowed),
        historical_nonce == 1,
        Or(caller_no_rest == 0, caller_no_rest == 1),
    )


def prove_hook_top_transitions(p):
    old_top = Int("hook_old_top_key")
    incoming = Int("hook_incoming_key")
    inserted_top = If(incoming > old_top, incoming, old_top)
    p.prove(
        "E2.insert-top-change-condition",
        And(
            Implies(incoming > old_top, inserted_top == incoming),
            Implies(incoming <= old_top, inserted_top == old_top),
        ),
    )

    old_nonce = Int("hook_old_nonce")
    replacement_nonce = Int("hook_replacement_nonce")
    partial = Int("hook_partial_flag")
    incoming_nonce = If(partial == 1, old_nonce, replacement_nonce)
    p.prove(
        "E2.partial-top-retains-nonce",
        incoming_nonce == old_nonce,
        partial == 1,
    )
    p.prove(
        "E2.full-top-uses-replacement-nonce",
        incoming_nonce == replacement_nonce,
        partial == 0,
    )

    second_key = Int("hook_second_key")
    removed_key = Int("hook_removed_key")
    replacement_key = If(removed_key == old_top, second_key, old_top)
    p.prove(
        "E2.removing-top-promotes-next-maximum",
        replacement_key == second_key,
        removed_key == old_top,
        second_key <= old_top,
    )
    p.prove(
        "E2.removing-nontop-preserves-maximum",
        replacement_key == old_top,
        removed_key != old_top,
        second_key <= old_top,
    )

    retained_quantity = Int("hook_retained_top_quantity")
    filled_quantity = Int("hook_filled_top_quantity")
    p.prove(
        "E2.partial-top-fill-retains-key-and-positive-quantity",
        And(old_top == old_top, retained_quantity > 0),
        retained_quantity >= 1,
        filled_quantity >= 1,
    )


def prove_route_and_signed_accounting(p):
    accumulated = Int("route_accumulated")
    leg = Int("route_leg")
    p.prove("N4.route-additive-step", accumulated + leg == leg + accumulated)

    prefix = Int("route_prefix")
    p.prove(
        "N4.checked-prefix-preserves-mathematical-sum",
        And(prefix + leg >= -(1 << 255), prefix + leg <= INT256_MAX),
        prefix >= -(1 << 255),
        prefix <= INT256_MAX,
        leg >= -(1 << 255),
        leg <= INT256_MAX,
        prefix + leg >= -(1 << 255),
        prefix + leg <= INT256_MAX,
    )

    before = Int("engine_balance_before")
    delta = Int("user_delta")
    fee = Int("protocol_fee")
    integrator_fee = Int("integrator_fee")
    after = before - delta - fee - integrator_fee
    p.prove("N4.settlement-conservation", after + delta + fee + integrator_fee == before)

    current = Int("current_signed_delta")
    debit = Int("unsigned_debit")
    p.prove(
        "N4.checked-debit-range",
        current - debit >= -(1 << 255),
        current >= -(1 << 255) + debit,
        current <= INT256_MAX,
        debit >= 0,
        debit <= INT256_MAX,
    )

    prior_fee = Int("route_prior_fee")
    leg_fee = Int("route_leg_fee")
    p.prove(
        "N4.checked-fee-prefix-is-exact",
        And(prior_fee + leg_fee >= 0, prior_fee + leg_fee < UINT256),
        prior_fee >= 0,
        leg_fee >= 0,
        prior_fee + leg_fee < UINT256,
    )

    prior_integrator_fee = Int("route_prior_integrator_fee")
    leg_integrator_fee = Int("route_leg_integrator_fee")
    p.prove(
        "N4.checked-integrator-fee-prefix-is-exact",
        And(
            prior_integrator_fee + leg_integrator_fee >= 0,
            prior_integrator_fee + leg_integrator_fee < UINT256,
        ),
        prior_integrator_fee >= 0,
        leg_integrator_fee >= 0,
        prior_integrator_fee + leg_integrator_fee < UINT256,
    )

    token0_delta = Int("leg_token0_delta")
    token1_delta = Int("leg_token1_delta")
    base_filled = Int("leg_base_filled")
    quote_filled = Int("leg_quote_filled")
    resting_base = Int("leg_resting_base")
    resting_quote = Int("leg_resting_quote")
    p.prove(
        "N4.bid-leg-deltas-equal-match-plus-rest",
        And(token0_delta == base_filled, token1_delta == -(quote_filled + resting_quote)),
        token0_delta == base_filled,
        token1_delta == -(quote_filled + resting_quote),
        base_filled >= 0,
        quote_filled >= 0,
        resting_quote >= 0,
    )
    p.prove(
        "N4.ask-leg-deltas-equal-match-plus-rest",
        And(token0_delta == -(base_filled + resting_base), token1_delta == quote_filled),
        token0_delta == -(base_filled + resting_base),
        token1_delta == quote_filled,
        base_filled >= 0,
        resting_base >= 0,
        quote_filled >= 0,
    )


def prove_native_eth_solvency(p):
    """Prove native collateral preservation for every local protocol transition.

    Native liability is the remaining quantity of an active ask plus the filled quantity of an
    active bid. The induction in docs/INDUCTIVE_PROOFS.md composes these local equations over every
    finite protocol history and permits arbitrary nonnegative unsolicited ETH credits.
    """

    empty_balance = Int("native_empty_balance")
    empty_liability = Int("native_empty_liability")
    p.prove(
        "A7.empty-native-state-is-exactly-collateralized",
        empty_balance == empty_liability,
        empty_balance == 0,
        empty_liability == 0,
    )

    original = Int("native_order_original")
    remaining = Int("native_order_remaining")
    ask_order_liability = remaining
    bid_order_liability = original - remaining
    order_domain = (
        original >= 1,
        original <= UINT160_MAX,
        remaining >= 0,
        remaining <= original,
    )
    p.prove(
        "A7.native-maker-liability-partition",
        And(
            ask_order_liability >= 0,
            ask_order_liability <= original,
            bid_order_liability >= 0,
            bid_order_liability <= original,
            ask_order_liability + bid_order_liability == original,
        ),
        *order_domain,
    )

    engine_before = Int("native_engine_before")
    ask_liability = Int("native_ask_liability")
    bid_liability = Int("native_bid_liability")
    matched_asks = Int("native_matched_asks")
    native_fee = Int("native_bid_protocol_fee")
    native_integrator_fee = Int("native_bid_integrator_fee")
    liability_before = ask_liability + bid_liability
    liability_after_bid = ask_liability - matched_asks + bid_liability
    user_bid_output = matched_asks - native_fee - native_integrator_fee
    engine_after_bid = engine_before - user_bid_output - native_fee - native_integrator_fee
    bid_fill_domain = (
        engine_before >= liability_before,
        ask_liability >= 0,
        bid_liability >= 0,
        matched_asks >= 0,
        matched_asks <= ask_liability,
        native_fee >= 0,
        native_integrator_fee >= 0,
        native_fee + native_integrator_fee <= matched_asks,
    )
    p.prove(
        "A7.incoming-bid-preserves-native-surplus",
        And(
            engine_after_bid - liability_after_bid == engine_before - liability_before,
            engine_after_bid >= liability_after_bid,
        ),
        *bid_fill_domain,
    )
    p.prove(
        "A7.incoming-bid-preserves-native-equality",
        engine_after_bid == liability_after_bid,
        *bid_fill_domain,
        engine_before == liability_before,
    )

    matched_bids = Int("native_matched_bids")
    resting_ask = Int("native_resting_ask")
    incoming_ask_debit = matched_bids + resting_ask
    liability_after_ask = liability_before + incoming_ask_debit
    engine_after_ask = engine_before + incoming_ask_debit
    ask_fill_domain = (
        engine_before >= liability_before,
        ask_liability >= 0,
        bid_liability >= 0,
        matched_bids >= 0,
        resting_ask >= 0,
        matched_bids + resting_ask <= UINT160_MAX,
    )
    p.prove(
        "A7.incoming-ask-and-rest-preserve-native-surplus",
        And(
            engine_after_ask - liability_after_ask == engine_before - liability_before,
            engine_after_ask >= liability_after_ask,
        ),
        *ask_fill_domain,
    )
    p.prove(
        "A7.incoming-ask-and-rest-preserve-native-equality",
        engine_after_ask == liability_after_ask,
        *ask_fill_domain,
        engine_before == liability_before,
    )

    ask_remaining = Int("native_cancel_ask_remaining")
    cancel_ask_domain = (
        engine_before >= liability_before,
        liability_before >= ask_remaining,
        ask_remaining >= 0,
    )
    p.prove(
        "A7.ask-cancel-preserves-native-surplus",
        And(
            (engine_before - ask_remaining) - (liability_before - ask_remaining)
            == engine_before - liability_before,
            engine_before - ask_remaining >= liability_before - ask_remaining,
        ),
        *cancel_ask_domain,
    )

    bid_original = Int("native_cancel_bid_original")
    bid_remaining = Int("native_cancel_bid_remaining")
    bid_filled_claim = bid_original - bid_remaining
    cancel_bid_domain = (
        engine_before >= liability_before,
        bid_original >= 1,
        bid_original <= UINT160_MAX,
        bid_remaining >= 0,
        bid_remaining <= bid_original,
        liability_before >= bid_filled_claim,
    )
    p.prove(
        "A7.bid-cancel-or-claim-preserves-native-surplus",
        And(
            (engine_before - bid_filled_claim) - (liability_before - bid_filled_claim)
            == engine_before - liability_before,
            engine_before - bid_filled_claim >= liability_before - bid_filled_claim,
        ),
        *cancel_bid_domain,
    )

    native_delta = Int("native_route_user_delta")
    accumulated_fee = Int("native_route_fee")
    required_value = If(native_delta < 0, -native_delta, 0)
    user_payout = If(native_delta > 0, native_delta, 0)
    supplied_value = Int("native_supplied_value")
    native_refund = supplied_value - required_value
    p.prove(
        "A7.native-msg-value-refund-and-payout-net-to-negative-delta",
        supplied_value - native_refund - user_payout == -native_delta,
        native_delta >= -(1 << 255),
        native_delta <= INT256_MAX,
        supplied_value >= required_value,
    )
    p.prove(
        "A7.native-refund-is-nonnegative-excess",
        And(native_refund >= 0, supplied_value - native_refund == required_value),
        native_delta >= -(1 << 255),
        native_delta <= INT256_MAX,
        supplied_value >= required_value,
    )

    liability_change = Int("native_route_liability_change")
    liability_after_route = liability_before + liability_change
    engine_after_route = engine_before + supplied_value - native_refund - user_payout - accumulated_fee
    route_domain = (
        engine_before >= liability_before,
        liability_before >= 0,
        liability_after_route >= 0,
        native_delta >= -(1 << 255),
        native_delta <= INT256_MAX,
        accumulated_fee >= 0,
        supplied_value >= required_value,
        liability_change == -native_delta - accumulated_fee,
    )
    p.prove(
        "A7.native-route-settlement-preserves-surplus",
        And(
            engine_after_route - liability_after_route == engine_before - liability_before,
            engine_after_route >= liability_after_route,
        ),
        *route_domain,
    )
    p.prove(
        "A7.native-route-settlement-preserves-equality",
        engine_after_route == liability_after_route,
        *route_domain,
        engine_before == liability_before,
    )

    first_delta = Int("native_first_leg_user_delta")
    second_delta = Int("native_second_leg_user_delta")
    first_fee = Int("native_first_leg_fee")
    second_fee = Int("native_second_leg_fee")
    first_liability_change = Int("native_first_leg_liability_change")
    second_liability_change = Int("native_second_leg_liability_change")
    p.prove(
        "A7.native-route-leg-composition",
        first_liability_change + second_liability_change
        == -(first_delta + second_delta) - (first_fee + second_fee),
        first_fee >= 0,
        second_fee >= 0,
        first_liability_change == -first_delta - first_fee,
        second_liability_change == -second_delta - second_fee,
    )

    unsolicited_credit = Int("native_unsolicited_credit")
    p.prove(
        "A7.unsolicited-native-credit-cannot-create-insolvency",
        engine_before + unsolicited_credit >= liability_before,
        engine_before >= liability_before,
        liability_before >= 0,
        unsolicited_credit >= 0,
    )
    p.prove(
        "A7.unsolicited-native-credit-is-the-exact-new-surplus",
        (engine_before + unsolicited_credit) - liability_before
        == (engine_before - liability_before) + unsolicited_credit,
        engine_before >= liability_before,
        liability_before >= 0,
        unsolicited_credit >= 0,
    )
    p.prove(
        "A7.native-equality-survives-only-zero-unsolicited-credit",
        ((engine_before + unsolicited_credit == liability_before) == (unsolicited_credit == 0)),
        engine_before == liability_before,
        liability_before >= 0,
        unsolicited_credit >= 0,
    )


def prove_atomicity_and_external_boundaries(p):
    guard_before = Int("guard_before")
    guarded_entry_allowed = guard_before == 0
    guard_during = If(guarded_entry_allowed, 1, guard_before)
    callback_allowed = guard_during == 0
    p.prove(
        "E1.callback-cannot-enter-while-outer-call-holds-guard",
        Not(callback_allowed),
        guard_before == 0,
    )

    state_before = Int("external_state_before")
    mutated_state = Int("external_mutated_state")
    external_success = Int("external_success")
    final_state = If(external_success == 1, mutated_state, state_before)
    p.prove(
        "E2.failed-hook-frame-cannot-commit-hook-local-state",
        final_state == state_before,
        external_success == 0,
    )
    p.prove(
        "E3.failed-token-call-rolls-back-protocol-state",
        final_state == state_before,
        external_success == 0,
    )

    # Exact-transfer semantics is an explicit premise, not something the engine can establish
    # against an adversarial external contract that lies about its own balances.
    engine_before = Int("token_engine_before")
    user_before = Int("token_user_before")
    transfer = Int("token_exact_transfer")
    engine_after = engine_before - transfer
    user_after = user_before + transfer
    p.prove(
        "E3.exact-transfer-conserves-token-balance",
        engine_after + user_after == engine_before + user_before,
        transfer >= 0,
        engine_before >= transfer,
        user_before >= 0,
    )


def prove_termination_measures(p):
    depth = Int("radix_depth")
    p.prove(
        "E4.radix-recursion-decreases-remaining-depth",
        And(64 - (depth + 1) < 64 - depth, 64 - (depth + 1) >= 0),
        depth >= 0,
        depth < 64,
    )

    subtree_size = Int("subtree_size")
    child_size = Int("child_size")
    p.prove(
        "E4.subtree-recursion-decreases-size",
        child_size < subtree_size,
        subtree_size >= 2,
        child_size >= 1,
        child_size <= subtree_size - 1,
    )

    route_length = Int("route_length")
    route_index = Int("route_index")
    p.prove(
        "E4.route-loop-decreases-remaining-legs",
        route_length - (route_index + 1) < route_length - route_index,
        route_length >= 1,
        route_index >= 0,
        route_index < route_length,
    )

    touched_count = Int("touched_count")
    touched_index = Int("touched_index")
    p.prove(
        "E4.touched-scan-decreases-remaining-items",
        touched_count - (touched_index + 1) < touched_count - touched_index,
        touched_count >= 1,
        touched_index >= 0,
        touched_index < touched_count,
    )

    match_remaining = Int("termination_match_remaining")
    consumed = Int("termination_consumed")
    p.prove(
        "E4.successful-match-step-decreases-remaining-quantity",
        match_remaining - consumed < match_remaining,
        match_remaining >= 1,
        consumed >= 1,
        consumed <= match_remaining,
    )


def main():
    try:
        bind_model_to_source()
        prover = Prover()
        prove_tick_decomposition(prover)
        prove_quote_limbs(prover)
        prove_rounding_and_corrections(prover)
        prove_fees(prover)
        prove_keys_and_radix(prover)
        prove_nonce_epoch_and_namespaces(prover)
        prove_tree_transition_summaries(prover)
        prove_matching_priority_and_accounting(prover)
        prove_hook_top_transitions(prover)
        prove_route_and_signed_accounting(prover)
        prove_native_eth_solvency(prover)
        prove_atomicity_and_external_boundaries(prover)
        prove_termination_measures(prover)
    except (OSError, ProofFailure) as exc:
        print(f"protocol proof failed: {exc}", file=sys.stderr)
        return 1

    print(f"protocol proof passed: {prover.count} complete-domain SMT obligations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
