#!/usr/bin/env bash
# Records the observable behaviour of a Dropwizard tree: dependencies, configuration, commands and admin interface.
# Usage: capture.sh <tree> <output directory>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tree="$(require_tree "$1")" || exit 2
mkdir -p "$2"
out="$(cd "$2" && pwd)"
rm -rf "$out/smoke" "$out/corpus" "$out/deps" "$out/jars" "$out/logs" "$out/cli"
mkdir -p "$out/smoke" "$out/corpus" "$out/deps" "$out/jars" "$out/logs" "$out/cli"

# --- Build, with the runtime classpath and dependency list of every module. Not with -Pdev, which turns off the
# example application's shading, so its jar wouldn't run.
pl="$(echo $all_modules | tr ' ' ',')"
(cd "$tree" && ./mvnw -B -ntp -q -DskipTests -Dpgpverify.skip=true -Djacoco.skip=true -pl "$pl" -am package \
    dependency:build-classpath dependency:list \
    -Dmdep.outputFile=target/compat-cp.txt -DoutputFile=target/compat-deps.txt -DincludeScope=test -Dsort=true) \
    > "$out/logs/build.log" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
    echo "Build of $tree failed, see $out/logs/build.log" >&2
    tail -20 "$out/logs/build.log" >&2
    exit 2
fi

# --- Dependencies: the runtime list (compile and runtime scopes) must not change. The classpath files keep every scope,
# because japicmp needs provided dependencies too. Dropwizard's own version is ignored, since releases change it.
for m in $all_modules; do
    python3 - "$tree/$m/target/compat-deps.txt" > "$out/deps/$m.txt" <<'PY'
import re
import sys
lines = []
for line in open(sys.argv[1], encoding="utf-8"):
    coordinates = line.strip().split(" -- ")[0]
    parts = coordinates.split(":")
    if len(parts) < 5 or parts[-1] not in ("compile", "runtime"):
        continue
    if parts[0].startswith("io.dropwizard"):
        parts[-2] = "VERSION"
    lines.append(":".join(parts) + (" -- " + line.strip().split(" -- ", 1)[1] if " -- " in line else ""))
print("\n".join(sorted(lines)))
PY
    cp "$(module_jar "$tree" "$m")" "$out/jars/$m.jar"
done

# --- Configuration corpus
snippets="$tree/target/compat-snippets"
rm -rf "$snippets"
mkdir -p "$snippets"
python3 "$compat_dir/extract_yaml.py" "$tree/docs/source/manual/configuration.rst" "$snippets"
classpath="$(python3 - "$tree" $public_modules <<'PY'
import sys
tree, modules = sys.argv[1], sys.argv[2:]
entries = []
for module in modules:
    for entry in open(f"{tree}/{module}/target/compat-cp.txt").read().strip().split(":"):
        if entry and entry not in entries:
            entries.append(entry)
print(":".join(entries))
PY
)"
for m in $public_modules; do classpath="$(module_jar "$tree" "$m"):$classpath"; done
corpus_files="$(cd "$tree" && git ls-files '*.yml' '*.yaml' | grep -vE '^(\.|compat/|appveyor|jreleaser|renovate)'; cd "$tree" && find target/compat-snippets -name '*.yml' | sort)"
(cd "$tree" && java -cp "$classpath" "$compat_dir/CorpusDump.java" "$out/corpus" $corpus_files) > "$out/logs/corpus.log" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
    echo "Configuration corpus failed, see $out/logs/corpus.log" >&2
    tail -20 "$out/logs/corpus.log" >&2
    exit 2
fi

# --- Commands: names, flags, exit codes and how a bad configuration fails
cd "$tree/dropwizard-example" || exit 2
jar="$(example_jar "$tree")"
rm -f target/example.mv.db target/example.trace.db
for args in "--help" "server --help" "check --help" "db --help"; do
    name="$(echo "$args" | tr -d -- '-' | tr ' ' '_')"
    java -jar "$jar" $args > "$out/cli/$name.txt" 2>&1
    echo "exit=$?" >> "$out/cli/$name.txt"
done
for sub in calculate-checksum clear-checksums drop-all dump fast-forward generate-docs locks migrate prepare-rollback rollback status tag test; do
    java -jar "$jar" db "$sub" --help > "$out/cli/db_$sub.txt" 2>&1
    echo "exit=$?" >> "$out/cli/db_$sub.txt"
