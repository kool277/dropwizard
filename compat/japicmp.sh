#!/usr/bin/env bash
# Checks binary and source compatibility of every published module with the upstream worktree. Both trees must be built.
# The baseline has no published artifacts, so this compares jars with the japicmp command line tool, not its Maven plugin.
# Usage: japicmp.sh <tree> <output directory>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
tree="$(require_tree "$1")" || exit 2
out="$2"
mkdir -p "$out"
version=0.27.0
tool_dir="${MAVEN_USER_HOME:-$HOME/.m2}/japicmp"
tool="$tool_dir/japicmp-$version-jar-with-dependencies.jar"
if [ ! -f "$tool" ]; then
    mkdir -p "$tool_dir"
    url="https://repo.maven.apache.org/maven2/com/github/siom79/japicmp/japicmp/$version/japicmp-$version-jar-with-dependencies.jar"
    curl -fsS -o "$tool.tmp" "$url" || exit 2
    [ "$(sha1sum "$tool.tmp" | cut -d' ' -f1)" = "$(curl -fsS "$url.sha1")" ] || { echo "japicmp checksum mismatch" >&2; exit 2; }
    mv "$tool.tmp" "$tool"
fi
status=0
checked=0
for m in $public_modules; do
    java -jar "$tool" \
        --old "$(module_jar "$base_tree" "$m")" --new "$(module_jar "$tree" "$m")" \
        --old-classpath "$(cat "$base_tree/$m/target/compat-cp.txt")" \
        --new-classpath "$(cat "$tree/$m/target/compat-cp.txt")" \
        --only-modified --error-on-binary-incompatibility --error-on-source-incompatibility \
        > "$out/$m.txt" 2>&1
    rc=$?
    checked=$((checked + 1))
    if [ $rc -ne 0 ]; then
        status=1
        echo "      $m is not compatible, see $out/$m.txt"
        grep -E 'MODIFIED|REMOVED|Exception|rror' "$out/$m.txt" | head -8 | cut -c1-160 | sed 's/^/        /'
    fi
done
if [ $status -eq 0 ]; then
    printf '%-5s %-36s %s\n' PASS "Binary and source compatibility" "$checked modules"
else
    printf '%-5s %-36s %s\n' FAIL "Binary and source compatibility" "$checked modules checked"
fi
exit $status
