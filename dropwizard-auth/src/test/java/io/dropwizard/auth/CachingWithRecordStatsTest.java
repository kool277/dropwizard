package io.dropwizard.auth;

import com.codahale.metrics.MetricRegistry;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.github.benmanes.caffeine.cache.CaffeineSpec;
import org.junit.jupiter.api.Test;

import java.security.Principal;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

class CachingWithRecordStatsTest {
    private final Authenticator<String, Principal> authenticator = credentials -> Optional.of(new PrincipalImpl(credentials));

    @Test
    void authenticatorAcceptsASpecThatAlreadyRecordsStats() throws Exception {
        final CachingAuthenticator<String, Principal> cached = new CachingAuthenticator<>(
            new MetricRegistry(), authenticator, CaffeineSpec.parse("maximumSize=10,recordStats"));

        cached.authenticate("a");
        cached.authenticate("a");

        assertThat(cached.stats().hitCount()).isEqualTo(1);
    }

    @Test
    void authorizerAcceptsABuilderThatAlreadyRecordsStats() {
        final Authorizer<Principal> authorizer = (principal, role, context) -> true;

        new CachingAuthorizer<>(new MetricRegistry(), authorizer, Caffeine.from("maximumSize=10,recordStats"));
    }
}
