#!/usr/bin/env bash
# Proves a fix: the named test must FAIL on upstream and PASS on this tree. A test that can't even compile on upstream
# proves nothing, so that is reported as inconclusive.
# Usage: prove.sh <module> <TestClass[#method]>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
check_base_tree
module="$1"
spec="$2"
class="${spec%%#*}"
source="$(cd "$compat_root" && find "$module/src/test" -name "$class.java" | head -1)"
if [ -z "$source" ]; then
    echo "No test named $class in $module" >&2
    exit 2
fi
logs="$compat_dir/work/prove"
mkdir -p "$logs"

# Prints PASS, FAIL or INCONCLUSIVE for the test in a tree.
run_test() {
    local tree="$1" log="$2"
    (cd "$tree" && ./mvnw -B -ntp -Pdev -pl "$module" -am "-Dtest=$spec" -Dsurefire.failIfNoSpecifiedTests=false test) > "$log" 2>&1
    local rc=$?
    if [ $rc -eq 0 ] && grep -qE 'Tests run: [1-9][0-9]*, Failures: 0, Errors: 0' "$log"; then
        echo PASS
    elif grep -q 'COMPILATION ERROR' "$log"; then
        echo INCONCLUSIVE
    elif grep -qE 'There are test failures|Tests run: .*(Failures: [1-9]|Errors: [1-9])' "$log"; then
        echo FAIL
    else
        echo INCONCLUSIVE
    fi
}

target="$base_tree/$source"
had_file=no
[ -f "$target" ] && had_file=yes
cp "$compat_root/$source" "$target"
on_upstream="$(run_test "$base_tree" "$logs/$class-upstream.log")"
if [ "$had_file" = yes ]; then git -C "$base_tree" checkout -q -- "$source"; else rm -f "$target"; fi
on_fork="$(run_test "$compat_root" "$logs/$class-fork.log")"

if [ "$on_upstream" = FAIL ] && [ "$on_fork" = PASS ]; then
    printf 'PROVEN      %-58s upstream=FAIL fork=PASS\n' "$module $spec"
else
    printf 'NOT PROVEN  %-58s upstream=%s fork=%s\n' "$module $spec" "$on_upstream" "$on_fork"
    exit 1
fi
