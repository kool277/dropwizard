package io.dropwizard.health;

import com.codahale.metrics.MetricRegistry;
import io.dropwizard.util.Duration;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

class HealthCheckManagerListenerTest {
    private static final String NAME = "test";

    private final HealthStateListener listener = mock(HealthStateListener.class);

    private HealthCheckManager managerWithConfiguredCheck() {
        final HealthCheckConfiguration config = new HealthCheckConfiguration();
        config.setName(NAME);
        config.setCritical(true);
        config.setSchedule(new Schedule());
        final HealthCheckManager manager = new HealthCheckManager(List.of(config), mock(HealthCheckScheduler.class),
            new MetricRegistry(), Duration.seconds(5), true, List.of(listener));
        manager.onHealthCheckAdded(NAME, mock(com.codahale.metrics.health.HealthCheck.class));
        return manager;
    }

    @Test
    void notifiesListenerOncePerStateChange() {
        managerWithConfiguredCheck().onStateChanged(NAME, false);

        verify(listener, times(1)).onStateChanged(NAME, false);
    }

    @Test
    void listenerExceptionDoesNotEscape() {
        doThrow(new IllegalStateException("boom")).when(listener).onStateChanged(NAME, false);
        final HealthCheckManager manager = managerWithConfiguredCheck();

        assertThatCode(() -> manager.onStateChanged(NAME, false)).doesNotThrowAnyException();
    }
}
