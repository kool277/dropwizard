package io.dropwizard.jersey.params;

import jakarta.ws.rs.WebApplicationException;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatExceptionOfType;

class AbstractParamErrorMessageTest {
    private static final class EchoingParam extends AbstractParam<Integer> {
        EchoingParam(@Nullable String input) {
            super(input, "id");
        }

        @Override
        protected Integer parse(@Nullable String input) {
            return Integer.valueOf(input);
        }
    }

    private static final class TemplatedMessageParam extends AbstractParam<Integer> {
        TemplatedMessageParam(@Nullable String input) {
            super(input, "id");
        }

        @Override
        protected String errorMessage(Exception e) {
            return "%s must be an integer";
        }

        @Override
        protected Integer parse(@Nullable String input) {
            return Integer.valueOf(input);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"%s%d", "%s%s%s", "%s%q", "%s%1$50s"})
    void clientInputIsNeverUsedAsAFormatString(String input) {
        assertThatExceptionOfType(WebApplicationException.class)
            .isThrownBy(() -> new EchoingParam(input))
            .satisfies(e -> {
                assertThat(e.getResponse().getStatus()).isEqualTo(400);
                assertThat(e.getMessage()).startsWith("id is invalid: ").doesNotContain("     ");
            });
    }

    @Test
    void parameterNameIsStillSubstitutedIntoCustomMessages() {
        assertThatExceptionOfType(WebApplicationException.class)
            .isThrownBy(() -> new TemplatedMessageParam("x"))
            .withMessage("id must be an integer");
    }
}
