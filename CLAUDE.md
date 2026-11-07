# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Dropwizard is a Java framework that glues together Jetty, Jersey, Jackson, Logback, Hibernate Validator and Metrics, with optional JDBI, Hibernate and Liquibase modules. This branch, `release/5.0.x`, targets Java 17 and Jakarta EE 10 on Jetty 12.

## Commands

Use the Maven wrapper with JDK 17 or newer. CI runs JDK 17, 21 and 25 on both Linux and Windows, so tests must pass on Windows too.

```bash
# Full build, as CI runs it
./mvnw -B -fae -DtrimStackTrace=false -Dsurefire.rerunFailingTestsCount=1 install

# Faster local build: the dev profile skips javadoc, sources, pgpverify and jacoco, and configures parallel Surefire
./mvnw -Pdev install

# Build and install without running tests
./mvnw -Pdev -DskipTests install

# One test class in one module, building its upstream modules first
./mvnw -Pdev -pl dropwizard-jackson -am -Dtest=DiscoverableSubtypeResolverTest -Dsurefire.failIfNoSpecifiedTests=false test

# One test method
./mvnw -Pdev -pl dropwizard-jackson -am -Dtest='DiscoverableSubtypeResolverTest#someMethod' -Dsurefire.failIfNoSpecifiedTests=false test
```

- Both `-am` and `-Dsurefire.failIfNoSpecifiedTests=false` are needed for a single test. Without `-am`, sibling `SNAPSHOT` modules don't resolve unless they're already installed. Without the flag, the build fails in the first upstream module that has no matching test.
- Use `verify` rather than `test` to check dependency changes, because `maven-dependency-plugin:analyze-only` runs in that phase with `failOnWarning`. A dependency that is used but not declared can pass `test` and still fail `verify`.
- Test reports are in `<module>/target/surefire-reports`.

The Maven build has no Checkstyle or Spotless. Linting happens during compilation (see "Static analysis" below), and formatting follows `.editorconfig` and the surrounding code. `.properties` files are latin1.

**Example app:** run `./mvnw package` from the root, then from `dropwizard-example/`:

```bash
java -jar target/dropwizard-example-$DW_VERSION.jar db migrate example.yml
java -jar target/dropwizard-example-$DW_VERSION.jar server example.yml
```

**Docs (Sphinx):** from `docs/`, run `pip install -r requirements.txt`, then `make html` (output in `target/html`) or `make livehtml` (serves on port 8000).

## Build structure

The POMs form a single inheritance chain rather than a flat parent:

`dropwizard-project` (root) → `dropwizard-bom` (versions of our own modules) → `dropwizard-dependencies` (third-party and plugin versions) → `dropwizard-parent` (compiler, ErrorProne, enforcer and Surefire config) → each module.

- Third-party versions belong in `dropwizard-dependencies`, not in module POMs.
- A new published module must be added to the root `<modules>` and to `dropwizard-bom`, and must set the `module.name` property. That property becomes `Automatic-Module-Name`; the repo has no `module-info.java` files.
- The root POM's `all-modules` profile adds `docs`, `dropwizard-e2e` and `dropwizard-benchmarks` (JMH). It is active unless `performRelease` is set.
- `docs/source/examples` is a separate Maven tree with its own parent (`examples-parent`) and a hard-coded project version, but it builds in the root reactor.

### Static analysis

These checks fail the build:

- **ErrorProne and NullAway** run in `javac`, with NullAway at `ERROR` for all of `io.dropwizard` except `io.dropwizard.benchmarks`. Mark nullable values with `org.jspecify.annotations.Nullable`. `.mvn/jvm.config` holds the `--add-exports` flags this needs.
- **The enforcer** requires dependency convergence and bans `javax.*` API artifacts, `jsr305`, `commons-logging`, `log4j` and other SLF4J bindings.
- **The dependency analyzer** runs at `verify`, as described under "Commands".

## Architecture

### Module layers

Modules depend roughly upward through these layers:

1. **Foundation:** `util`, then `jackson`, `validation`, `lifecycle`, `servlets`
2. **Subsystems:** `configuration`, `logging`, `metrics`, `jersey`, `jetty`, then `request-logging`, `health`
3. **Assembly:** `core`, which wires all of the above together
4. **Optional add-ons:** `client`, `auth`, `db`, `hibernate`, `jdbi3`, `migrations`, `forms`, `assets`, `views` and its renderers, `http2`, `unix-socket`, `json-logging`, `metrics-graphite`
5. **Test support:** `testing`

### Package names

Packages must not be split across modules, for JPMS compatibility. That is why some modules have a qualifier: `io.dropwizard.core`, `io.dropwizard.logging.common`, `io.dropwizard.metrics.common`, `io.dropwizard.views.common`. Add new classes to a package that only the current module owns.

### Application startup

1. `Application.run(String...)` creates the `Bootstrap`, adds the `server` and `check` commands, calls `initialize(bootstrap)`, registers metrics and hands off to `Cli`.
2. `ConfiguredCommand` parses and validates the YAML configuration.
3. `EnvironmentCommand` builds the `Environment`, configures the metrics, server and health factories, then runs the bundles (`bootstrap.run`) and `application.run(config, env)`.
4. `ServerCommand` calls `ServerFactory.build(environment)` and starts Jetty.

`DefaultServerFactory` serves the application and admin contexts on separate connectors. `SimpleServerFactory` serves both on one connector. Shared logic is in `AbstractServerFactory`.

### Polymorphic configuration

Pluggable config types such as connectors, appenders, reporters and server factories are discovered at runtime through two levels of service files, read by `DiscoverableSubtypeResolver`:

- `META-INF/services/io.dropwizard.jackson.Discoverable` lists the factory interfaces.
- `META-INF/services/<factory interface>` lists the implementations.

Adding an implementation means updating the service file and annotating the class with `@JsonTypeName`. Otherwise its `type:` value won't resolve when the configuration is parsed. A module that only adds implementations of a factory interface declared elsewhere needs just the second file; for example, `dropwizard-http2` only has `io.dropwizard.jetty.ConnectorFactory`.

### Tests

Tests use JUnit 5 and AssertJ, and all run under Surefire; there are no `*IT` classes. Surefire pins the locale and timezone to `en`/`US`/`UTC` and loads the byte-buddy agent.

Add `@ExtendWith(DropwizardExtensionsSupport.class)` to use the extensions in `dropwizard-testing`: `ResourceExtension` (a single Jersey resource), `DropwizardAppExtension` (a full application), `DropwizardClientExtension` and `DAOTestExtension`.

Modules that `dropwizard-testing` depends on, including `core`, can't use it in their own tests without creating a dependency cycle. Full-application tests live in `dropwizard-e2e/src/test/java/com/example`.

## Docs and contributions

- User docs in `docs/source/manual` pull code in through `dropwizard_literalinclude` from `docs/source/examples`, which is compiled by the build. When an API changes, update those examples as well as the prose.
- Breaking changes go in `docs/source/manual/upgrade-notes/upgrade-notes-5_0_x.rst`. Release notes are kept in GitHub releases, not in `release-notes.rst`.
- New features need an issue before a PR. PR descriptions follow `PULL_REQUEST_TEMPLATE.md` (Problem, Solution, Result). Fixes and features need tests and any related doc updates.
- Renovate manages dependency updates on `release/5.0.x` and holds `io.dropwizard.metrics` below 4.3.0.
