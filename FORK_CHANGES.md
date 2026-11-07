# Fork changes

This fork is upstream Dropwizard at the commit below, plus the changes listed here. Every file that differs from upstream must be covered by an entry; `compat/check_ledger.py` enforces this.

- **Upstream base:** `a8a09d85e6` on `release/5.0.x` (148 commits after `v5.0.2`). This commit has no upstream tag, which is a deliberate exception to basing the fork on a tag: `v5.0.3` doesn't exist yet, and the later commits include fixes and library updates that the fork should keep. Move to `v5.0.3` once upstream publishes it.
- **Version scheme:** `5.0.2-a8a09d85-fix.N`

## Fork-only

### F1: Compatibility harness and fork documents

- Why: proves that the fork behaves like upstream, apart from the entries below.
- Commits: `320181260c`, `38dd7e8d04`, `c81e175af3`, `fe0af19571`, `f9a725a12e`, and the commit that adds this report
- Status: fork-only
- Files: `compat/*`, `FORK_CHANGES.md`, `RELEASE_NOTES_*.md`, `COMPATIBILITY_REPORT.md`

### F2: Operations guide

- Why: requested for this fork. Documents what Dropwizard needs from the machine and the network, its default limits,
  and how to run it securely, with measurements of the example application.
- Commit: `040f7f210d`
- Status: fork-only. It could be proposed upstream, but its measurements describe one machine.
- Files: `docs/source/manual/operations.rst`, `docs/source/index.rst`

## Fixes

Each fix has a test that fails on the upstream base and passes here, shown by `compat/prove.sh`.

