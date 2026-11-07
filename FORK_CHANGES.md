# Fork changes

This fork is upstream Dropwizard at the commit below, plus the changes listed here. Every file that differs from upstream must be covered by an entry; `compat/check_ledger.py` enforces this.

- **Upstream base:** `a8a09d85e6` on `release/5.0.x` (148 commits after `v5.0.2`). This commit has no upstream tag, which is a deliberate exception to basing the fork on a tag: `v5.0.3` doesn't exist yet, and the later commits include fixes and library updates that the fork should keep. Move to `v5.0.3` once upstream publishes it.
- **Version scheme:** `5.0.2-a8a09d85-fix.N`

## Fork-only

### F1: Compatibility harness and fork documents

- Why: proves that the fork behaves like upstream, apart from the entries below.
- Status: fork-only
- Files: `compat/*`, `FORK_CHANGES.md`, `RELEASE_NOTES_*.md`

## Fixes

Each fix has a test that fails on the upstream base and passes here, shown by `compat/prove.sh`.

### B1: Class-level `@DenyAll` is ignored

- Upstream issue: None found.
- Module: `dropwizard-auth`
- Root cause: `AuthDynamicFeature` only looks for `@RolesAllowed` and `@PermitAll` on classes, and Jersey's `RolesAllowedDynamicFeature` doesn't read a class-level `@DenyAll` either.
- Visible change: Methods of a class annotated with `@DenyAll` now return 401 or 403 unless they have their own security annotation. A class that relied on the annotation being ignored must remove it.
- Proving test: `dropwizard-auth ClassLevelDenyAllTest`
- Commit: `fix(auth): deny access for class-level @DenyAll`
- Status: fork-only
- Files: `dropwizard-auth/src/main/java/io/dropwizard/auth/AuthDynamicFeature.java`, `dropwizard-auth/src/test/java/io/dropwizard/auth/ClassLevelDenyAllTest.java`, `docs/source/manual/auth.rst`

### B2: Path parameters choose the asset media type

- Upstream issue: [dropwizard/dropwizard#11385](https://github.com/dropwizard/dropwizard/pull/11385), open.
- Module: `dropwizard-servlets`
- Root cause: `AssetServlet` loads the asset from the decoded path, but picks the media type from `getRequestURI()`, which still has `;` path parameters.
- Visible change: `/app.js;x.html` is served with the media type of `app.js`.
- Proving test: `dropwizard-servlets AssetServletTest#pathParametersDoNotChangeTheMediaType`
- Commit: `fix(servlets): ignore path parameters when choosing asset media type (dropwizard/dropwizard#11385)`
- Status: fork-only; upstream fix proposed in the PR above
- Files: `dropwizard-servlets/src/main/java/io/dropwizard/servlets/assets/AssetServlet.java`, `dropwizard-servlets/src/test/java/io/dropwizard/servlets/assets/AssetServletTest.java`
