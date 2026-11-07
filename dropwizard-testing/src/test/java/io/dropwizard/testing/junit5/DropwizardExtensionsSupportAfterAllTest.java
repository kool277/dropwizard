package io.dropwizard.testing.junit5;

import io.dropwizard.testing.junit5.helper.RecordingTestExtension;
import io.dropwizard.testing.junit5.helper.ThrowingTestExtension;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.platform.testkit.engine.EngineTestKit;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.platform.engine.discovery.DiscoverySelectors.selectClass;

class DropwizardExtensionsSupportAfterAllTest {
    private static EngineTestKit.Builder engine() {
        return EngineTestKit.engine("junit-jupiter")
            .configurationParameter(
                "junit.jupiter.conditions.deactivate",
                "org.junit.jupiter.engine.extension.DisabledCondition");
    }

    @Test
    void doesNotTearDownStaticFieldsThatFailedOrWereRolledBack() {
        StaticBeforeThrows.log.clear();

        engine().selectors(selectClass(StaticBeforeThrows.class)).execute();

        assertThat(StaticBeforeThrows.log).containsExactly("before:A", "before:B", "after:A");
    }

    @Test
    void stillTearsDownStaticFieldsWhenAPerClassInstanceFieldFails() {
        PerClassInstanceBeforeThrows.log.clear();

        engine().selectors(selectClass(PerClassInstanceBeforeThrows.class)).execute();

        assertThat(PerClassInstanceBeforeThrows.log)
            .containsExactly("before:static", "before:instance", "after:static");
    }

    @Test
    void tearsDownInReverseOrderAndCanStartAgain() {
        for (int run = 0; run < 2; run++) {
            AllSucceed.log.clear();

            engine().selectors(selectClass(AllSucceed.class)).execute();

            assertThat(AllSucceed.log)
                .containsExactly("before:static", "before:instance", "test-body", "after:instance", "after:static");
        }
    }

    @Disabled("test-kit fixture: executed indirectly via EngineTestKit")
    @ExtendWith(DropwizardExtensionsSupport.class)
    static class StaticBeforeThrows {
        static final List<String> log = new ArrayList<>();
        static final RecordingTestExtension a = new RecordingTestExtension("A", log);
        static final ThrowingTestExtension b = new ThrowingTestExtension("B", log, true, false);
        static final RecordingTestExtension c = new RecordingTestExtension("C", log);

        @Test
        void test() {
            log.add("test-body");
        }
    }

    @Disabled("test-kit fixture: executed indirectly via EngineTestKit")
    @TestInstance(TestInstance.Lifecycle.PER_CLASS)
    @ExtendWith(DropwizardExtensionsSupport.class)
    static class PerClassInstanceBeforeThrows {
        static final List<String> log = new ArrayList<>();
        static final RecordingTestExtension staticField = new RecordingTestExtension("static", log);
        final ThrowingTestExtension instanceField = new ThrowingTestExtension("instance", log, true, false);

        @Test
        void test() {
            log.add("test-body");
        }
    }

    @Disabled("test-kit fixture: executed indirectly via EngineTestKit")
    @TestInstance(TestInstance.Lifecycle.PER_CLASS)
    @ExtendWith(DropwizardExtensionsSupport.class)
    static class AllSucceed {
        static final List<String> log = new ArrayList<>();
        static final RecordingTestExtension staticField = new RecordingTestExtension("static", log);
        final RecordingTestExtension instanceField = new RecordingTestExtension("instance", log);

        @Test
        void test() {
            log.add("test-body");
        }
    }
}
