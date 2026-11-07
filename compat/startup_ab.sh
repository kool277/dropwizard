#!/usr/bin/env bash
# Starts the upstream and the fork example applications alternately, and records each one's time to the first 200 on
# /healthcheck. Alternating removes most of the effect of the machine's changing load, which a few startups per side
# don't.
# Usage: startup_ab.sh <upstream tree> <fork tree> <output json> [samples per side, default 12]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
base="$(require_tree "$1")" || exit 2
fork="$(require_tree "$2")" || exit 2
output="$(absolute_path "$3")" || exit 2
samples="${4:-12}"
work="$(mktemp -d)"
trap 'kill -9 $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
cd "$work" || exit 2
split_cpus
rm -f /tmp/compat-perf.*
java -Xmx512m -jar "$(example_jar "$base")" db migrate "$compat_dir/perf.yml" > "$work/migrate.log" 2>&1

# Prints the milliseconds from launch to the first 200.
start_once() {
    local jar="$1" started pid ms
    started="$(date +%s%3N)"
    "${server_on[@]}" java -Xmx512m -jar "$jar" server "$compat_dir/perf.yml" > "$work/server.log" 2>&1 &
    pid=$!
    if ! ms="$(wait_for_200 http://127.0.0.1:8081/healthcheck "$started")"; then
        tail -20 "$work/server.log" >&2
        exit 2
    fi
    kill -TERM "$pid"
    wait "$pid" 2>/dev/null
    echo "$ms"
}

upstream=()
forked=()
for i in $(seq 1 "$samples"); do
    if [ $((i % 2)) -eq 1 ]; then
        upstream+=("$(start_once "$(example_jar "$base")")")
        forked+=("$(start_once "$(example_jar "$fork")")")
    else
        forked+=("$(start_once "$(example_jar "$fork")")")
        upstream+=("$(start_once "$(example_jar "$base")")")
    fi
done
python3 - "$output" "${upstream[*]}" "${forked[*]}" <<'PY'
import json
import sys
json.dump({"upstream": [int(x) for x in sys.argv[2].split()], "fork": [int(x) for x in sys.argv[3].split()]},
          open(sys.argv[1], "w"), indent=2)
PY
