#!/usr/bin/env python3
import argparse
import json
import re
import sys
from dataclasses import dataclass, field


METRICS = ("lines", "statements", "branches", "funcs")
EXCLUSION_FIELDS = {"reason", "lines", "statements", "functions", "branches"}


@dataclass
class SummaryMetric:
    covered: int
    total: int


@dataclass
class FileCoverage:
    lines: dict[int, int] = field(default_factory=dict)
    functions: dict[str, int] = field(default_factory=dict)
    branches: dict[str, str] = field(default_factory=dict)


def parse_args():
    parser = argparse.ArgumentParser(description="Enforce adjusted forge coverage thresholds.")
    parser.add_argument("report", help="Path to captured forge coverage summary output.")
    parser.add_argument("--file", help="Source file row to check.")
    parser.add_argument("--files", help="Comma or space separated source files to check.")
    parser.add_argument("--lcov", default="lcov.info", help="Path to forge-generated lcov.info.")
    parser.add_argument("--exclude", help="JSON file containing explicit coverage exclusions.")
    parser.add_argument("--min-lines", type=float, required=True)
    parser.add_argument("--min-statements", type=float, required=True)
    parser.add_argument("--min-branches", type=float, required=True)
    parser.add_argument("--min-funcs", type=float, required=True)
    return parser.parse_args()


def target_files(args):
    if args.files:
        files = [part for part in re.split(r"[\s,]+", args.files) if part]
    elif args.file:
        files = [args.file]
    else:
        raise ValueError("one of --file or --files is required")
    return files


