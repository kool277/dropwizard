#!/usr/bin/env bash
# Measures memory after 60 s of light load, alternating the upstream and the fork example applications. Besides RSS, it
# records the live heap after a full GC and the JVM's non-heap memory from native memory tracking: RSS also depends on
# how much heap the garbage collector chose to commit, which varies from run to run.
# Usage: footprint_ab.sh <upstream tree> <fork tree> <output json> [samples per side, default 6]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
base="$(require_tree "$1")" || exit 2
fork="$(require_tree "$2")" || exit 2
output="$(absolute_path "$3")" || exit 2
samples="${4:-6}"
work="$(mktemp -d)"
trap 'kill -9 $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
cd "$work" || exit 2
split_cpus
jvm_cpus=()
[ "${#server_on[@]}" -gt 0 ] && jvm_cpus=(-XX:ActiveProcessorCount=4)
rm -f /tmp/compat-perf.*
java -Xmx512m -jar "$(example_jar "$base")" db migrate "$compat_dir/perf.yml" > "$work/migrate.log" 2>&1

sample() {
    local side="$1" jar="$2" started pid rss live
    started="$(date +%s%3N)"
    "${server_on[@]}" java -Xmx512m "${jvm_cpus[@]}" -XX:NativeMemoryTracking=summary -jar "$jar" server "$compat_dir/perf.yml" \
        > "$work/server.log" 2>&1 &
    pid=$!
    if ! wait_for_200 http://127.0.0.1:8081/healthcheck "$started" > /dev/null; then
        tail -20 "$work/server.log" >&2
        exit 2
    fi
    "${client_on[@]}" wrk -t1 -c2 -d60s --timeout 10s http://127.0.0.1:8080/hello-world > /dev/null
    rss="$(awk '/VmRSS/{print $2}' "/proc/$pid/status")"
    jcmd "$pid" VM.native_memory summary scale=KB > "$work/nmt.txt"
    jcmd "$pid" GC.run > /dev/null
    sleep 1
    live="$(jcmd "$pid" GC.heap_info | grep -oE 'used [0-9]+K' | head -1 | grep -oE '[0-9]+')"
    kill -TERM "$pid"
    wait "$pid" 2>/dev/null
    python3 - "$work/nmt.txt" "$side" "$rss" "$live" >> "$work/samples.jsonl" <<'PY'
import json
import re
import sys
text = open(sys.argv[1]).read()
total = int(re.search(r"Total: reserved=\d+KB, committed=(\d+)KB", text).group(1))
heap = int(re.search(r"Java Heap \(reserved=\d+KB, committed=(\d+)KB\)", text).group(1))
print(json.dumps({"side": sys.argv[2], "rss_kb": int(sys.argv[3]), "live_heap_kb": int(sys.argv[4]),
                  "heap_committed_kb": heap, "non_heap_committed_kb": total - heap}))
PY
}

: > "$work/samples.jsonl"
for i in $(seq 1 "$samples"); do
    if [ $((i % 2)) -eq 1 ]; then order="upstream fork"; else order="fork upstream"; fi
    for side in $order; do
        if [ "$side" = upstream ]; then sample upstream "$(example_jar "$base")"; else sample fork "$(example_jar "$fork")"; fi
    done
done
python3 - "$work/samples.jsonl" "$output" <<'PY'
import json
import sys
result = {"upstream": [], "fork": []}
for line in open(sys.argv[1]):
    sample = json.loads(line)
    result[sample.pop("side")].append(sample)
json.dump(result, open(sys.argv[2], "w"), indent=2)
PY
