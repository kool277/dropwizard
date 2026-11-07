# Shared by the harness scripts.
compat_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compat_root="$(cd "$compat_dir/.." && pwd)"
base_tree="${COMPAT_BASE_TREE:-$compat_root/../dw-upstream}"
base_sha="$(cat "$compat_dir/UPSTREAM_BASE")"

# Published modules, whose public API must stay compatible with upstream.
public_modules="dropwizard-assets dropwizard-auth dropwizard-client dropwizard-configuration dropwizard-core
dropwizard-db dropwizard-forms dropwizard-health dropwizard-hibernate dropwizard-http2 dropwizard-jackson
dropwizard-jdbi3 dropwizard-jersey dropwizard-jetty dropwizard-json-logging dropwizard-lifecycle dropwizard-logging
dropwizard-metrics dropwizard-metrics-graphite dropwizard-migrations dropwizard-request-logging dropwizard-servlets
dropwizard-testing dropwizard-unix-socket dropwizard-util dropwizard-validation dropwizard-views
dropwizard-views-freemarker dropwizard-views-mustache"
all_modules="$public_modules dropwizard-example dropwizard-benchmarks"

check_base_tree() {
    local actual
    actual="$(git -C "$base_tree" rev-parse HEAD)"
    case "$actual" in
        "$base_sha"*) ;;
        *) echo "Upstream worktree $base_tree is at $actual, expected $base_sha" >&2; exit 2 ;;
    esac
}

# Prints the absolute path of a tree, or exits if there is none.
require_tree() {
    if [ ! -d "$1" ]; then
        echo "No tree at $1" >&2
        exit 2
    fi
    (cd "$1" && pwd)
}

# The runnable example jar in a tree (not the original- jar that the shade plugin leaves behind).
example_jar() {
    ls "$1"/dropwizard-example/target/dropwizard-example-*.jar | grep -v -e sources -e javadoc | head -1
}

# The main jar of a module in a tree.
module_jar() {
    ls "$1/$2"/target/"$2"-*.jar | grep -v -e sources -e javadoc -e tests | head -1
}

# Waits until a URL answers 200. Prints the elapsed milliseconds, or fails after 180 seconds.
wait_for_200() {
    local url="$1" started="$2" deadline=$((SECONDS + 180))
    until [ "$(curl -s -o /dev/null -w '%{http_code}' "$url")" = 200 ]; do
        [ "$SECONDS" -lt "$deadline" ] || return 1
        sleep 0.05
    done
    echo $(( $(date +%s%3N) - started ))
}

# Rewrites anything that legitimately varies between runs, keeping the shape of a line.
shape() {
    sed -E 's/[0-9]+/N/g'
}
