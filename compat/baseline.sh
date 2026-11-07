#!/usr/bin/env bash
# Records upstream's behaviour as the golden files in compat/baseline. Run this only when UPSTREAM_BASE changes.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
check_base_tree
"$compat_dir/capture.sh" "$base_tree" "$compat_dir/baseline"
echo "Recorded baseline from $(git -C "$base_tree" rev-parse --short HEAD) in compat/baseline"