def read_text(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        raise ValueError(f"could not read {path}: {exc}") from exc


def parse_summary(report_text):
    rows = {}
    for row in report_text.splitlines():
        if "src/" not in row:
            continue
        matches = re.findall(r"([0-9]+(?:\.[0-9]+)?)%\s+\((\d+)/(\d+)\)", row)
        if len(matches) != len(METRICS):
            continue
        path_match = re.search(r"(src/[^|\s]+\.sol)", row)
        if path_match is None:
            continue
        rows[path_match.group(1)] = {
            metric: SummaryMetric(int(covered), int(total))
            for metric, (_, covered, total) in zip(METRICS, matches)
        }
    return rows


def parse_lcov(lcov_text):
    result = {}
    current_path = None
    current = None

    for raw_line in lcov_text.splitlines():
        if raw_line.startswith("SF:"):
            current_path = raw_line[3:]
            current = FileCoverage()
            result[current_path] = current
        elif raw_line == "end_of_record":
            current_path = None
            current = None
        elif current is None:
            continue
        elif raw_line.startswith("DA:"):
            line_no, count = raw_line[3:].split(",", 1)
            current.lines[int(line_no)] = int(count)
        elif raw_line.startswith("FNDA:"):
            count, name = raw_line[5:].split(",", 1)
            current.functions[name] = int(count)
        elif raw_line.startswith("BRDA:"):
            line_no, block, branch, taken = raw_line[5:].split(",", 3)
            key = f"{line_no}:{block}:{branch}"
            current.branches[key] = taken

    return result


def load_exclusions(path):
    if not path:
        return {}
    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise ValueError(f"could not parse {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def branch_is_covered(taken):
    return taken not in ("-", "0")


def adjusted_lcov_counts(file_name, coverage, exclusions):
    failures = []

    excluded_lines = set(exclusions.get("lines", []))
    for line in excluded_lines:
        if line not in coverage.lines:
            failures.append(f"line exclusion {line} is stale or absent from lcov")
        elif coverage.lines[line] != 0:
            failures.append(f"line exclusion {line} is now covered; remove it")

    excluded_functions = set(exclusions.get("functions", []))
    for function in excluded_functions:
        if function not in coverage.functions:
            failures.append(f"function exclusion {function} is stale or absent from lcov")
        elif coverage.functions[function] != 0:
            failures.append(f"function exclusion {function} is now covered; remove it")

    excluded_branches = set(exclusions.get("branches", []))
    for branch in excluded_branches:
        if branch not in coverage.branches:
            failures.append(f"branch exclusion {branch} is stale or absent from lcov")
        elif branch_is_covered(coverage.branches[branch]):
            failures.append(f"branch exclusion {branch} is now covered; remove it")

    lines = [(line, count) for line, count in coverage.lines.items() if line not in excluded_lines]
    functions = [
        (function, count) for function, count in coverage.functions.items() if function not in excluded_functions
    ]
    branches = [
        (branch, taken) for branch, taken in coverage.branches.items() if branch not in excluded_branches
    ]

    counts = {
        "lines": SummaryMetric(sum(1 for _, count in lines if count != 0), len(lines)),
        "funcs": SummaryMetric(sum(1 for _, count in functions if count != 0), len(functions)),
        "branches": SummaryMetric(sum(1 for _, taken in branches if branch_is_covered(taken)), len(branches)),
    }
    return counts, failures


def adjusted_statement_counts(file_name, summary_metrics, exclusions):
    metric = summary_metrics["statements"]
    statement_exclusions = exclusions.get("statements", 0)
    if not isinstance(statement_exclusions, int) or isinstance(statement_exclusions, bool) or statement_exclusions < 0:
        return None, ["statement exclusions must be a nonnegative integer"]
    missing = metric.total - metric.covered
    if statement_exclusions > missing:
        return None, [f"statement exclusions {statement_exclusions} exceed missing statements {missing}"]
    return SummaryMetric(metric.covered, metric.total - statement_exclusions), []


def pct(metric):
    if metric.total == 0:
        return 100.0 if metric.covered == 0 else 0.0
    return metric.covered * 100.0 / metric.total


def validate_metric(file_name, metric_name, metric, threshold):
    failures = []
    percentage = pct(metric)
    if metric.total == 0:
        failures.append(f"{metric_name}: adjusted total is zero")
    elif percentage < threshold:
        failures.append(
            f"{metric_name}: {percentage:.2f}% ({metric.covered}/{metric.total}) < {threshold:g}%"
        )
    if threshold >= 100 and metric.covered != metric.total:
        failures.append(f"{metric_name}: {metric.covered}/{metric.total} is not complete after exclusions")
    return failures


def main():
    args = parse_args()
    try:
        files = target_files(args)
        summary = parse_summary(read_text(args.report))
        lcov = parse_lcov(read_text(args.lcov))
        exclusions = load_exclusions(args.exclude)
    except ValueError as exc:
        print(f"coverage check failed: {exc}", file=sys.stderr)
        return 1

    thresholds = {
        "lines": args.min_lines,
        "statements": args.min_statements,
        "branches": args.min_branches,
        "funcs": args.min_funcs,
    }

    failures = []
    totals = {metric: SummaryMetric(0, 0) for metric in METRICS}
    summaries = []

    stale_files = sorted(set(exclusions) - set(files))
    failures.extend(f"exclusion entry targets untracked file {file_name}" for file_name in stale_files)

    for file_name in files:
        file_summary = summary.get(file_name)
        file_lcov = lcov.get(file_name)
        file_exclusions = exclusions.get(file_name, {})

        unknown_fields = sorted(set(file_exclusions) - EXCLUSION_FIELDS)
        failures.extend(f"{file_name}: unknown exclusion field {field}" for field in unknown_fields)
        has_exclusions = any(file_exclusions.get(field) for field in ("lines", "statements", "functions", "branches"))
        reason = file_exclusions.get("reason")
        if has_exclusions and (not isinstance(reason, str) or not reason.strip()):
            failures.append(f"{file_name}: exclusions require a nonempty reason")

        if file_summary is None:
            failures.append(f"{file_name}: no forge summary row found")
            continue
        if file_lcov is None:
            failures.append(f"{file_name}: no lcov record found")
            continue

        adjusted, exclusion_failures = adjusted_lcov_counts(file_name, file_lcov, file_exclusions)
        failures.extend(f"{file_name}: {failure}" for failure in exclusion_failures)

        statements, statement_failures = adjusted_statement_counts(file_name, file_summary, file_exclusions)
        failures.extend(f"{file_name}: {failure}" for failure in statement_failures)
        # Keep validating the remaining metrics when the statement exclusion itself is invalid.
        # The recorded failure still makes the command fail, while the raw statement counts avoid
        # turning a malformed manifest into an unrelated KeyError traceback.
        adjusted["statements"] = statements if statements is not None else file_summary["statements"]

        for metric in METRICS:
            metric_counts = adjusted[metric]
            totals[metric].covered += metric_counts.covered
            totals[metric].total += metric_counts.total
            failures.extend(
                f"{file_name}: {failure}"
                for failure in validate_metric(file_name, metric, metric_counts, thresholds[metric])
            )

        summaries.append(
            f"{file_name}: "
            + ", ".join(
                f"{metric} {pct(adjusted[metric]):.2f}% "
                f"({adjusted[metric].covered}/{adjusted[metric].total})"
                for metric in METRICS
            )
        )

    for metric in METRICS:
        failures.extend(
            f"total: {failure}" for failure in validate_metric("total", metric, totals[metric], thresholds[metric])
        )

    if failures:
        print("coverage check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    for line in summaries:
        print(f"coverage check passed for {line}")
    total_summary = ", ".join(
        f"{metric} {pct(totals[metric]):.2f}% ({totals[metric].covered}/{totals[metric].total})"
        for metric in METRICS
    )
    print(f"coverage check passed for total: {total_summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
