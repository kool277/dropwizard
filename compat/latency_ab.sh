#!/usr/bin/env bash
# Measures GET and POST latency of the upstream and the fork example applications in alternating trials, without a
# profiler attached. The order flips on every trial, so that slow drifts in the machine's load affect both equally.
# Usage: latency_ab.sh <upstream tree> <fork tree> <output json> [trials per side, default 8]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
base="$(require_tree "$1")" || exit 2
fork="$(require_tree "$2")" || exit 2
output="$(absolute_path "$3")" || exit 2
trials="${4:-8}"
work="$(mktemp -d)"
trap 'kill -9 $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
cd "$work" || exit 2
split_cpus
jvm_cpus=()
[ "${#server_on[@]}" -gt 0 ] && jvm_cpus=(-XX:ActiveProcessorCount=4)
rm -f /tmp/compat-perf.*
java -Xmx512m -jar "$(example_jar "$base")" db migrate "$compat_dir/perf.yml" > "$work/migrate.log" 2>&1

# Prints the COMPAT line from report.lua for one trial: start, 15 s warm-up, 30 s measured, stop.
trial() {
    local jar="$1" started pid
    started="$(date +%s%3N)"
    "${server_on[@]}" java -Xmx512m "${jvm_cpus[@]}" -jar "$jar" server "$compat_dir/perf.yml" > "$work/server.log" 2>&1 &
    pid=$!
    if ! wait_for_200 http://127.0.0.1:8081/healthcheck "$started" > /dev/null; then
        tail -20 "$work/server.log" >&2
        exit 2
    fi
    "${client_on[@]}" wrk -t2 -c32 -d15s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world > /dev/null
    "${client_on[@]}" wrk -t2 -c32 -d30s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world | grep '^COMPAT'
    kill -TERM "$pid"
    wait "$pid" 2>/dev/null
}

: > "$work/results.txt"
for method in get post; do
    if [ "$method" = post ]; then export COMPAT_POST=1; else export COMPAT_POST=0; fi
    for i in $(seq 1 "$trials"); do
        if [ $((i % 2)) -eq 1 ]; then order="upstream fork"; else order="fork upstream"; fi
        for side in $order; do
            if [ "$side" = upstream ]; then tree="$base"; else tree="$fork"; fi
            echo "$method $side $(trial "$(example_jar "$tree")")" >> "$work/results.txt"
        done
    done
done
python3 - "$work/results.txt" "$output" <<'PY'
import json
import sys
results = {}
for line in open(sys.argv[1]):
    method, side, _, requests, duration_us, p50, p95, p99, errors = line.split()
    results.setdefault(method, {}).setdefault(side, []).append({
        "requests_per_second": int(requests) / (int(duration_us) / 1e6),
        "p50_us": int(p50), "p95_us": int(p95), "p99_us": int(p99), "errors": int(errors)})
json.dump(results, open(sys.argv[2], "w"), indent=2)
PY
