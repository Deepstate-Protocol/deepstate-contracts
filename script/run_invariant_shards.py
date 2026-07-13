#!/usr/bin/env python3
import argparse
import math
import os
import re
import subprocess
import sys
from pathlib import Path


INVARIANT_FILES = (
    Path("test/RadixMatchingEngineInvariant.t.sol"),
    Path("test/DeepstateV1Invariant.t.sol"),
)
INVARIANT_CONTRACT = ".*(RadixMatchingEngineInvariantTest|DeepstateV1MultiPoolInvariantTest).*"


def parse_args():
    parser = argparse.ArgumentParser(description="Run deep invariant tests in deterministic shards.")
    parser.add_argument("--runs", type=int, required=True)
    parser.add_argument("--depth", type=int, required=True)
    parser.add_argument("--shards", type=int, required=True)
    parser.add_argument("--shard", type=int, default=None)
    parser.add_argument("--all", action="store_true", help="Run every shard sequentially.")
    return parser.parse_args()


def invariant_names():
    names = []
    for invariant_file in INVARIANT_FILES:
        text = invariant_file.read_text(encoding="utf-8")
        names.extend(re.findall(r"function\s+(invariant_[A-Za-z0-9_]+)\s*\(", text))
    if not names:
        raise RuntimeError(f"no invariant functions found in {INVARIANT_FILES}")
    if len(names) != len(set(names)):
        raise RuntimeError("invariant function names must be unique across invariant suites")
    return names


def select_shard(names, shard, shards):
    if shards < 1:
        raise ValueError("--shards must be >= 1")
    if shard < 1 or shard > shards:
        raise ValueError("--shard must be between 1 and --shards")

    start = math.floor((shard - 1) * len(names) / shards)
    end = math.floor(shard * len(names) / shards)
    return names[start:end]


def run_shard(names, shard, shards, runs, depth):
    selected = select_shard(names, shard, shards)
    if not selected:
        print(f"invariant shard {shard}/{shards}: empty", flush=True)
        return 0

    pattern = "|".join(selected)
    print(f"invariant shard {shard}/{shards}: {len(selected)} invariant(s)", flush=True)
    for name in selected:
        print(f"  - {name}", flush=True)

    command = [
        "forge",
        "test",
        "--force",
        "--match-contract",
        INVARIANT_CONTRACT,
        "--match-test",
        pattern,
    ]
    env = {
        **dict(os.environ),
        "FOUNDRY_INVARIANT_RUNS": str(runs),
        "FOUNDRY_INVARIANT_DEPTH": str(depth),
    }
    return subprocess.run(command, env=env).returncode


def main():
    args = parse_args()
    if args.all == (args.shard is not None):
        print("choose exactly one of --all or --shard", file=sys.stderr)
        return 2

    names = invariant_names()
    print(f"found {len(names)} invariant(s) in {len(INVARIANT_FILES)} files", flush=True)

    if args.all:
        for shard in range(1, args.shards + 1):
            code = run_shard(names, shard, args.shards, args.runs, args.depth)
            if code != 0:
                return code
        return 0

    return run_shard(names, args.shard, args.shards, args.runs, args.depth)


if __name__ == "__main__":
    raise SystemExit(main())
