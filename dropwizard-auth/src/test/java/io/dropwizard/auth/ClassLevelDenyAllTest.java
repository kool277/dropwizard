package io.dropwizard.auth;

import io.dropwizard.auth.basic.BasicCredentialAuthFilter;
import io.dropwizard.auth.util.AuthUtil;
import io.dropwizard.jersey.DropwizardResourceConfig;
import io.dropwizard.logging.common.BootstrapLogging;
import jakarta.annotation.security.DenyAll;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.Response;
import org.glassfish.jersey.server.filter.RolesAllowedDynamicFeature;
import org.glassfish.jersey.server.ServerProperties;
import org.glassfish.jersey.test.JerseyTest;
import org.glassfish.jersey.test.TestProperties;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.security.Principal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ClassLevelDenyAllTest extends JerseyTest {
    static {
        BootstrapLogging.bootstrap();
    }

    private static final String ADMIN = "good-guy";
    private static final String BASIC_ADMIN = "Basic Z29vZC1ndXk6c2VjcmV0";

    @DenyAll
    @Path("/denied")
    public static class DeniedResource {
        @GET
        @Path("no-annotation")
        public String noAnnotation() {
            return "reached";
        }

        @GET
        @Path("auth-parameter")
        public String authParameter(@Auth Principal principal) {
            return "reached";
        }

        @PermitAll
        @GET
        @Path("permit-all")
        public String permitAll(@Auth Principal principal) {
            return "reached";
        }

        @RolesAllowed("ADMIN")
        @GET
        @Path("roles-allowed")
        public String rolesAllowed(@Auth Principal principal) {
            return "reached";
        }
    }

    @Override
    @BeforeEach
    public void setUp() throws Exception {
        super.setUp();
    }

    @Override
    @AfterEach
    public void tearDown() throws Exception {
        super.tearDown();
    }

    @Override
    protected jakarta.ws.rs.core.Application configure() {
        forceSet(TestProperties.CONTAINER_PORT, "0");
        final DropwizardResourceConfig config = DropwizardResourceConfig.forTesting();
        config.property(ServerProperties.RESPONSE_SET_STATUS_OVER_SEND_ERROR, true);
        final BasicCredentialAuthFilter.Builder<Principal> builder = new BasicCredentialAuthFilter.Builder<>();
        builder.setAuthorizer(AuthUtil.getTestAuthorizer(ADMIN, "ADMIN"));
        builder.setAuthenticator(AuthUtil.getBasicAuthenticator(List.of(ADMIN)));
        config.register(new AuthDynamicFeature(builder.buildAuthFilter()));
        config.register(new AuthValueFactoryProvider.Binder<>(Principal.class));
        config.register(RolesAllowedDynamicFeature.class);
        config.register(DeniedResource.class);
        return config;
    }

    private int anonymous(String path) {
        try (Response response = target(path).request().get()) {
            return response.getStatus();
        }
    }

    private int authenticated(String path) {
        try (Response response = target(path).request().header(HttpHeaders.AUTHORIZATION, BASIC_ADMIN).get()) {
            return response.getStatus();
        }
    }

    @Test
    void methodsWithoutAnnotationsAreDenied() {
        assertThat(anonymous("/denied/no-annotation")).isEqualTo(401);
        assertThat(authenticated("/denied/no-annotation")).isEqualTo(403);
    }

    @Test
    void authParametersDoNotBypassTheClassLevelDenial() {
        assertThat(authenticated("/denied/auth-parameter")).isEqualTo(403);
    }

    @Test
    void methodLevelAnnotationsStillOverrideTheClassLevelDenial() {
        assertThat(authenticated("/denied/permit-all")).isEqualTo(200);
        assertThat(authenticated("/denied/roles-allowed")).isEqualTo(200);
        assertThat(anonymous("/denied/permit-all")).isEqualTo(401);
    }
}
