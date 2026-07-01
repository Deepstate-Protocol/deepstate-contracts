#!/usr/bin/env python3
import argparse
import re
import sys


METRICS = ("lines", "statements", "branches", "funcs")


def parse_args():
    parser = argparse.ArgumentParser(description="Enforce forge coverage summary thresholds.")
    parser.add_argument("report", help="Path to captured forge coverage summary output.")
    parser.add_argument("--file", required=True, help="Source file row to check.")
    parser.add_argument("--min-lines", type=float, required=True)
    parser.add_argument("--min-statements", type=float, required=True)
    parser.add_argument("--min-branches", type=float, required=True)
    parser.add_argument("--min-funcs", type=float, required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    thresholds = {
        "lines": args.min_lines,
        "statements": args.min_statements,
        "branches": args.min_branches,
        "funcs": args.min_funcs,
    }

    try:
        text = open(args.report, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"coverage check failed: could not read {args.report}: {exc}", file=sys.stderr)
        return 1

    row = next((line for line in text.splitlines() if args.file in line), None)
    if row is None:
        print(f"coverage check failed: no summary row found for {args.file}", file=sys.stderr)
        return 1

    matches = re.findall(r"([0-9]+(?:\.[0-9]+)?)%\s+\((\d+)/(\d+)\)", row)
    if len(matches) != len(METRICS):
        print(f"coverage check failed: could not parse summary row: {row}", file=sys.stderr)
        return 1

    failures = []
    for metric, (pct_text, covered_text, total_text) in zip(METRICS, matches):
        pct = float(pct_text)
        covered = int(covered_text)
        total = int(total_text)
        threshold = thresholds[metric]
        if total == 0:
            failures.append(f"{metric}: total is zero")
            continue
        if pct < threshold:
            failures.append(f"{metric}: {pct_text}% ({covered}/{total}) < {threshold:g}%")
        if threshold >= 100 and covered != total:
            failures.append(f"{metric}: {covered}/{total} is not complete")

    if failures:
        print(f"coverage check failed for {args.file}:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    summary = ", ".join(
        f"{metric} {pct}% ({covered}/{total})"
        for metric, (pct, covered, total) in zip(METRICS, matches)
    )
    print(f"coverage check passed for {args.file}: {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
