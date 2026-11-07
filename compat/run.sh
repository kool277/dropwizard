#!/usr/bin/env bash
# Runs the harness on this tree and compares it with upstream. Prints a PASS/FAIL table; only differences declared in
# compat/declared-differences.txt may differ.
#
# Usage: run.sh [--full]
#   --full also compares footprint and performance, measuring upstream and the fork alternately on this machine.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
check_base_tree
current="$compat_dir/work/current"
"$compat_dir/capture.sh" "$compat_root" "$current" || exit 2
status=0
python3 "$compat_dir/compare.py" "$compat_dir/baseline" "$current" "$compat_dir/declared-differences.txt" || status=1
"$compat_dir/japicmp.sh" "$compat_root" "$current/japicmp" || status=1
printf '%-5s %-36s %s\n' n/a "Archetype project" "no archetype module exists in this release line"
printf '%-5s %-36s %s\n' n/a "Canary application" "CANARY_APP is not set"
if [ "${1:-}" = "--full" ]; then
    rounds="${COMPAT_PERF_ROUNDS:-2}"
    perf="$compat_dir/work/perf"
    rm -rf "$perf"
    mkdir -p "$perf"
    base_results=()
    fork_results=()
    for round in $(seq 1 "$rounds"); do
        # Alternate which side goes first, so that a drift in the machine's load doesn't favour one side.
        if [ $((round % 2)) -eq 1 ]; then sides="upstream fork"; else sides="fork upstream"; fi
        for side in $sides; do
            if [ "$side" = upstream ]; then tree="$base_tree"; else tree="$compat_root"; fi
            "$compat_dir/perf.sh" "$tree" "$perf/$side-$round.json" || status=1
        done
        base_results+=("$perf/upstream-$round.json")
        fork_results+=("$perf/fork-$round.json")
    done
    "$compat_dir/startup_ab.sh" "$base_tree" "$compat_root" "$perf/startup.json" "${COMPAT_STARTUP_SAMPLES:-12}" || status=1
    "$compat_dir/latency_ab.sh" "$base_tree" "$compat_root" "$perf/latency.json" "${COMPAT_LATENCY_TRIALS:-8}" || status=1
    "$compat_dir/footprint_ab.sh" "$base_tree" "$compat_root" "$perf/footprint.json" "${COMPAT_FOOTPRINT_SAMPLES:-6}" || status=1
    "$compat_dir/jmh_ab.sh" "$base_tree" "$compat_root" "$perf/jmh.json" || status=1
    python3 "$compat_dir/compare_perf.py" --startup "$perf/startup.json" --latency "$perf/latency.json" \
        --footprint "$perf/footprint.json" --jmh "$perf/jmh.json" \
        "${base_results[@]}" -- "${fork_results[@]}" | tee "$perf/comparison.txt"
    [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
fi
if [ $status -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $status
