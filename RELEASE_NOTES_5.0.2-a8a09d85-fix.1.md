# Dropwizard 5.0.2-a8a09d85-fix.1

Based on upstream `a8a09d85e6` on `release/5.0.x`, 148 commits after `v5.0.2`. This is a bug-fix fork, not an upstream release. It keeps upstream's `io.dropwizard` coordinates, so it is for local use and must not be published.

## Fixes

- Deny access for class-level `@DenyAll`, which was ignored, leaving methods without their own security annotation reachable anonymously. **Behaviour change** for any class that relied on this. (B1)
- Ignore path parameters when choosing the `AssetServlet` media type, so that a link such as `/app.js;x.html` can't serve an asset as HTML. (B2)
- Stop treating `AbstractParam` error messages as format strings. Input such as `%s%d` now gets a 400 rather than a 500. **Behaviour change:** a custom `errorMessage` that uses `%%` for a percent sign must now use `%`. (B3)
- Limit the `ConstraintMessage` prefix cache to 10,000 entries, because its keys can contain client-chosen map keys. (B4)
- Fix nested `@UnitOfWork` with `DualSessionFactory`: it joins the outer session, closed sessions no longer stay bound to the thread, and the active factory is restored afterwards. (B5)
- Use the primary factory on threads that never called `DualSessionFactory.prepare`, instead of throwing `NullPointerException`. (B6)
- Close the connection pool of `JerseyClientBuilder` clients when the environment stops. (B7)
- Stop truncating client timeouts of 25 days or more, which failed the build or silently became much shorter. (B8)
- Saturate `DataSizeUnit` conversions instead of overflowing to wrong or negative sizes, which also broke `@MaxDataSize` checks and comparisons. (B9)
- Notify health state listeners once per state change instead of twice, and stop their exceptions from escaping. (B10)
- Allow `CachingAuthenticator` and `CachingAuthorizer` to use cache specs that contain `recordStats`, which failed at startup. (B11)
- Only tear down static and `PER_CLASS` test extensions whose `before()` succeeded. (B12)
- Start outer `PER_METHOD` test extensions when the nested class uses `PER_CLASS`. (B13)
- Roll back `DAOTest` transactions when an `Error` such as `AssertionError` is thrown. (B14)
