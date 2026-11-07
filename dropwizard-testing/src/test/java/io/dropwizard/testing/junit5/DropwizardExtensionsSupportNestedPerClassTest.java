package io.dropwizard.testing.junit5;

import io.dropwizard.testing.junit5.helper.RecordingTestExtension;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.platform.testkit.engine.EngineTestKit;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.platform.engine.discovery.DiscoverySelectors.selectClass;

class DropwizardExtensionsSupportNestedPerClassTest {
    @Test
    void outerPerMethodFieldStartsAroundEachTestOfAPerClassNestedClass() {
        OuterPerMethod.log.clear();

        EngineTestKit.engine("junit-jupiter")
            .configurationParameter(
                "junit.jupiter.conditions.deactivate",
                "org.junit.jupiter.engine.extension.DisabledCondition")
            .selectors(selectClass(OuterPerMethod.class))
            .execute();

        assertThat(OuterPerMethod.log)
            .containsExactly("before:inner", "before:outer", "test-body", "after:outer", "after:inner");
    }

    @Disabled("test-kit fixture: executed indirectly via EngineTestKit")
    @ExtendWith(DropwizardExtensionsSupport.class)
    static class OuterPerMethod {
        static final List<String> log = new ArrayList<>();
        final RecordingTestExtension outer = new RecordingTestExtension("outer", log);

        @Nested
        @TestInstance(TestInstance.Lifecycle.PER_CLASS)
        class Inner {
            final RecordingTestExtension inner = new RecordingTestExtension("inner", log);

            @Test
            void test() {
                log.add("test-body");
            }
        }
    }
}
