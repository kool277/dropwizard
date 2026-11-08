# Compatibility report: Dropwizard 5.0.2-fix.1

## Summary

This fork is upstream Dropwizard at `a8a09d85e6` on `release/5.0.x`, plus 14 bug fixes, a compatibility harness and an operations guide. Each fix has a test that fails on upstream and passes on the fork. Apart from those fixes, the fork behaves identically to upstream: same commands, admin endpoints, metric names, log formats, configuration keys and defaults, runtime dependencies, and binary and source API.

- **Commits:** `a8a09d85e6..fix/5.0.x`: the harness and 4 later fixes to it, 14 bug fixes, the operations guide, and the commit that adds this report. Each commit passed the gate described below.
- **Date:** 2026-11-07
- **Upstream base:** tag `v5.0.2` plus 148 commits, which is commit `a8a09d85e6` on `release/5.0.x`. Upstream hasn't tagged that commit, which is a deliberate, recorded exception to basing the fork on a tag (see `FORK_CHANGES.md`).
- **Version:** `5.0.2-fix.1`. Maven orders it after `5.0.2` and before `5.0.3`, checked with `ComparableVersion`.

## Version matrix

| Library | Upstream base | Fork |
|---|---|---|
| Java baseline | 17 | 17 |
| Jetty | 12.1.14 | 12.1.14 |
| Jersey | 3.1.12 | 3.1.12 |
| Jackson | 2.22.4 | 2.22.4 |
| Hibernate Validator | 8.0.5.Final | 8.0.5.Final |
| Hibernate ORM | 6.6.59.Final | 6.6.59.Final |
| Logback / logback-access | 1.5.38 / 2.0.15 | 1.5.38 / 2.0.15 |
| SLF4J | 2.0.20 | 2.0.20 |
| Metrics | 4.2.40 | 4.2.40 |
| JDBI | 3.54.0 | 3.54.0 |
| Liquibase | 4.33.0 | 4.33.0 |
| Apache HttpClient / HttpCore | 5.6.5 / 5.4.4 | 5.6.5 / 5.4.4 |
| tomcat-jdbc | 11.0.27 | 11.0.27 |
| Caffeine / Guava | 3.3.1 / 33.7.2-jre | 3.3.1 / 33.7.2-jre |
| FreeMarker / Mustache | 2.3.35 / 0.9.14 | 2.3.35 / 0.9.14 |

There are no dependency exceptions. The only `pom.xml` change is a test-scope `junit-jupiter-params` in `dropwizard-jersey`, which a new test needs.

## Harness results

`compat/run.sh --full` on `f9a725a12e`, against the baseline recorded from upstream:

| Check | Result | Detail |
|---|---|---|
| Commands and flags | PASS | 17 files identical |
| Smoke run: admin, logs, shutdown | PASS | 17 files identical |
| Configuration corpus | PASS | 181 files identical |
| Runtime dependencies | PASS | 31 files identical |
| Binary and source compatibility | PASS | 29 modules |
| Archetype project | n/a | no archetype module exists in this release line |
| Canary application | n/a | CANARY_APP is not set |

The harness was checked in two ways before it was committed. A second capture of upstream matched the baseline exactly. A copy of upstream with five planted regressions failed the matching check for each one:

| Planted regression | Detected by |
|---|---|
| `idleTimeout` default changed from 30 to 31 seconds | Configuration corpus |
| `commons-text` added as a runtime dependency | Runtime dependencies |
| `deadlocks` health check renamed | Smoke run (health check JSON) |
| Log pattern changed from `%-5p` to `%-6p` | Smoke run (log line shapes) |
| `JarLocation` made `final` | Binary and source compatibility |

There is no archetype module on this release line, and no canary application was configured, so those checks don't apply.

## Gate

Every commit passed `compat/gate.sh`. For a commit that touches code, that means `./mvnw clean verify`, `compat/run.sh`, `compat/prove.sh` for the commit's test, and the ledger check; for a documentation commit, the ledger check and `sphinx-build -W`.

