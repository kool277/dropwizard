# Dropwizard 5.0.2-a8a09d85-fix.1

Based on upstream `a8a09d85e6` on `release/5.0.x`, 148 commits after `v5.0.2`. This is a bug-fix fork, not an upstream release. It keeps upstream's `io.dropwizard` coordinates, so it is for local use and must not be published.

## Fixes

- Deny access for class-level `@DenyAll`, which was ignored, leaving methods without their own security annotation reachable anonymously. **Behaviour change** for any class that relied on this. (B1)
