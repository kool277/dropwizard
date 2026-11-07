#!/usr/bin/env bash
# Measures footprint and performance of a tree that capture.sh has built.
# Usage: perf.sh <tree> <output json> [--jmh]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tree="$(require_tree "$1")" || exit 2
json="$2"
jmh="${3:-}"
work="$(mktemp -d)"
trap 'kill -9 $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
jar="$(example_jar "$tree")"
cd "$work" || exit 2
rm -f /tmp/compat-perf.*
java -Xmx512m -jar "$jar" db migrate "$compat_dir/perf.yml" > "$work/migrate.log" 2>&1

# With a dedicated CPU set of at least 6 CPUs (COMPAT_CPUSET), the server gets the first 4 and wrk the rest, so that
# they don't compete. A CPU quota would add throttling pauses that hide small differences.
read -r -a cpus <<< "$(python3 - <<'PY'
cpus = []
for part in open("/sys/fs/cgroup/cpuset.cpus.effective").read().strip().split(","):
    first, _, last = part.partition("-")
    cpus.extend(range(int(first), int(last or first) + 1))
print(" ".join(str(cpu) for cpu in cpus))
PY
)"
server_on=()
client_on=()
if [ "${#cpus[@]}" -ge 6 ]; then
    server_on=(taskset -c "$(IFS=,; echo "${cpus[*]:0:4}")")
    client_on=(taskset -c "$(IFS=,; echo "${cpus[*]:4}")")
fi

# Sets server_pid and startup_ms. Not called in a subshell, so that both stay visible.
start_server() {
    local started
    started="$(date +%s%3N)"
    "${server_on[@]}" java -Xmx512m -Xlog:gc:file="$work/gc.log" -jar "$jar" server "$compat_dir/perf.yml" > "$work/server.log" 2>&1 &
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

startups=()
for _ in 1 2 3; do
    start_server
    startups+=("$startup_ms")
    stop_server
done

# Light load, then resident memory
start_server
"${client_on[@]}" wrk -t1 -c2 -d60s --timeout 10s http://127.0.0.1:8080/hello-world > /dev/null
rss_kb="$(awk '/VmRSS/{print $2}' "/proc/$server_pid/status")"
stop_server

# Heavy load, with JFR recording only the measured window
measure() {
    local name="$1"
    export COMPAT_POST="$2"
    start_server
    "${client_on[@]}" wrk -t2 -c32 -d15s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world > /dev/null
    jcmd "$server_pid" JFR.start name=compat settings=profile > /dev/null
    "${client_on[@]}" wrk -t2 -c32 -d60s -s "$compat_dir/report.lua" --timeout 10s http://127.0.0.1:8080/hello-world > "$work/$name.wrk"
    jcmd "$server_pid" JFR.dump name=compat filename="$work/$name.jfr" > /dev/null
    jcmd "$server_pid" JFR.stop name=compat > /dev/null
    stop_server
    jfr summary "$work/$name.jfr" | awk '$1=="jdk.GarbageCollection"{print $2}' > "$work/$name.gc"
    jfr print --events jdk.ObjectAllocationSample "$work/$name.jfr" | grep 'weight =' > "$work/$name.weights"
}
measure get 0
measure post 1

if [ "$jmh" = "--jmh" ]; then
    jmh_cp="$(module_jar "$tree" dropwizard-benchmarks):$(cat "$tree/dropwizard-benchmarks/target/compat-cp.txt")"
    "${server_on[@]}" java -cp "$jmh_cp" org.openjdk.jmh.Main -f 1 -wi 3 -i 5 -w 5s -r 5s -rf json -rff "$work/jmh.json" > "$work/jmh.log" 2>&1
fi

python3 "$compat_dir/perf_json.py" "$work" "$json" "$jar" "${startups[*]}" "$rss_kb"
