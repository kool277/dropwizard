#!/usr/bin/env python3
"""Compares footprint and performance of the fork with upstream.

Every comparison uses measurements that alternate between the two applications, so that changes in the machine's load
affect both. The tolerance only applies to getting worse, by at most 5%:

- Jar size, live heap after a full GC, non-heap memory and allocation per request: the median may not grow by more
  than 5%. These hardly vary between runs.
- Startup: the median of the alternating startups may not grow by more than 5%.
- RSS, p99 latency and the JMH benchmarks: these vary between runs, so a change beyond 5% must also be statistically
  significant (one-sided exact Mann-Whitney test, p < 0.05) to fail. A change beyond 5% that isn't significant is
  reported as WARN.
"""
import itertools
import json
import statistics
import sys

TOLERANCE = 0.05
SIGNIFICANCE = 0.05


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


class Table:
    def __init__(self):
        self.failed = False
        print(f"      {'metric':56} {'upstream':>12} {'fork':>12} {'change':>8}")

    def strict(self, name, base, fork):
        """Fails if the median grows by more than the tolerance."""
        base_value, fork_value = statistics.median(base), statistics.median(fork)
        change = (fork_value - base_value) / base_value if base_value else 0.0
        self._print("FAIL" if change > TOLERANCE else "PASS", name, base_value, fork_value, change)

    def noisy(self, name, base, fork):
        """Fails if the median grows by more than the tolerance and the difference is significant."""
        base_value, fork_value = statistics.median(base), statistics.median(fork)
        change = (fork_value - base_value) / base_value if base_value else 0.0
        p_value = mann_whitney_greater(list(base), list(fork))
        if change <= TOLERANCE:
            status = "PASS"
        else:
            status = "FAIL" if p_value < SIGNIFICANCE else "WARN"
        self._print(status, f"{name}, p={p_value:.3f}", base_value, fork_value, change)

    def info(self, name, base, fork):
        base_value, fork_value = statistics.median(base), statistics.median(fork)
        change = (fork_value - base_value) / base_value if base_value else 0.0
        self._print("info", name, base_value, fork_value, change)

    def _print(self, status, name, base_value, fork_value, change):
        self.failed |= status == "FAIL"
        print(f"{status:5} {name:56} {base_value:12.1f} {fork_value:12.1f} {change * 100:+7.1f}%")


def values(samples, key, scale=1.0):
    return [sample[key] / scale for sample in samples]


def main(base_paths, fork_paths, startup, latency, footprint, jmh):
    base = [json.load(open(path)) for path in base_paths]
    fork = [json.load(open(path)) for path in fork_paths]
    table = Table()
    table.strict("example jar (bytes)", values(base, "example_jar_bytes"), values(fork, "example_jar_bytes"))
    table.strict(f"startup to first 200 (ms, {len(startup['upstream'])} alternating each)",
                 startup["upstream"], startup["fork"])

    up, fk = footprint["upstream"], footprint["fork"]
    table.noisy(f"RSS after 60 s light load (MB, {len(up)} each)", values(up, "rss_kb", 1024), values(fk, "rss_kb", 1024))
    table.strict("live heap after full GC (MB)", values(up, "live_heap_kb", 1024), values(fk, "live_heap_kb", 1024))
    table.strict("non-heap memory committed (MB)", values(up, "non_heap_committed_kb", 1024),
                 values(fk, "non_heap_committed_kb", 1024))
    table.info("heap committed by the GC (MB)", values(up, "heap_committed_kb", 1024), values(fk, "heap_committed_kb", 1024))

    for method in ("get", "post"):
        up, fk = latency[method]["upstream"], latency[method]["fork"]
        table.info(f"{method} requests/s ({len(up)} alternating trials each)",
                   values(up, "requests_per_second"), values(fk, "requests_per_second"))
        table.info(f"{method} p50 (us)", values(up, "p50_us"), values(fk, "p50_us"))
        table.info(f"{method} p95 (us)", values(up, "p95_us"), values(fk, "p95_us"))
        table.noisy(f"{method} p99 (us)", values(up, "p99_us"), values(fk, "p99_us"))
        errors = sum(values(fk, "errors"))
        if errors:
            print(f"FAIL  {method} had {errors:.0f} errors")
            table.failed = True
        table.strict(f"{method} allocation (bytes/request, {len(base)} rounds)",
                     [round_[method]["allocated_bytes_per_request"] for round_ in base],
                     [round_[method]["allocated_bytes_per_request"] for round_ in fork])
        table.info(f"{method} GC count (30 s)", [round_[method]["gc_count"] for round_ in base],
                   [round_[method]["gc_count"] for round_ in fork])

    for name in sorted(jmh):
        entry = jmh[name]
        table.noisy(f"jmh {name} ({entry['unit']}, {len(entry['upstream'])} forks each)",
                    entry["upstream"], entry["fork"])
    return 1 if table.failed else 0


if __name__ == "__main__":
    arguments = sys.argv[1:]
    options = {}
    while arguments and arguments[0].startswith("--"):
        options[arguments[0][2:]] = json.load(open(arguments[1]))
        arguments = arguments[2:]
    split = arguments.index("--")
    sys.exit(main(arguments[:split], arguments[split + 1:], options["startup"], options["latency"],
                  options["footprint"], options["jmh"]))