### B1: Class-level `@DenyAll` is ignored

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-auth`
- Root cause: `AuthDynamicFeature` only looks for `@RolesAllowed` and `@PermitAll` on classes, and Jersey's `RolesAllowedDynamicFeature` doesn't read a class-level `@DenyAll` either.
- Visible change: Methods of a class annotated with `@DenyAll` now return 401 or 403 unless they have their own security annotation. A class that relied on the annotation being ignored must remove it.
- Proving test: `dropwizard-auth ClassLevelDenyAllTest`
- Commit: `8a7b5675a8` fix(auth): deny access for class-level @DenyAll
- Status: fork-only
- Files: `dropwizard-auth/src/main/java/io/dropwizard/auth/AuthDynamicFeature.java`, `dropwizard-auth/src/test/java/io/dropwizard/auth/ClassLevelDenyAllTest.java`, `docs/source/manual/auth.rst`

### B2: Path parameters choose the asset media type

- Upstream issue: [dropwizard/dropwizard#11385](https://github.com/dropwizard/dropwizard/pull/11385), open.
- Module: `dropwizard-servlets`
- Root cause: `AssetServlet` loads the asset from the decoded path, but picks the media type from `getRequestURI()`, which still has `;` path parameters.
- Visible change: `/app.js;x.html` is served with the media type of `app.js`.
- Proving test: `dropwizard-servlets AssetServletTest#pathParametersDoNotChangeTheMediaType`
- Commit: `c05bdbfa8f` fix(servlets): ignore path parameters when choosing asset media type (dropwizard/dropwizard#11385)
- Status: fork-only; upstream fix proposed in the PR above
- Files: `dropwizard-servlets/src/main/java/io/dropwizard/servlets/assets/AssetServlet.java`, `dropwizard-servlets/src/test/java/io/dropwizard/servlets/assets/AssetServletTest.java`

### B3: `AbstractParam` formats client input

- Upstream issue: [dropwizard/dropwizard#11364](https://github.com/dropwizard/dropwizard/pull/11364), open.
- Module: `dropwizard-jersey`
- Root cause: `generateErrorMessage` passes the message to `String.format` if it contains `%s`, and the default message includes the parse exception's text, which can echo the input.
- Visible change: `%s` in an error message is replaced literally. A custom `errorMessage` using `%%` for a percent sign must now use `%`, and other format specifiers are no longer interpreted.
- Proving test: `dropwizard-jersey AbstractParamErrorMessageTest`
- Commit: `434047a51e` fix(jersey): stop treating AbstractParam errors as format strings (dropwizard/dropwizard#11364)
- Status: fork-only; upstream fix proposed in the PR above
- Files: `dropwizard-jersey/src/main/java/io/dropwizard/jersey/params/AbstractParam.java`, `dropwizard-jersey/src/test/java/io/dropwizard/jersey/params/AbstractParamErrorMessageTest.java`, `dropwizard-jersey/pom.xml`

### B4: Constraint message cache has no size limit

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-jersey`
- Root cause: `ConstraintMessage.PREFIX_CACHE` only expires entries after an hour, and its key includes the violation path, which for a `Map` includes the client's map keys.
- Visible change: None. Evicted entries are recalculated.
- Proving test: `dropwizard-jersey ConstraintMessageCacheTest`
- Commit: `d5c906474e` fix(jersey): bound the constraint message prefix cache
- Status: fork-only
- Files: `dropwizard-jersey/src/main/java/io/dropwizard/jersey/validation/ConstraintMessage.java`, `dropwizard-jersey/src/test/java/io/dropwizard/jersey/validation/ConstraintMessageCacheTest.java`

### B5: Nested `@UnitOfWork` breaks on `DualSessionFactory`

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-hibernate`
- Root cause: `UnitOfWorkAspect` calls `hasBind` and `unbind` with the `DualSessionFactory` wrapper, but `ManagedSessionContext.bind` uses the session's own factory, so they never match. The aspect also never restores the factory chosen by `prepare`.
- Visible change: A nested unit of work joins the outer session instead of committing separately, and the outer session stays usable afterwards.
- Proving test: `dropwizard-hibernate DualSessionFactoryUnitOfWorkTest`
- Commit: `b73211b452` fix(hibernate): bind nested units of work correctly on DualSessionFactory
- Status: fork-only
- Files: `dropwizard-hibernate/src/main/java/io/dropwizard/hibernate/UnitOfWorkAspect.java`, `dropwizard-hibernate/src/test/java/io/dropwizard/hibernate/dual/DualSessionFactoryUnitOfWorkTest.java`

### B6: `DualSessionFactory` fails on threads that never called `prepare`

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-hibernate`
- Root cause: The active factory is a `ThreadLocal` that the constructor sets for its own thread only.
- Visible change: Calls on other threads use the primary factory instead of throwing `NullPointerException`.
- Proving test: `dropwizard-hibernate DualSessionFactoryTest#threadsThatNeverPreparedUseThePrimaryFactory`
- Commit: `a3c4211644` fix(hibernate): use the primary factory on threads that never prepared
- Status: fork-only
- Files: `dropwizard-hibernate/src/main/java/io/dropwizard/hibernate/dual/DualSessionFactory.java`, `dropwizard-hibernate/src/test/java/io/dropwizard/hibernate/dual/DualSessionFactoryTest.java`

### B7: Jersey clients never close their connection pool

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-client`
- Root cause: `DropwizardApacheConnector.close()` leaves the Apache client to the environment, but only `HttpClientBuilder.build` registers it. `JerseyClientBuilder` doesn't.
- Visible change: The connection pool closes when the environment stops. A client built without an environment still isn't closed; see the deferred items in `COMPATIBILITY_REPORT.md`.
- Proving test: `dropwizard-client JerseyClientBuilderTest#closesTheApacheClientWhenTheEnvironmentStops`
- Commit: `10c0cdecc2` fix(client): close the Apache client when the environment stops
- Status: fork-only
- Files: `dropwizard-client/src/main/java/io/dropwizard/client/JerseyClientBuilder.java`, `dropwizard-client/src/test/java/io/dropwizard/client/JerseyClientBuilderTest.java`

### B8: Client timeouts of 25 days or more overflow

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-client`
- Root cause: `HttpClientBuilder.createClient` casts the timeouts to `int` milliseconds.
- Visible change: These timeouts now take effect as configured.
- Proving test: `dropwizard-client HttpClientBuilderTest#timeoutsLongerThanAnIntOfMillisecondsAreNotTruncated`
- Commit: `63ee859030` fix(client): stop truncating timeouts to int milliseconds
- Status: fork-only
- Files: `dropwizard-client/src/main/java/io/dropwizard/client/HttpClientBuilder.java`, `dropwizard-client/src/test/java/io/dropwizard/client/HttpClientBuilderTest.java`

### B9: `DataSizeUnit` conversions overflow

- Upstream issue: [dropwizard/dropwizard#11363](https://github.com/dropwizard/dropwizard/pull/11363), open.
- Module: `dropwizard-util`
- Root cause: `convert` multiplies by the number of bits first, which overflows at 2^60 bytes.
- Visible change: Results that fit are correct, and results that don't fit saturate at `Long.MAX_VALUE` or `Long.MIN_VALUE`.
- Proving test: `dropwizard-util DataSizeOverflowTest`
- Commit: `9f1a1e6a0a` fix(util): saturate DataSizeUnit conversions instead of overflowing (dropwizard/dropwizard#11363)
- Status: fork-only; upstream fix proposed in the PR above
- Files: `dropwizard-util/src/main/java/io/dropwizard/util/DataSizeUnit.java`, `dropwizard-util/src/test/java/io/dropwizard/util/DataSizeOverflowTest.java`

### B10: Health state listeners are notified twice

- Upstream issue: [dropwizard/dropwizard#11371](https://github.com/dropwizard/dropwizard/pull/11371), open.
- Module: `dropwizard-health`
- Root cause: `HealthCheckManager.onStateChanged` has a guarded notification loop followed by an unguarded copy of it.
- Visible change: Listeners are called once per state change, and an exception from a listener no longer escapes into the health check run.
- Proving test: `dropwizard-health HealthCheckManagerListenerTest`
- Commit: `86b86e5aec` fix(health): notify health state listeners once per change (dropwizard/dropwizard#11371)
- Status: fork-only; upstream fix proposed in the PR above
- Files: `dropwizard-health/src/main/java/io/dropwizard/health/HealthCheckManager.java`, `dropwizard-health/src/test/java/io/dropwizard/health/HealthCheckManagerListenerTest.java`

### B11: Caching decorators reject specs with `recordStats`

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-auth`
- Root cause: `CachingAuthenticator` and `CachingAuthorizer` always call `recordStats` on the builder, which Caffeine allows only once.
- Visible change: A valid cache spec that contains `recordStats` now works. This turns a startup failure into success only for that valid configuration; the catch covers the single `recordStats` call and nothing else, so invalid specs still fail at startup.
- Proving test: `dropwizard-auth CachingWithRecordStatsTest`
- Commit: `c5f4d2db42` fix(auth): allow caches that already record statistics
- Status: fork-only
- Files: `dropwizard-auth/src/main/java/io/dropwizard/auth/CachingAuthenticator.java`, `dropwizard-auth/src/main/java/io/dropwizard/auth/CachingAuthorizer.java`, `dropwizard-auth/src/test/java/io/dropwizard/auth/CachingWithRecordStatsTest.java`

### B12: `afterAll` tears down extensions that never started

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-testing`
- Root cause: `DropwizardExtensionsSupport.afterAll` iterates over all fields, without the record of successful `before()` calls that `afterEach` has.
- Visible change: `after()` runs only for fields whose `before()` succeeded.
- Proving test: `dropwizard-testing DropwizardExtensionsSupportAfterAllTest`
- Commit: `360f0048a5` fix(testing): only tear down extensions whose before() succeeded in beforeAll
- Status: fork-only
- Files: `dropwizard-testing/src/main/java/io/dropwizard/testing/junit5/DropwizardExtensionsSupport.java`, `dropwizard-testing/src/test/java/io/dropwizard/testing/junit5/DropwizardExtensionsSupportAfterAllTest.java`

### B13: Outer extension never starts under a `PER_CLASS` nested class

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-testing`
- Root cause: `beforeEach` and `afterEach` return early based on the innermost class's lifecycle, before the walk over enclosing instances that checks each class.
- Visible change: Outer `PER_METHOD` fields start and stop around each nested test, as the class's Javadoc says.
- Proving test: `dropwizard-testing DropwizardExtensionsSupportNestedPerClassTest`
- Commit: `51751bbb78` fix(testing): start outer extensions under a PER_CLASS nested class
- Status: fork-only
- Files: `dropwizard-testing/src/main/java/io/dropwizard/testing/junit5/DropwizardExtensionsSupport.java`, `dropwizard-testing/src/test/java/io/dropwizard/testing/junit5/DropwizardExtensionsSupportNestedPerClassTest.java`

### B14: `DAOTest` leaves the transaction open on an `Error`

- Upstream issue: none found in a search of upstream issues and pull requests on 2026-11-07.
- Module: `dropwizard-testing`
- Root cause: `inTransaction` only catches `Exception`.
- Visible change: The transaction rolls back and the `Error` is rethrown unchanged.
- Proving test: `dropwizard-testing DAOTestExtensionTest#rollsBackTransactionWhenAnErrorIsThrown`
- Commit: `73941f31ce` fix(testing): roll back DAOTest transactions when an Error is thrown
- Status: fork-only
- Files: `dropwizard-testing/src/main/java/io/dropwizard/testing/common/DAOTest.java`, `dropwizard-testing/src/test/java/io/dropwizard/testing/junit5/DAOTestExtensionTest.java`