| Commit | Change | Gate | Minutes |
|---|---|---|---|
| `320181260c` | test(compat): add compatibility harness against upstream a8a09d85e6 | passed | 11 |
| `8a7b5675a8` | fix(auth): deny access for class-level @DenyAll | failed | 9 |
| | First attempt at the commit above: `HealthIntegrationTest` timed out waiting 5 s for a health check. That test doesn't load the changed code, and 16 isolated runs (8 on upstream, 8 at this commit) all passed, so the gate was run again unchanged | | |
| `8a7b5675a8` | fix(auth): deny access for class-level @DenyAll | passed | 13 |
| `c05bdbfa8f` | fix(servlets): ignore path parameters when choosing asset media type (dropwiza | passed | 12 |
| `434047a51e` | fix(jersey): stop treating AbstractParam errors as format strings (dropwizard/ | passed | 12 |
| `d5c906474e` | fix(jersey): bound the constraint message prefix cache | passed | 11 |
| `b73211b452` | fix(hibernate): bind nested units of work correctly on DualSessionFactory | passed | 12 |
| `a3c4211644` | fix(hibernate): use the primary factory on threads that never prepared | passed | 12 |
| `10c0cdecc2` | fix(client): close the Apache client when the environment stops | passed | 13 |
| `63ee859030` | fix(client): stop truncating timeouts to int milliseconds | passed | 12 |
| `9f1a1e6a0a` | fix(util): saturate DataSizeUnit conversions instead of overflowing (dropwizar | passed | 11 |
| `86b86e5aec` | fix(health): notify health state listeners once per change (dropwizard/dropwiz | passed | 12 |
| `c5f4d2db42` | fix(auth): allow caches that already record statistics | passed | 12 |
| `360f0048a5` | fix(testing): only tear down extensions whose before() succeeded in beforeAll | passed | 12 |
| `51751bbb78` | fix(testing): start outer extensions under a PER_CLASS nested class | passed | 12 |
| `73941f31ce` | fix(testing): roll back DAOTest transactions when an Error is thrown | passed | 12 |
| `040f7f210d` | docs(fork): add an operations guide with measured hardware and network needs | passed | 1 |
| `38dd7e8d04` | test(compat): fix perf.sh server tracking and use dedicated CPUs for performan | passed | 10 |
| `c81e175af3` | test(compat): compare startup with alternating samples, and pass --full settin | passed | 10 |
| `fe0af19571` | test(compat): compare latency in alternating trials with a significance test | passed | 10 |
| `f9a725a12e` | test(compat): compare memory and benchmarks in alternating samples, and measur | passed | 11 |

## Bugs fixed

| Id | Module | Bug | Proving test | Upstream |
|---|---|---|---|---|
| B1 | auth | Class-level `@DenyAll` is ignored, so methods without their own annotation are reachable anonymously | `ClassLevelDenyAllTest` | Issue #11401 |
| B2 | servlets | Path parameters such as `;x.html` choose the asset media type | `AssetServletTest#pathParametersDoNotChangeTheMediaType` | PR #11385 by another contributor, tracking |
| B3 | jersey | `AbstractParam` passes client input to `String.format`: 500 instead of 400, and format widths are honoured | `AbstractParamErrorMessageTest` | PR #11364 by another contributor, tracking |
| B4 | jersey | Constraint message cache grows with client-chosen map keys | `ConstraintMessageCacheTest` | Issue #11402, PR #11411 |
| B5 | hibernate | Nested `@UnitOfWork` on `DualSessionFactory` replaces the outer session, closed sessions stay bound | `DualSessionFactoryUnitOfWorkTest` | Issue #11403 |
| B6 | hibernate | `DualSessionFactory` throws `NullPointerException` on threads that never called `prepare` | `DualSessionFactoryTest#threadsThatNeverPreparedUseThePrimaryFactory` | Issue #11404, PR #11413 |
| B7 | client | `JerseyClientBuilder` never closes the Apache client's connection pool | `JerseyClientBuilderTest#closesTheApacheClientWhenTheEnvironmentStops` | Issue #11405 |
| B8 | client | Timeouts of 25 days or more overflow `int` milliseconds | `HttpClientBuilderTest#timeoutsLongerThanAnIntOfMillisecondsAreNotTruncated` | Issue #11406, PR #11412 |
| B9 | util | `DataSizeUnit` conversions overflow to wrong or negative sizes | `DataSizeOverflowTest` | PR #11363 by another contributor, tracking |
| B10 | health | Health state listeners are notified twice per change | `HealthCheckManagerListenerTest` | PR #11371 by another contributor, tracking |
| B11 | auth | Cache specs containing `recordStats` fail at startup | `CachingWithRecordStatsTest` | Issue #11407 |
| B12 | testing | `afterAll` tears down extensions whose `before()` failed or was rolled back | `DropwizardExtensionsSupportAfterAllTest` | Issue #11408 |
| B13 | testing | An outer `PER_METHOD` extension never starts under a `PER_CLASS` nested class | `DropwizardExtensionsSupportNestedPerClassTest` | Issue #11409 |
| B14 | testing | `DAOTest` leaves the transaction open when an `Error` is thrown | `DAOTestExtensionTest#rollsBackTransactionWhenAnErrorIsThrown` | Issue #11410 |

The 10 issues were opened on 2026-11-08 after a search of upstream issues and pull requests found no duplicates. The 4 PRs marked "tracking" are by another contributor; the fork's fixes were written independently, and the fork's tests and theirs pass against both implementations. B1, B5, B7 and B11 change visible behaviour, so their issues propose a fix and wait for a maintainer before any PR. Root causes and visible changes are in `FORK_CHANGES.md`.

## Security review

Severity is for a default configuration unless the precondition says otherwise.

| Severity | Finding | Precondition | Status |
|---|---|---|---|
| Medium | Class-level `@DenyAll` doesn't deny (B1) | A resource class with this annotation | Fixed |
| Medium | `AbstractParam` formats client input (B3) | A custom parameter whose parse error echoes the input | Fixed |
| Medium | Constraint message cache grows without limit (B4) | An endpoint that validates a `Map` with client-chosen keys | Fixed |
| Medium | Path parameters change an asset's media type (B2) | An asset whose content can be interpreted as HTML | Fixed |
| Medium | Gzip request bodies are decompressed without limit: about 1 MB that expands to 1 GB was accepted with `204` after 3.4 seconds | Gzip enabled (the default) and a reachable endpoint. Endpoints that read the whole body into memory are the most exposed (not measured) | Documented in the operations guide. A fix needs a new configuration key: decision needed |
| Medium | The admin interface has no authentication and listens on all interfaces | Network access to port 8081 | Documented in the operations guide. Changing the default isn't allowed in this fork |
| Medium | `amqp-client` 5.35.0 has GHSA-7822-rcf6-97fx and GHSA-cqgh-8p3p-mx4m | Only via `metrics-graphite`, and only if an application uses its RabbitMQ sender | Accepted: you chose to keep upstream's dependency list. Applications that use that sender can pin 5.37.1 |
| Low | `X-Request-Id` from the client is reflected and logged unvalidated (upstream PR 11378) | Log consumers that trust the id | Deferred: fixing it changes a default |
| Low | An exception escaping a non-Jersey servlet shows its class and message on Jetty's error page | A servlet or filter that throws | Deferred; found by code reading, not reproduced |
| Low | `access_token` query parameter is always accepted, and appears in request logs | OAuth filter in use and readable logs | Documented in the operations guide |
| Low | HTTP/2 allows 1,024 concurrent streams and no minimum data rate | HTTP/2 connector in use | Deferred: changing defaults isn't allowed in this fork |
| Low | TLS renegotiation is allowed by default | HTTPS connector, TLS 1.2 | Deferred, same reason |
| Low | FreeMarker uses `DEBUG_HANDLER` and the unrestricted class resolver | FreeMarker views with untrusted templates or failures after the response is committed | Deferred, same reason |
| Low | Configuration errors print the offending YAML line, which can include a substituted secret | A malformed line holding a secret, and readable startup output | Deferred |
| Low | `PolymorphicAuthDynamicFeature` doesn't apply `@PermitAll` without an `@Auth` parameter, unlike the docs say | Polymorphic auth in use | Deferred |
| Low | `PermitAllAuthorizer` is the default, so omitting `setAuthorizer` lets every authenticated user pass `@RolesAllowed` | Omitted authorizer | Deferred |
| Low | Default `Authorization` headers set on the client builder survive cross-host redirects | `using(List<Header>)` and a hostile redirect | Deferred |
| Info | `useForwardedHeaders` trusts every peer; the simple server puts admin on the application port | Operator opt-in | Documented |
| Info | Jackson's `StreamReadConstraints` defaults don't limit document size | Large untrusted bodies | Documented |

**Scans:** grype (database of 2026-11-05) and OSV found no High or Critical advisories in the 178 runtime components of the upstream base's SBOM; the only matches are the two `amqp-client` Medium advisories above. Upstream issue 11380 lists CVEs for the Jackson, HttpCore and Jetty versions in 5.0.2; the base has newer versions of all three, and neither scanner reports those CVEs for them. gitleaks found 7 matches in the full history, all test credentials and tokens in test classes, and no real secrets.

## Footprint and performance

`compat/run.sh --full` on `f9a725a12e`, on dedicated CPUs 8–13 of the same 16-vCPU virtual machine (server on 4, load generator on 2), with Eclipse Temurin 17.0.20.1. Each comparison alternates upstream and the fork.

| Metric | Upstream | Fork | Change | Result |
|---|---|---|---|---|
| example jar (bytes) | 59,556,728.0 | 59,558,583.0 | +0.0% | PASS |
| startup to first 200 (ms, 12 alternating each) | 3,778.0 | 3,790.0 | +0.3% | PASS |
| RSS after 60 s light load (MB, 6 each), p=0.242 | 340.7 | 351.1 | +3.1% | PASS |
| live heap after full GC (MB) | 24.9 | 25.0 | +0.3% | PASS |
| non-heap memory committed (MB) | 175.5 | 175.4 | -0.0% | PASS |
| heap committed by the GC (MB) | 152.0 | 151.0 | -0.7% | info |
| get requests/s (8 alternating trials each) | 26,285.2 | 25,966.4 | -1.2% | info |
| get p50 (us) | 1,243.0 | 1,260.5 | +1.4% | info |
| get p95 (us) | 2,809.5 | 2,825.5 | +0.6% | info |
| get p99 (us), p=0.677 | 4,194.0 | 4,168.5 | -0.6% | PASS |
| get allocation (bytes/request, 4 rounds) | 33,001.3 | 32,978.5 | -0.1% | PASS |
| get GC count (30 s) | 171.0 | 168.5 | -1.5% | info |
| post requests/s (8 alternating trials each) | 24,106.7 | 24,888.3 | +3.2% | info |
| post p50 (us) | 1,311.5 | 1,288.0 | -1.8% | info |
| post p95 (us) | 10,280.5 | 8,086.5 | -21.3% | info |
| post p99 (us), p=0.747 | 21,544.5 | 19,768.0 | -8.2% | PASS |
| post allocation (bytes/request, 4 rounds) | 24,708.7 | 24,870.3 | +0.7% | PASS |
| post GC count (30 s) | 45.0 | 45.5 | +1.1% | info |
| jmh ConstraintViolationBenchmark.objViolation (ns/op, 4 forks each), p=0.757 | 56.5 | 56.2 | -0.5% | PASS |
| jmh ConstraintViolationBenchmark.paramViolation (ns/op, 4 forks each), p=0.557 | 55.4 | 55.6 | +0.3% | PASS |
| jmh DataSizeBenchmark.parseSize (ns/op, 4 forks each), p=0.943 | 176.8 | 173.7 | -1.8% | PASS |
| jmh DurationBenchmark.parseDuration (ns/op, 4 forks each), p=0.757 | 130.7 | 130.1 | -0.4% | PASS |
| jmh SelfValidatingBenchmark.selfValidating (ns/op, 4 forks each), p=0.243 | 562.5 | 586.0 | +4.2% | PASS |
| jmh SelfValidatingBenchmark.validationMethod (ns/op, 4 forks each), p=0.657 | 109.4 | 108.4 | -0.9% | PASS |

### Measurement problems found on the way

Earlier versions of the harness reported four failures that turned out to be measurement noise. Each was investigated before the method was changed, and the changes are in the harness commits:

| Reported | What was found | Change |
|---|---|---|
| Startup +10.3% | 3 startups per round varied by up to 20%. 12 alternating startups per side showed -0.4%. | Alternating startups |
| POST p99 +10.8%, consistent over 3 rounds | Upstream always ran first in each round, and JFR was recording during the measurement. 8 alternating trials per side, without JFR, showed -12% (p = 0.78). POST p99 ranged from 14 to 53 ms for the same code. | Alternating latency trials, significance test |
| RSS +17.2% | Native memory tracking showed identical memory in every category; the RSS difference was how much heap G1 had committed (80 to 152 MB), which varied for both sides. | Alternating samples, strict checks on live heap and non-heap memory |
| JMH `paramViolation` +5.3% | One JVM fork per side. With 6 forks per side the difference was -0.4% (p = 0.71). | 4 forks per side, significance test |

The harness itself also had bugs that these runs found: the performance script lost the server's process ID, the rounds setting didn't reach the container, and output paths broke when scripts changed directory. All are fixed, and each fix passed the gate.

### Capacity of the example application

The operations guide (`docs/source/manual/operations.rst`) has the measured CPU, memory, startup, concurrency, TLS and network figures for upstream's example application, and what they mean for sizing.

## Documentation changes

- `docs/source/manual/operations.rst` (new) and `docs/source/index.rst`: the operations guide (F2)
- `docs/source/manual/auth.rst`: class-level `@DenyAll` (B1)
- `RELEASE_NOTES_5.0.2-fix.1.md`, `FORK_CHANGES.md`, `compat/README.md` and this report

## Changes not made, and why

| Change | Reason |
|---|---|
| Pin `amqp-client` to 5.37.1 | Crosses a minor version and changes the dependency list; you chose to keep upstream's |
| Limit decompressed request size | Needs a new configuration key, which is a hard stop: decision needed |
| Bind the admin connector to loopback by default | Changes a default |
| Validate `X-Request-Id`, disable TLS renegotiation, lower HTTP/2 stream limits, harden FreeMarker | Each changes a default |
| README build section, `RELEASES.md` process update, stale TLS and gzip entries in `configuration.rst` | Outside a fix, the harness or fork documentation; better proposed upstream |
| Stop deployment from the fork's `Release` workflow | Not changed in the repository; see the commands below |

## Deferred

In priority order:

1. **Decision needed:** a limit on decompressed request bodies, as a new opt-in key.
2. Bugs found but not fixed, because the right behaviour needs a decision upstream:
   - `CachingAuthorizer` never gets a cache hit, because its default key includes the request.
   - A stopped scheduled executor still runs delayed tasks.
   - `JerseyClientBuilder` without an environment never closes its pool, and rebuilding a client with the same name fails on duplicate metrics.
   - `DAOTest` never closes its `SessionFactory`.
3. Smaller bugs from the review, each reproduced only by a probe program: a YAML file containing only `---` reports a validation error instead of "empty"; a missing classpath configuration resource causes `NullPointerException`; a non-string system property key causes `ClassCastException`; very large `Duration` values saturate in `toJavaDuration()`; overriding the same key twice in `DropwizardTestSupport` leaves the property set; `ExecutorServiceBuilder` names metrics oddly when the name has no format specifier; `ConfigOverrideRandomPorts` fails without a connector section.
4. Upstream issues not addressed: 3435 (empty UUID query parameters, blocked upstream), 10907 (the `type` health query parameter only affects the status code), 11305 (logback-access built against logback-core 1.6), 11330 (an advisory that can't be viewed publicly).
5. Upstream: 10 issues are open (#11401 to #11410) and 3 PRs (#11411 to #11413). More PRs follow as reviews come in, at most 3 open at once.

## Commands still to be run by a human

None. With your approval, this session disabled the `Release` workflow on `kool277/dropwizard`, opened the upstream issues and pull requests above, pushed `fix/5.0.x`, pushed the annotated tag `v5.0.2-fix.1`, and published the GitHub release with this report and the SBOM: https://github.com/kool277/dropwizard/releases/tag/v5.0.2-fix.1. `fix/5.0.x` then moved to `5.0.2-fix.2-SNAPSHOT`.
