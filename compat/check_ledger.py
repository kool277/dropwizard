#!/usr/bin/env python3
"""Checks that FORK_CHANGES.md explains every file that differs from the upstream baseline.

Each ledger entry has a line starting with "- Files:" that lists paths or globs in backticks.
"""
import fnmatch
import pathlib
import re
import subprocess
import sys


def main(root, base):
    ledger = pathlib.Path(root, "FORK_CHANGES.md").read_text(encoding="utf-8")
    patterns = []
    for line in ledger.splitlines():
        if line.startswith("- Files:"):
            patterns.extend(re.findall(r"`([^`]+)`", line))
    changed = subprocess.run(
        ["git", "-C", root, "diff", "--name-only", f"{base}..HEAD"],
        check=True, capture_output=True, text=True).stdout.split("\n")
    changed = [path for path in changed if path]
    unexplained = [path for path in changed if not any(fnmatch.fnmatch(path, pattern) for pattern in patterns)]
    unused = [pattern for pattern in patterns if not any(fnmatch.fnmatch(path, pattern) for path in changed)]
    for path in unexplained:
        print(f"not in the ledger: {path}")
    for pattern in unused:
        print(f"in the ledger but unchanged: {pattern}")
    if unexplained or unused:
        return 1
    print(f"PASS  Ledger explains all {len(changed)} changed files")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
