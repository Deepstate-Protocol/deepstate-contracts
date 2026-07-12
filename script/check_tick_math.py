#!/usr/bin/env python3
"""Independently validate TickMath32 constants against high-precision Decimal math."""

import argparse
import random
import re
import sys
from decimal import Decimal, ROUND_FLOOR, getcontext
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "src/libraries/TickMath32.sol"
Q128 = 1 << 128
FRACTION_MODULUS = 1 << 26
HALF_FRACTION = 1 << 25
MIN_TICK = -(1 << 31)
MAX_TICK = (1 << 31) - 1
MAX_ULP_ERROR = 64
RANDOM_SAMPLES = 4096
VECTOR_PATTERN = re.compile(r"_assertReference\((-?\d+),\s*(0x[0-9a-f]+|\d+),\s*(\d+)\);")

getcontext().prec = 180
LN2 = Decimal(2).ln()
DECIMAL_Q128 = Decimal(Q128)
DECIMAL_TICK_DENOMINATOR = Decimal(1 << 31)


def function_body(source, name):
    start = source.index(f"function {name}")
    end = source.find("\n    function ", start + 1)
    return source[start:] if end == -1 else source[start:end]


def switch_table(source, name):
    body = function_body(source, name)
    result = {
        int(key): int(value, 16)
        for key, value in re.findall(r"case (\d+) \{ factor := (0x[0-9a-f]+)", body)
    }
    default = re.search(r"default \{ factor := (0x[0-9a-f]+)", body)
    if default is not None:
        result["default"] = int(default.group(1), 16)
    return result


class ProductionFactors:
    def __init__(self, source):
        self.tables = [switch_table(source, f"_factor{i}") for i in range(6)]
        self.residuals = switch_table(source, "_residualFactor")
        self._validate_shape()

    def _validate_shape(self):
        if set(self.tables[0]) != set(range(15)) | {"default"}:
            raise ValueError("_factor0 must encode nibbles 0..15")
        for index, table in enumerate(self.tables[1:], 1):
            if set(table) != set(range(1, 15)) | {"default"}:
                raise ValueError(f"_factor{index} must encode nibbles 1..15")
        if set(self.residuals) != {1, 2, "default"}:
            raise ValueError("_residualFactor must encode residuals 1..3")

    @staticmethod
    def _lookup(table, value):
        return table.get(value, table["default"])

    def fraction_factor(self, fraction):
        residual = fraction & 0x03
        fraction >>= 2

        factor = self._lookup(self.tables[0], fraction & 0x0F)
        for table_index, bit_shift in enumerate((4, 8, 12, 16), 1):
            nibble = (fraction >> bit_shift) & 0x0F
            if nibble:
                factor = (factor * self._lookup(self.tables[table_index], nibble)) >> 128
        nibble = fraction >> 20
        if nibble:
            factor = (factor * self._lookup(self.tables[5], nibble)) >> 128
        if residual:
            factor = (factor * self._lookup(self.residuals, residual)) >> 128
        return factor

    def price_factor(self, tick):
        scaled_tick = tick * 3
        integer_exponent = scaled_tick >> 26
        fraction = scaled_tick - (integer_exponent << 26)

        if fraction <= HALF_FRACTION:
            inverse_factor = self.fraction_factor(fraction)
            factor = ((1 << 256) - 1) // inverse_factor + 1
        else:
            integer_exponent += 1
            factor = self.fraction_factor(FRACTION_MODULUS - fraction)
        return factor, 128 - integer_exponent

    def verify_constants(self):
        tables = [("_residualFactor", self.residuals, 26, range(1, 4))]
        tables.extend(
            (f"_factor{index}", table, 24 - 4 * index, range(16) if index == 0 else range(1, 16))
            for index, table in enumerate(self.tables)
        )

        for name, table, denominator_bits, values in tables:
            for value in values:
                encoded = self._lookup(table, value)
                exact = DECIMAL_Q128 * (-(LN2 * Decimal(value) / Decimal(1 << denominator_bits))).exp()
                reference = int(exact.to_integral_value(rounding=ROUND_FLOOR))
                error = reference - encoded
                if not 0 <= error <= 4:
                    raise ValueError(f"{name}[{value}] is {error} Q128 ulps below its independent floor")


def reference_factor(tick):
    scaled_tick = tick * 3
    integer_exponent = scaled_tick >> 26
    fraction = scaled_tick - (integer_exponent << 26)
    if fraction > HALF_FRACTION:
        integer_exponent += 1

    fractional_exponent = Decimal(96) * Decimal(tick) / DECIMAL_TICK_DENOMINATOR
    fractional_exponent -= Decimal(integer_exponent)
    exact = DECIMAL_Q128 * (LN2 * fractional_exponent).exp()
    return int(exact.to_integral_value(rounding=ROUND_FLOOR)), 128 - integer_exponent


