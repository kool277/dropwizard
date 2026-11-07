# Compatibility harness

This fork must stay a drop-in replacement for upstream Dropwizard, apart from the fixes listed in `FORK_CHANGES.md`. The harness compares the fork with the upstream commit in `UPSTREAM_BASE` and fails on any difference that isn't declared.

## Setup

The scripts need a worktree of the upstream commit, and Docker. They run in a container that has the JDK and tools, so nothing else needs to be installed.

```bash
git fetch upstream --tags
git worktree add ../dw-upstream "$(cat compat/UPSTREAM_BASE)"
```

Environment variables: `COMPAT_BASE_TREE` (upstream worktree, default `../dw-upstream`), `COMPAT_M2` (Maven repository directory, default `~/.m2`), `COMPAT_CPUS` (CPU limit, default 6), `COMPAT_CPUSET` (dedicated CPUs instead of a limit), `COMPAT_PERF_ROUNDS` (rounds per side for `--full`, default 2), `COMPAT_STARTUP_SAMPLES` (alternating startups per side for `--full`, default 12).

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
| Footprint (`--full`) | Example jar size, startup to first 200, RSS after 60 s of light load | At most 5% worse |
| Performance (`--full`) | wrk for 60 s on JSON GET and POST, with JFR, plus the JMH benchmarks | p99 and allocation at most 5% worse |

There is no archetype module on this release line, so that check doesn't apply.

`--full` measures upstream and the fork alternately, because results recorded earlier aren't comparable if the machine's load has changed. Golden files for those numbers therefore aren't stored.

## Declaring a difference

If a fix has to change something the harness compares, add its path to `declared-differences.txt` with the ledger entry that explains it. The harness also fails on a declaration that no longer matches anything.
