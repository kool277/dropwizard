# Compatibility harness

This fork must stay a drop-in replacement for upstream Dropwizard, apart from the fixes listed in `FORK_CHANGES.md`. The harness compares the fork with the upstream commit in `UPSTREAM_BASE` and fails on any difference that isn't declared.

## Setup

The scripts need a worktree of the upstream commit, and Docker. They run in a container that has the JDK and tools, so nothing else needs to be installed.

```bash
git fetch upstream --tags
git worktree add ../dw-upstream "$(cat compat/UPSTREAM_BASE)"
```

Environment variables: `COMPAT_BASE_TREE` (upstream worktree, default `../dw-upstream`), `COMPAT_M2` (Maven repository directory, default `~/.m2`), `COMPAT_CPUS` (CPU limit, default 6), `COMPAT_CPUSET` (dedicated CPUs instead of a limit), `COMPAT_PERF_ROUNDS` (rounds per side for `--full`, default 2), `COMPAT_STARTUP_SAMPLES` (alternating startups per side for `--full`, default 12), `COMPAT_LATENCY_TRIALS` (alternating latency trials per side and method for `--full`, default 8), `COMPAT_FOOTPRINT_SAMPLES` (alternating memory samples per side for `--full`, default 6).

For `--full`, set `COMPAT_CPUSET` to at least 6 CPUs that are otherwise idle, such as `COMPAT_CPUSET=8-13`. The server then runs on the first 4 and the load generator on the rest. Under a CPU limit instead, the kernel's throttling adds pauses of tens of milliseconds that hide small differences in latency.

## Usage

```bash
compat/docker.sh compat/baseline.sh    # record upstream's behaviour; only when UPSTREAM_BASE changes
compat/docker.sh compat/run.sh         # compare this tree with upstream
compat/docker.sh compat/run.sh --full  # also compare footprint and performance
compat/docker.sh compat/prove.sh dropwizard-auth ClassLevelDenyAllTest   # must fail on upstream, pass here
compat/gate.sh                         # everything required for a commit
```

## What is compared

| Item | How | Rule |
|---|---|---|
| Commands | Help text and exit codes of `server`, `check` and `db` | Identical |
| Smoke run | Admin endpoints and status codes, metric names, health check JSON, log and request-log line shapes, SIGTERM | Identical |
| Configuration | Effective configuration of each YAML file in the repo and each block in `configuration.rst`, and the defaults of every configuration type | Identical |
| Dependencies | Runtime dependency list of each module | Identical |
| API | japicmp on each published module, comparing jars because the baseline commit has no published artifacts | No binary or source incompatibility |
| Footprint (`--full`) | Example jar size. Startup to first 200, alternating 12 times each. Memory after 60 s of light load, alternating 6 times each: RSS, live heap after a full GC, and non-heap memory from native memory tracking | Jar, startup, live heap and non-heap: median at most 5% worse. RSS also depends on how much heap the GC committed, so it fails only if more than 5% worse and significant |
| Performance (`--full`) | Latency: alternating 30 s wrk trials on JSON GET and POST, 8 each, without a profiler. Allocation and GC: JFR during 30 s of load in each round. JMH: 4 forks per side in interleaved halves | Allocation: median at most 5% worse. p99 and JMH vary between runs, so they fail only if more than 5% worse and significant (one-sided exact Mann-Whitney test, p < 0.05); otherwise WARN |

There is no archetype module on this release line, so that check doesn't apply.

`--full` measures upstream and the fork alternately, because results recorded earlier aren't comparable if the machine's load has changed. Golden files for those numbers therefore aren't stored. Single measurements of startup, RSS, p99 and benchmarks varied by 10–20% between runs of the same code here, which is why those use repeated alternating samples and a significance test.

## Declaring a difference

If a fix has to change something the harness compares, add its path to `declared-differences.txt` with the ledger entry that explains it. The harness also fails on a declaration that no longer matches anything.
