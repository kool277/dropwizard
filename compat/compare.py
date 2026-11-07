#!/usr/bin/env python3
"""Compares a capture with the baseline and prints a PASS/FAIL table.

A difference is allowed only if compat/declared-differences.txt lists its path (a glob, relative to the capture) next to
the ledger entry that explains it. Exits non-zero on any undeclared difference, and on declarations that match nothing,
so that the list can't go stale.
"""
import fnmatch
import json
import os
import pathlib
import sys

ITEMS = [
    ("Commands and flags", "cli"),
    ("Smoke run: admin, logs, shutdown", "smoke"),
    ("Configuration corpus", "corpus"),
    ("Runtime dependencies", "deps"),
]


def read_declared(path):
    declared = []
    for line in pathlib.Path(path).read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            glob, _, reason = line.partition(" ")
            declared.append((glob, reason.strip()))
    return declared


def files_under(root):
    root = pathlib.Path(root)
    if not root.is_dir():
        return {}
    return {str(p.relative_to(root)): p for p in sorted(root.rglob("*")) if p.is_file()}


def json_differences(old, new, path=""):
    """Yields a description of every key that disappeared, appeared or changed."""
    if isinstance(old, dict) and isinstance(new, dict):
        for key in sorted(old.keys() | new.keys()):
            child = f"{path}.{key}" if path else key
            if key not in new:
                yield f"{child} disappeared (was {json.dumps(old[key])[:60]})"
            elif key not in old:
                yield f"{child} is new ({json.dumps(new[key])[:60]})"
            else:
                yield from json_differences(old[key], new[key], child)
    elif isinstance(old, list) and isinstance(new, list) and len(old) == len(new):
        for index, (old_item, new_item) in enumerate(zip(old, new)):
            yield from json_differences(old_item, new_item, f"{path}[{index}]")
    elif old != new:
        kind = "changed type" if type(old) is not type(new) else "changed"
        yield f"{path} {kind}: {json.dumps(old)[:60]} -> {json.dumps(new)[:60]}"


def describe(relative, old_path, new_path):
    if old_path is None:
        return [f"{relative}: new file"]
    if new_path is None:
        return [f"{relative}: missing"]
    old_bytes, new_bytes = old_path.read_bytes(), new_path.read_bytes()
    if old_bytes == new_bytes:
        return []
    if relative.endswith(".json"):
        try:
            found = list(json_differences(json.loads(old_bytes), json.loads(new_bytes)))
            return [f"{relative}: {item}" for item in found] or [f"{relative}: formatting differs"]
        except ValueError:
            pass
    old_lines = old_bytes.decode("utf-8", "replace").splitlines()
    new_lines = new_bytes.decode("utf-8", "replace").splitlines()
    removed = [line for line in old_lines if line not in new_lines]
    added = [line for line in new_lines if line not in old_lines]
    return [f"{relative}: - {line[:100]}" for line in removed[:5]] + [f"{relative}: + {line[:100]}" for line in added[:5]]


def main(baseline, current, declared_path):
    declared = read_declared(declared_path)
    used = set()
    failed = False
    rows, details = [], []
    for title, subdirectory in ITEMS:
        old_files = files_under(os.path.join(baseline, subdirectory))
        new_files = files_under(os.path.join(current, subdirectory))
        undeclared, allowed = [], 0
        for name in sorted(old_files.keys() | new_files.keys()):
            differences = describe(name, old_files.get(name), new_files.get(name))
            if not differences:
                continue
            relative = f"{subdirectory}/{name}"
            matches = [glob for glob, _ in declared if fnmatch.fnmatch(relative, glob)]
            if matches:
                used.update(matches)
                allowed += 1
            else:
                undeclared.extend(f"{subdirectory}/{item}" for item in differences)
        if undeclared:
            failed = True
            rows.append((title, "FAIL", f"{len(undeclared)} undeclared difference(s) in {len(new_files)} files"))
            details.extend(undeclared)
        elif allowed:
            rows.append((title, "PASS", f"{len(new_files)} files, {allowed} declared difference(s)"))
        elif not old_files:
            failed = True
            rows.append((title, "FAIL", "no baseline"))
        else:
            rows.append((title, "PASS", f"{len(new_files)} files identical"))
    stale = [glob for glob, _ in declared if glob not in used]
    if stale:
        failed = True
        rows.append(("Declared differences", "FAIL", f"{len(stale)} declared but not observed"))
        details.extend(f"declared but not observed: {glob}" for glob in stale)

    for title, status, detail in rows:
        print(f"{status:5} {title:36} {detail}")
    for line in details[:60]:
        print(f"      {line}")
    if len(details) > 60:
        print(f"      ... and {len(details) - 60} more")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
