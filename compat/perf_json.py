#!/usr/bin/env python3
"""Collects the raw results of perf.sh into one JSON file."""
import json
import os
import sys

def allocated_bytes(path):
    """Bytes allocated during the recording, from the per-thread totals at its start and end."""
    per_thread = {}
    for event in json.load(open(path))["recording"]["events"]:
        values = event["values"]
        thread = values["thread"]
        key = thread.get("javaThreadId") or thread.get("osThreadId") or thread.get("javaName")
        per_thread.setdefault(key, []).append(values["allocated"])
    total = 0
    for samples in per_thread.values():
        # A thread with one sample started during the recording, so everything it allocated counts.
        total += max(samples) - min(samples) if len(samples) > 1 else samples[0]
    return total


def load(work, name):
    line = next(l for l in open(os.path.join(work, f"{name}.wrk")) if l.startswith("COMPAT"))
    requests, duration_us, p50, p95, p99, errors = (int(x) for x in line.split()[1:])
    allocated = allocated_bytes(os.path.join(work, f"{name}.alloc.json"))
    gc_text = open(os.path.join(work, f"{name}.gc")).read().strip()
    return {
        "requests_per_second": requests / (duration_us / 1e6),
        "p50_us": p50,
        "p95_us": p95,
        "p99_us": p99,
        "errors": errors,
        "gc_count": int(gc_text or 0),
        "allocated_bytes_per_request": allocated / max(requests, 1),
    }


def main(work, output, jar):
    result = {
        "example_jar_bytes": os.path.getsize(jar),
        "get": load(work, "get"),
        "post": load(work, "post"),
    }
    with open(output, "w") as out:
        json.dump(result, out, indent=2, sort_keys=True)
        out.write("\n")


if __name__ == "__main__":
    main(*sys.argv[1:])
