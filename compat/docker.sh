#!/usr/bin/env bash
# Runs a command in the harness container, with the checkout and the upstream worktree at their host paths.
#
#   COMPAT_BASE_TREE  upstream worktree (default: ../dw-upstream)
#   COMPAT_M2         directory for the Maven repository and wrapper (default: ~/.m2)
#   COMPAT_CPUS       CPU limit for the container (default: 6)
#   COMPAT_CPUSET     dedicated CPUs instead of a limit, such as 8-13; use this for --full, see compat/README.md
#   COMPAT_EXTRA_TREES other trees to mount at their host paths, separated by spaces
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
base="${COMPAT_BASE_TREE:-$root/../dw-upstream}"
base="$(cd "$base" && pwd)"
m2="${COMPAT_M2:-$HOME/.m2}"
mkdir -p "$m2"
m2="$(cd "$m2" && pwd)"
common="$(cd "$(git -C "$root" rev-parse --git-common-dir)" && pwd)"
extra=()
for tree in ${COMPAT_EXTRA_TREES:-}; do
    tree="$(cd "$tree" && pwd)"
    extra+=(-v "$tree:$tree")
done
docker build -q -t dw-compat - < "$root/compat/Dockerfile" >/dev/null
if [ -n "${COMPAT_CPUSET:-}" ]; then
    cpu_option="--cpuset-cpus=$COMPAT_CPUSET"
else
    cpu_option="--cpus=${COMPAT_CPUS:-6}"
fi
exec docker run --rm "$cpu_option" -u "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e COMPAT_BASE_TREE="$base" \
    -e COMPAT_PERF_ROUNDS -e COMPAT_STARTUP_SAMPLES -e COMPAT_LATENCY_TRIALS -e COMPAT_FOOTPRINT_SAMPLES \
    -e JAVA_OPTS='-XX:+TieredCompilation -XX:TieredStopAtLevel=1' \
    -e MAVEN_USER_HOME="$m2/wrapper" \
    -e MAVEN_ARGS="-Dmaven.repo.local=$m2/repo" \
    -v "$root:$root" -v "$base:$base" -v "$m2:$m2" -v "$common:$common" "${extra[@]}" \
    -w "$root" dw-compat "$@"