done
# The usage line names the jar, which includes the version.
sed -i -E 's/dropwizard-example-[^ ]+\.jar/dropwizard-example-VERSION.jar/' "$out"/cli/*.txt
java -jar "$jar" check example.yml > "$out/logs/check.log" 2>&1
echo "exit=$?" > "$out/smoke/check-valid.txt"
java -jar "$jar" check "$compat_dir/invalid.yml" 2>&1 | shape | sed -E "s#^.*invalid\.yml#invalid.yml#" > "$out/smoke/check-invalid.txt"
echo "exit=${PIPESTATUS[0]}" >> "$out/smoke/check-invalid.txt"
java -jar "$jar" db migrate example.yml > "$out/logs/migrate.log" 2>&1
echo "exit=$?" > "$out/smoke/db-migrate.txt"

# --- Running server
started="$(date +%s%3N)"
java -jar "$jar" server example.yml > "$out/logs/server.log" 2>&1 &
pid=$!
trap 'kill -9 $pid 2>/dev/null' EXIT
if ! startup_ms="$(wait_for_200 http://127.0.0.1:8081/healthcheck "$started")"; then
    echo "Server did not become healthy, see $out/logs/server.log" >&2
    tail -20 "$out/logs/server.log" >&2
    exit 2
fi
echo "$startup_ms" > "$out/logs/startup-ms.txt"

curl -s http://127.0.0.1:8080/hello-world?name=compat > "$out/smoke/get-body.txt"
sed -i -E 's/"id":[0-9]+/"id":N/' "$out/smoke/get-body.txt"
curl -s -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' -d '{"id":1,"content":"compat"}' http://127.0.0.1:8080/hello-world > "$out/smoke/post-status.txt"
curl -s -D - -o /dev/null http://127.0.0.1:8080/hello-world | grep -iE '^(HTTP|content-type|server|vary|x-)' | tr -d '\r' | sort > "$out/smoke/get-headers.txt"

curl -s http://127.0.0.1:8081/healthcheck | jq -S 'keys' > "$out/smoke/healthcheck-keys.json"
curl -s http://127.0.0.1:8081/healthcheck | jq -S 'map_values(keys)' > "$out/smoke/healthcheck-shape.json"
curl -s http://127.0.0.1:8081/metrics | jq -r '.gauges,.counters,.histograms,.meters,.timers | keys[]' | sort > "$out/smoke/metric-names.txt"
curl -s http://127.0.0.1:8081/metrics | jq -S 'keys' > "$out/smoke/metrics-sections.json"
curl -s http://127.0.0.1:8081/ping > "$out/smoke/ping.txt"
for path in / /ping /threads /metrics /healthcheck /pprof /tasks/does-not-exist; do
    printf '%s %s\n' "$path" "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8081$path")"
done > "$out/smoke/admin-status.txt"
for path in /ping /threads /metrics /healthcheck /tasks/gc; do
    printf '%s %s\n' "$path" "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8080$path")"
done > "$out/smoke/application-port-status.txt"
{
    printf 'gc %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8081/tasks/gc)"
    printf 'log-level %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -X POST 'http://127.0.0.1:8081/tasks/log-level?logger=com.example.helloworld&level=INFO')"
} > "$out/smoke/tasks-status.txt"

# Log formats: request logs are written asynchronously, so give them a moment.
sleep 2
grep -E '^(INFO|WARN|DEBUG) +\[' "$out/logs/server.log" | head -200 | sed -E 's/^([A-Z]+ +\[[^]]+\] [^:]+:).*/\1/' | shape | awk '!seen[$0]++' | sort > "$out/smoke/log-line-shapes.txt"
grep -E '"GET /hello-world' "$out/logs/server.log" | head -1 | shape > "$out/smoke/request-log-shape.txt"

# --- Graceful shutdown
stop_started="$(date +%s%3N)"
kill -TERM "$pid"
wait "$pid"
rc=$?
trap - EXIT
echo $(( $(date +%s%3N) - stop_started )) > "$out/logs/shutdown-ms.txt"
echo "exit=$rc" > "$out/smoke/sigterm.txt"
shutdown_ms="$(cat "$out/logs/shutdown-ms.txt")"
if [ "$shutdown_ms" -le 30000 ]; then echo "within-grace-period" >> "$out/smoke/sigterm.txt"; else echo "EXCEEDED-grace-period" >> "$out/smoke/sigterm.txt"; fi
