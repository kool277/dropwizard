#!/usr/bin/env python3
"""Compares footprint and performance of the fork with upstream.

Allocation, GC and memory use the median across perf.sh rounds. Startup uses the alternating samples from startup_ab.sh,
and latency the alternating trials from latency_ab.sh, because single measurements of these vary with whatever else the
machine is doing.

The tolerance only applies to getting worse: startup, memory, allocation and p99 may each grow by at most 5%. A p99
difference beyond that must also be statistically significant (one-sided exact Mann-Whitney test, p < 0.05) to fail;
otherwise it is reported as WARN. A benchmark regresses only if it is more than 5% slower and its error bars don't
overlap with upstream's.
"""
import itertools
import json
import statistics
import sys

TOLERANCE = 0.05
SIGNIFICANCE = 0.05


def median(rounds, *path):
    values = []
    for data in rounds:
        for key in path:
            data = data[key]
        values.append(data)
    return statistics.median(values)


def mann_whitney_greater(base, fork):
    """One-sided exact p-value that fork values tend to be greater than base values."""
    def u_statistic(first, second):
        return sum(1.0 if f > b else 0.5 if f == b else 0.0 for f in second for b in first)
    observed = u_statistic(base, fork)
    combined = base + fork
    at_least, total = 0, 0
    for indices in itertools.combinations(range(len(combined)), len(fork)):
        chosen = set(indices)
        candidate_fork = [combined[i] for i in chosen]
        candidate_base = [combined[i] for i in range(len(combined)) if i not in chosen]
        total += 1
        if u_statistic(candidate_base, candidate_fork) >= observed:
            at_least += 1
    return at_least / total


def row(name, base, fork, limit=True, status=None):
    change = (fork - base) / base if base else 0.0
    if status is None:
        status = ("FAIL" if change > TOLERANCE else "PASS") if limit else "info"
    print(f"{status:5} {name:46} {base:12.1f} {fork:12.1f} {change * 100:+7.1f}%")
    return status == "FAIL"


def main(base_paths, fork_paths, startup=None, latency=None):
    base = [json.load(open(path)) for path in base_paths]
    fork = [json.load(open(path)) for path in fork_paths]
    failed = False
    print(f"      {'metric':46} {'upstream':>12} {'fork':>12} {'change':>8}")
    failed |= row("example jar (bytes)", median(base, "example_jar_bytes"), median(fork, "example_jar_bytes"))
    if startup:
        failed |= row(f"startup to first 200 (ms, {len(startup['upstream'])} alternating each)",
                      statistics.median(startup["upstream"]), statistics.median(startup["fork"]))
    else:
        failed |= row("startup to first 200 (ms)", median(base, "startup_ms"), median(fork, "startup_ms"))
    failed |= row("RSS after 60 s light load (MB)", median(base, "rss_after_light_load_mb"), median(fork, "rss_after_light_load_mb"))
    for method in ("get", "post"):
        if latency:
            trials = latency[method]
            up, fk = trials["upstream"], trials["fork"]
            label = f"({len(up)} alternating trials each)"
            row(f"{method} requests/s {label}", statistics.median(t["requests_per_second"] for t in up),
                statistics.median(t["requests_per_second"] for t in fk), False)
            row(f"{method} p50 (us)", statistics.median(t["p50_us"] for t in up), statistics.median(t["p50_us"] for t in fk), False)
            row(f"{method} p95 (us)", statistics.median(t["p95_us"] for t in up), statistics.median(t["p95_us"] for t in fk), False)
            base_p99 = [t["p99_us"] for t in up]
            fork_p99 = [t["p99_us"] for t in fk]
            change = (statistics.median(fork_p99) - statistics.median(base_p99)) / statistics.median(base_p99)
            p_value = mann_whitney_greater(base_p99, fork_p99)
            if change > TOLERANCE:
                status = "FAIL" if p_value < SIGNIFICANCE else "WARN"
            else:
                status = "PASS"
            failed |= row(f"{method} p99 (us, one-sided p={p_value:.3f})", statistics.median(base_p99),
                          statistics.median(fork_p99), status=status)
            errors = sum(t["errors"] for t in fk)
        else:
            failed |= row(f"{method} p99 (us)", median(base, method, "p99_us"), median(fork, method, "p99_us"))
            errors = median(fork, method, "errors")
        failed |= row(f"{method} allocation (bytes/request)", median(base, method, "allocated_bytes_per_request"),
                      median(fork, method, "allocated_bytes_per_request"))
        row(f"{method} GC count (30 s)", median(base, method, "gc_count"), median(fork, method, "gc_count"), False)
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
        print(f"{'FAIL' if bad else 'PASS':5} {'jmh ' + name + ' (' + old['unit'] + ')':46} {old['score']:12.1f} {new['score']:12.1f} {change:+7.1f}%")
    return 1 if failed else 0


if __name__ == "__main__":
    arguments = sys.argv[1:]
    options = {}
    while arguments and arguments[0] in ("--startup", "--latency"):
        options[arguments[0][2:]] = json.load(open(arguments[1]))
        arguments = arguments[2:]
    split = arguments.index("--")
    sys.exit(main(arguments[:split], arguments[split + 1:], options.get("startup"), options.get("latency")))
