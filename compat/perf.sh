#!/usr/bin/env bash
# Measures allocation and garbage collection under load, with JFR, for a tree that capture.sh has built. Startup, memory,
# latency and the benchmarks are compared by the *_ab.sh scripts, which alternate between the two trees.
# Usage: perf.sh <tree> <output json>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tree="$(require_tree "$1")" || exit 2
json="$(absolute_path "$2")" || exit 2
work="$(mktemp -d)"
trap 'kill -9 $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
jar="$(example_jar "$tree")"
cd "$work" || exit 2
rm -f /tmp/compat-perf.*
java -Xmx512m -jar "$jar" db migrate "$compat_dir/perf.yml" > "$work/migrate.log" 2>&1

# A CPU quota would add throttling pauses that hide small differences, so use dedicated CPUs where available.
split_cpus
jvm_cpus=()
[ "${#server_on[@]}" -gt 0 ] && jvm_cpus=(-XX:ActiveProcessorCount=4)

# Sets server_pid and startup_ms. Not called in a subshell, so that both stay visible.
start_server() {
    local started
    started="$(date +%s%3N)"
    "${server_on[@]}" java -Xmx512m "${jvm_cpus[@]}" -Xlog:gc:file="$work/gc.log" -jar "$jar" server "$compat_dir/perf.yml" > "$work/server.log" 2>&1 &
    server_pid=$!
    if ! startup_ms="$(wait_for_200 http://127.0.0.1:8081/healthcheck "$started")"; then
        echo "Server did not start, see the log below" >&2
        tail -20 "$work/server.log" >&2
        exit 2
    fi
}

stop_server() {
    kill -TERM "$server_pid"
    wait "$server_pid" 2>/dev/null
}

# Heavy load with JFR recording, for allocation and garbage collection. Latency is compared by latency_ab.sh, without a
# profiler attached.
measure() {
    local name="$1"
    export COMPAT_POST="$2"
    start_server
    "${client_on[@]}" wrk -t2 -c32 -d15s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world > /dev/null
    jcmd "$server_pid" JFR.start name=compat settings=profile > /dev/null
    "${client_on[@]}" wrk -t2 -c32 -d30s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world > "$work/$name.wrk"
    jcmd "$server_pid" JFR.dump name=compat filename="$work/$name.jfr" > /dev/null
    jcmd "$server_pid" JFR.stop name=compat > /dev/null
    stop_server
    jfr summary "$work/$name.jfr" | awk '$1=="jdk.GarbageCollection"{print $2}' > "$work/$name.gc"
    # Exact per-thread allocation counters, rather than the sampled allocation events.
    jfr print --json --events jdk.ThreadAllocationStatistics "$work/$name.jfr" > "$work/$name.alloc.json"
}
measure get 0
measure post 1

python3 "$compat_dir/perf_json.py" "$work" "$json" "$jar"
