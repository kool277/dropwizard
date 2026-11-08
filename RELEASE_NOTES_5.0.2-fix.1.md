# Dropwizard 5.0.2-fix.1

Based on upstream tag `v5.0.2` plus 148 commits: commit `a8a09d85e6` on `release/5.0.x`, which upstream hasn't tagged. This is a bug-fix fork, not an upstream release. It keeps upstream's `io.dropwizard` coordinates, so it is for local use and must not be published to a Maven repository.

## Fixes

- **B1** (dropwizard-auth): Deny access for class-level `@DenyAll`, which was ignored, leaving methods without their own security annotation reachable anonymously. **Behaviour change** for any class that relied on this. Upstream: issue [#11401](https://github.com/dropwizard/dropwizard/issues/11401) with a proposed fix; no PR until a maintainer responds. Commit `8a7b5675a8`.
- **B2** (dropwizard-servlets): Ignore path parameters when choosing the `AssetServlet` media type, so that a link such as `/app.js;x.html` can't serve an asset as HTML. Upstream: upstream PR #11385 by madib06ops — tracking; drop on sync when merged. Commit `c05bdbfa8f`.
- **B3** (dropwizard-jersey): Stop treating `AbstractParam` error messages as format strings. Input such as `%s%d` now gets a 400 rather than a 500. **Behaviour change:** a custom `errorMessage` that uses `%%` for a percent sign must now use `%`. Upstream: upstream PR #11364 by madib06ops — tracking; drop on sync when merged. Commit `434047a51e`.
- **B4** (dropwizard-jersey): Limit the `ConstraintMessage` prefix cache to 10,000 entries, because its keys can contain client-chosen map keys. Upstream: issue [#11402](https://github.com/dropwizard/dropwizard/issues/11402); PR opened https://github.com/dropwizard/dropwizard/pull/11411. Commit `d5c906474e`.
- **B5** (dropwizard-hibernate): Fix nested `@UnitOfWork` with `DualSessionFactory`: it joins the outer session, closed sessions no longer stay bound to the thread, and the active factory is restored afterwards. Upstream: issue [#11403](https://github.com/dropwizard/dropwizard/issues/11403) with a proposed fix; no PR until a maintainer responds. Commit `b73211b452`.
- **B6** (dropwizard-hibernate): Use the primary factory on threads that never called `DualSessionFactory.prepare`, instead of throwing `NullPointerException`. Upstream: issue [#11404](https://github.com/dropwizard/dropwizard/issues/11404); PR opened https://github.com/dropwizard/dropwizard/pull/11413. Commit `a3c4211644`.
- **B7** (dropwizard-client): Close the connection pool of `JerseyClientBuilder` clients when the environment stops. Upstream: issue [#11405](https://github.com/dropwizard/dropwizard/issues/11405) with a proposed fix; no PR until a maintainer responds. Commit `10c0cdecc2`.
- **B8** (dropwizard-client): Stop truncating client timeouts of 25 days or more, which failed the build or silently became much shorter. Upstream: issue [#11406](https://github.com/dropwizard/dropwizard/issues/11406); PR opened https://github.com/dropwizard/dropwizard/pull/11412. Commit `63ee859030`.
- **B9** (dropwizard-util): Saturate `DataSizeUnit` conversions instead of overflowing to wrong or negative sizes, which also broke `@MaxDataSize` checks and comparisons. Upstream: upstream PR #11363 by madib06ops — tracking; drop on sync when merged. Commit `9f1a1e6a0a`.
- **B10** (dropwizard-health): Notify health state listeners once per state change instead of twice, and stop their exceptions from escaping. Upstream: upstream PR #11371 by madib06ops — tracking; drop on sync when merged. Commit `86b86e5aec`.
- **B11** (dropwizard-auth): Allow `CachingAuthenticator` and `CachingAuthorizer` to use cache specs that contain `recordStats`, which failed at startup. Upstream: issue [#11407](https://github.com/dropwizard/dropwizard/issues/11407) with a proposed fix; no PR until a maintainer responds. Commit `c5f4d2db42`.
- **B12** (dropwizard-testing): Only tear down static and `PER_CLASS` test extensions whose `before()` succeeded. Upstream: issue [#11408](https://github.com/dropwizard/dropwizard/issues/11408); PR to follow after one of this fork's open PRs has been reviewed or merged (at most 3 open). Commit `360f0048a5`.
- **B13** (dropwizard-testing): Start outer `PER_METHOD` test extensions when the nested class uses `PER_CLASS`. Upstream: issue [#11409](https://github.com/dropwizard/dropwizard/issues/11409); PR to follow after one of this fork's open PRs has been reviewed or merged (at most 3 open). Commit `51751bbb78`.
- **B14** (dropwizard-testing): Roll back `DAOTest` transactions when an `Error` such as `AssertionError` is thrown. Upstream: issue [#11410](https://github.com/dropwizard/dropwizard/issues/11410); PR to follow after one of this fork's open PRs has been reviewed or merged (at most 3 open). Commit `73941f31ce`.

## Upgrading from upstream

The fork is a drop-in replacement for upstream at the base commit, except for two deliberate behaviour changes:

- **B1:** methods of a resource class annotated with `@DenyAll` now return 401 or 403 unless they have their own `@PermitAll` or `@RolesAllowed`. If a class relied on the annotation being ignored, remove it.
- **B3:** in a custom `AbstractParam.errorMessage`, `%s` is replaced literally and nothing else is formatted, so write a percent sign as `%`, not `%%`.

## Dependency exceptions

None. Every library version is the same as upstream's. The two Medium advisories for the transitive `com.rabbitmq:amqp-client` 5.35.0 (GHSA-7822-rcf6-97fx, GHSA-cqgh-8p3p-mx4m) remain, as upstream has them; applications that use metrics-graphite's RabbitMQ sender can pin `amqp-client` 5.37.1 themselves.

## Compatibility

`compat/run.sh --full` on `f9a725a12e` passed. Commands, admin endpoints, metric names, log and request-log formats, the effective configuration of 181 files and every configuration type's defaults, runtime dependencies, and the binary and source API of all 29 published modules are identical to upstream. Startup, memory, allocation, latency and the JMH benchmarks are within 5% of upstream. Each fix has a test that fails on upstream and passes here. See `COMPATIBILITY_REPORT.md`.

## New documentation

An operations guide (`docs/source/manual/operations.rst`) with measured CPU, memory, startup, concurrency, TLS, network and disk figures, default limits, and how to isolate the admin interface.
