#!/usr/bin/env python3
"""Compares footprint and performance of the fork with upstream, using several rounds of each.

Each metric uses the median across rounds, because this is sensitive to whatever else the machine is doing. The tolerance
only applies to getting worse: p99, allocation, startup and memory may each grow by at most 5%. A benchmark regresses only
if it is more than 5% slower and its error bars don't overlap with upstream's.
"""
import json
import statistics
import sys

TOLERANCE = 0.05


def median(rounds, *path):
    values = []
    for data in rounds:
        for key in path:
            data = data[key]
        values.append(data)
    return statistics.median(values)


def row(name, base, fork, limit=True):
    change = (fork - base) / base if base else 0.0
    bad = limit and change > TOLERANCE
    status = "FAIL" if bad else ("PASS" if limit else "info")
    print(f"{status:5} {name:42} {base:12.1f} {fork:12.1f} {change * 100:+7.1f}%")
    return bad


def main(base_paths, fork_paths):
    base = [json.load(open(path)) for path in base_paths]
    fork = [json.load(open(path)) for path in fork_paths]
    failed = False
    print(f"      {'metric':42} {'upstream':>12} {'fork':>12} {'change':>8}")
    failed |= row("example jar (bytes)", median(base, "example_jar_bytes"), median(fork, "example_jar_bytes"))
    failed |= row("startup to first 200 (ms)", median(base, "startup_ms"), median(fork, "startup_ms"))
    failed |= row("RSS after 60 s light load (MB)", median(base, "rss_after_light_load_mb"), median(fork, "rss_after_light_load_mb"))
    for method in ("get", "post"):
        row(f"{method} requests/s", median(base, method, "requests_per_second"), median(fork, method, "requests_per_second"), False)
        row(f"{method} p50 (us)", median(base, method, "p50_us"), median(fork, method, "p50_us"), False)
        row(f"{method} p95 (us)", median(base, method, "p95_us"), median(fork, method, "p95_us"), False)
        failed |= row(f"{method} p99 (us)", median(base, method, "p99_us"), median(fork, method, "p99_us"))
        failed |= row(f"{method} allocation (bytes/request)", median(base, method, "allocated_bytes_per_request"), median(fork, method, "allocated_bytes_per_request"))
        row(f"{method} GC count", median(base, method, "gc_count"), median(fork, method, "gc_count"), False)
        errors = median(fork, method, "errors")
        if errors:
            print(f"FAIL  {method} had {errors} errors")
            failed = True
    base_jmh = next((data["jmh"] for data in base if "jmh" in data), {})
    fork_jmh = next((data["jmh"] for data in fork if "jmh" in data), {})
    for name in sorted(base_jmh):
        old, new = base_jmh[name], fork_jmh.get(name)
        if new is None:
            print(f"FAIL  benchmark {name} is missing")
            failed = True
            continue
        slower = new["score"] > old["score"] * (1 + TOLERANCE)
        separated = new["score"] - new["error"] > old["score"] + old["error"]
        bad = slower and separated
        failed |= bad
        change = (new["score"] - old["score"]) / old["score"] * 100
        print(f"{'FAIL' if bad else 'PASS':5} {'jmh ' + name + ' (' + old['unit'] + ')':42} {old['score']:12.1f} {new['score']:12.1f} {change:+7.1f}%")
    return 1 if failed else 0


if __name__ == "__main__":
    split = sys.argv.index("--")
    sys.exit(main(sys.argv[1:split], sys.argv[split + 1:]))
