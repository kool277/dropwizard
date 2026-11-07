# Fork changes

This fork is upstream Dropwizard at the commit below, plus the changes listed here. Every file that differs from upstream must be covered by an entry; `compat/check_ledger.py` enforces this.

- **Upstream base:** `a8a09d85e6` on `release/5.0.x` (148 commits after `v5.0.2`). This commit has no upstream tag, which is a deliberate exception to basing the fork on a tag: `v5.0.3` doesn't exist yet, and the later commits include fixes and library updates that the fork should keep. Move to `v5.0.3` once upstream publishes it.
- **Version scheme:** `5.0.2-a8a09d85-fix.N`

## Fork-only

### F1: Compatibility harness and fork documents

- Why: proves that the fork behaves like upstream, apart from the entries below.
- Status: fork-only
- Files: `compat/*`, `FORK_CHANGES.md`

## Fixes

Each fix has a test that fails on the upstream base and passes here, shown by `compat/prove.sh`.
