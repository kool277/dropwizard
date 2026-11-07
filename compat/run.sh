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
        jmh=""
        [ "$round" = 1 ] && jmh="--jmh"
        "$compat_dir/perf.sh" "$base_tree" "$perf/upstream-$round.json" $jmh || status=1
        "$compat_dir/perf.sh" "$compat_root" "$perf/fork-$round.json" $jmh || status=1
        base_results+=("$perf/upstream-$round.json")
        fork_results+=("$perf/fork-$round.json")
    done
    "$compat_dir/startup_ab.sh" "$base_tree" "$compat_root" "$perf/startup.json" "${COMPAT_STARTUP_SAMPLES:-12}" || status=1
    python3 "$compat_dir/compare_perf.py" --startup "$perf/startup.json" "${base_results[@]}" -- "${fork_results[@]}" \
        | tee "$perf/comparison.txt"
    [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
fi
if [ $status -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $status
