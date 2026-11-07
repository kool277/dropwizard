#!/usr/bin/env bash
# Runs the JMH benchmarks of both trees with several forks each, in two interleaved halves, so that the comparison sees
# the variation between JVM forks, which one fork's error bars don't show.
# Usage: jmh_ab.sh <upstream tree> <fork tree> <output json> [forks per half, default 2]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
base="$(require_tree "$1")" || exit 2
fork="$(require_tree "$2")" || exit 2
output="$(absolute_path "$3")" || exit 2
forks="${4:-2}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
split_cpus
run() {
    local tree="$1" name="$2"
    "${server_on[@]}" java -cp "$(module_jar "$tree" dropwizard-benchmarks):$(cat "$tree/dropwizard-benchmarks/target/compat-cp.txt")" \
        org.openjdk.jmh.Main -f "$forks" -wi 3 -i 3 -w 3s -r 3s -rf json -rff "$work/$name.json" > "$work/$name.log" 2>&1 \
        || { tail -20 "$work/$name.log" >&2; exit 2; }
}
run "$base" upstream-1
run "$fork" fork-1
run "$fork" fork-2
run "$base" upstream-2
python3 - "$work" "$output" <<'PY'
import json
import os
import statistics
import sys
result = {}
for side in ("upstream", "fork"):
    for half in (1, 2):
        for item in json.load(open(os.path.join(sys.argv[1], f"{side}-{half}.json"))):
            name = ".".join(item["benchmark"].rsplit(".", 2)[-2:])
            entry = result.setdefault(name, {"unit": item["primaryMetric"]["scoreUnit"], "upstream": [], "fork": []})
            entry[side].extend(statistics.mean(fork) for fork in item["primaryMetric"]["rawData"])
json.dump(result, open(sys.argv[2], "w"), indent=2)
PY
