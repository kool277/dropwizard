#!/usr/bin/env bash
# The gate that every commit must pass. Run on the host, from the root of the tree being checked.
#
#   Commit touches code: ./mvnw clean verify, run.sh, prove.sh for the commit's Proved-by trailers
#   Every commit:        ledger check, and sphinx-build -W when docs changed
#
# Usage: gate.sh [--full]    --full passes --full to run.sh, which adds footprint and performance.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
base="$(cat compat/UPSTREAM_BASE)"
full="${1:-}"
parent="HEAD~1"
changed="$(git diff --name-only "$parent" HEAD)"
fail() { echo "GATE FAILED: $1 at $(git rev-parse --short HEAD)"; exit 1; }

if echo "$changed" | grep -qvE '^(docs/|[A-Z_0-9a-z.-]+\.md$)'; then
    compat/docker.sh ./mvnw -B -ntp clean verify > compat/work-verify.log 2>&1 || {
        grep -E 'ERROR.*(Tests run|Failed to execute|\.java)|FAILURE \[' compat/work-verify.log | cut -c1-200 | head -20
        fail "clean verify"
    }
    echo "PASS  clean verify ($(grep -E 'Total time' compat/work-verify.log | sed 's/.*Total time: *//'))"
    compat/docker.sh compat/run.sh $full || fail "compat/run.sh"
    git log -1 --format='%(trailers:key=Proved-by,valueonly)' | while read -r module spec; do
        [ -n "$module" ] || continue
        compat/docker.sh compat/prove.sh "$module" "$spec" || exit 1
    done || fail "compat/prove.sh"
fi

compat/docker.sh python3 compat/check_ledger.py "$root" "$base" || fail "ledger"

if echo "$changed" | grep -q '^docs/'; then
    out="$(mktemp -d)"
    docker run --rm --cpus=2 -u "$(id -u):$(id -g)" -e HOME=/tmp -e PYTHONUSERBASE=/tmp/pu \
        -v "$root:/w:ro" -v "$out:/out" -w /w/docs python:3.11-slim sh -c \
        'pip install -q --no-warn-script-location --user -r requirements.txt > /dev/null 2>&1; /tmp/pu/bin/sphinx-build -W --keep-going -q -b html -d /out/doctrees source /out/html' \
        || { rm -rf "$out"; fail "sphinx-build -W"; }
    rm -rf "$out"
    echo "PASS  sphinx-build -W"
fi
echo "GATE PASSED at $(git rev-parse --short HEAD)"