def in_domain(tick):
    return MIN_TICK <= tick <= MAX_TICK


def sample_ticks():
    ticks = {MIN_TICK, MIN_TICK + 1, -1, 0, 1, MAX_TICK - 1, MAX_TICK}

    for exponent in range(-96, 97):
        for numerator in (exponent * FRACTION_MODULUS, exponent * FRACTION_MODULUS + HALF_FRACTION):
            center = numerator // 3
            ticks.update(tick for tick in range(center - 2, center + 3) if in_domain(tick))

    inverse_three = pow(3, -1, FRACTION_MODULUS)
    fractions = {0, 1, 2, 3, HALF_FRACTION - 1, HALF_FRACTION, HALF_FRACTION + 1}
    for bit in range(26):
        for nibble in (1, 7, 15):
            fraction = nibble << bit
            if fraction < FRACTION_MODULUS:
                fractions.add(fraction)
    for fraction in fractions:
        tick = (fraction * inverse_three) % FRACTION_MODULUS
        ticks.add(tick)
        ticks.add(tick - FRACTION_MODULUS)

    rng = random.Random(0x4E4947495249)
    ticks.update(rng.randint(MIN_TICK, MAX_TICK) for _ in range(RANDOM_SAMPLES))
    return sorted(ticks)


def rational_less(left_factor, left_shift, right_factor, right_shift):
    if left_shift >= right_shift:
        return left_factor < (right_factor << (left_shift - right_shift))
    return (left_factor << (right_shift - left_shift)) < right_factor


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", type=Path, help="Verify generated Solidity vectors in this file")
    return parser.parse_args()


def check_solidity_vectors(path):
    try:
        source = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"could not read {path}: {exc}") from exc

    vectors = VECTOR_PATTERN.findall(source)
    if not vectors:
        raise ValueError(f"{path} contains no _assertReference vectors")

    seen = set()
    for raw_tick, raw_factor, raw_shift in vectors:
        tick = int(raw_tick)
        factor = int(raw_factor, 0)
        shift = int(raw_shift)
        if tick in seen:
            raise ValueError(f"{path} contains duplicate tick vector {tick}")
        seen.add(tick)

        reference, reference_shift = reference_factor(tick)
        if factor != reference or shift != reference_shift:
            raise ValueError(
                f"{path} vector {tick} is stale: ({factor}, {shift}) != ({reference}, {reference_shift})"
            )

    required = {MIN_TICK, MIN_TICK + 1, -1, 0, 1, MAX_TICK - 1, MAX_TICK}
    missing = sorted(required - seen)
    if missing:
        raise ValueError(f"{path} is missing boundary vectors {missing}")
    return len(vectors)


def main():
    args = parse_args()
    try:
        source = SOURCE.read_text(encoding="utf-8")
        production = ProductionFactors(source)
        production.verify_constants()
    except (OSError, ValueError) as exc:
        print(f"tick reference check failed: {exc}", file=sys.stderr)
        return 1

    max_error = 0
    worst_tick = 0
    ticks = sample_ticks()
    for tick in ticks:
        factor, shift = production.price_factor(tick)
        reference, reference_shift = reference_factor(tick)
        error = abs(factor - reference)
        if error > max_error:
            max_error = error
            worst_tick = tick

        if shift != reference_shift:
            print(f"tick reference check failed: tick {tick} shift {shift} != {reference_shift}", file=sys.stderr)
            return 1
        if not (1 << 127) <= factor < (1 << 129):
            print(f"tick reference check failed: tick {tick} factor is not normalized", file=sys.stderr)
            return 1
        if not 32 <= shift <= 224:
            print(f"tick reference check failed: tick {tick} shift {shift} is outside [32, 224]", file=sys.stderr)
            return 1
        if error > MAX_ULP_ERROR:
            print(
                f"tick reference check failed: tick {tick} differs by {error} Q128 ulps",
                file=sys.stderr,
            )
            return 1
        if tick != MAX_TICK:
            next_factor, next_shift = production.price_factor(tick + 1)
            if not rational_less(factor, shift, next_factor, next_shift):
                print(f"tick reference check failed: tick {tick} is not below tick {tick + 1}", file=sys.stderr)
                return 1

    vector_count = 0
    if args.check is not None:
        try:
            vector_count = check_solidity_vectors(args.check)
        except ValueError as exc:
            print(f"tick reference check failed: {exc}", file=sys.stderr)
            return 1

    vector_suffix = f", {vector_count} generated Solidity vectors" if vector_count else ""
    print(
        f"tick reference check passed: {len(ticks)} ticks, max error {max_error} Q128 ulps "
        f"at tick {worst_tick}{vector_suffix}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
