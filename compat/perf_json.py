#!/usr/bin/env python3
"""Collects the raw results of perf.sh into one JSON file."""
import json
import os
import re
import statistics
import sys

UNITS = {"bytes": 1, "byte": 1, "kB": 1024, "MB": 1024 ** 2, "GB": 1024 ** 3}


def load(work, name):
    line = next(l for l in open(os.path.join(work, f"{name}.wrk")) if l.startswith("COMPAT"))
    requests, duration_us, p50, p95, p99, errors = (int(x) for x in line.split()[1:])
    allocated = 0.0
    for weight in open(os.path.join(work, f"{name}.weights")):
        match = re.search(r"weight = ([\d.]+) (\w+)", weight)
        allocated += float(match.group(1)) * UNITS[match.group(2)]
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


def main(work, output, jar, startups, rss_kb):
    result = {
        "example_jar_bytes": os.path.getsize(jar),
        "startup_ms": statistics.median(int(x) for x in startups.split()),
        "startup_samples_ms": [int(x) for x in startups.split()],
        "rss_after_light_load_mb": int(rss_kb) / 1024,
        "get": load(work, "get"),
        "post": load(work, "post"),
    }
    jmh_path = os.path.join(work, "jmh.json")
    if os.path.exists(jmh_path):
        result["jmh"] = {
            item["benchmark"].rsplit(".", 2)[-2] + "." + item["benchmark"].rsplit(".", 1)[-1]: {
                "score": item["primaryMetric"]["score"],
                "error": item["primaryMetric"]["scoreError"],
                "unit": item["primaryMetric"]["scoreUnit"],
            }
            for item in json.load(open(jmh_path))
        }
    with open(output, "w") as out:
        json.dump(result, out, indent=2, sort_keys=True)
        out.write("\n")


if __name__ == "__main__":
    main(*sys.argv[1:])
