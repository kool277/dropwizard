package io.dropwizard.hibernate.dual;

import com.codahale.metrics.MetricRegistry;
import io.dropwizard.core.setup.Environment;
import io.dropwizard.db.DataSourceFactory;
import io.dropwizard.hibernate.HibernateBundle;
import io.dropwizard.hibernate.SessionFactoryFactory;
import io.dropwizard.hibernate.UnitOfWork;
import io.dropwizard.hibernate.UnitOfWorkAspect;
import io.dropwizard.lifecycle.setup.LifecycleEnvironment;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.context.internal.ManagedSessionContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class DualSessionFactoryUnitOfWorkTest {
    private SessionFactory primary;
    private SessionFactory reader;
    private DualSessionFactory dual;

    @UnitOfWork
    void readWrite() {
    }

    @UnitOfWork(readOnly = true)
    void readOnly() {
    }

    private static UnitOfWork unitOfWork(String method) throws Exception {
        return DualSessionFactoryUnitOfWorkTest.class.getDeclaredMethod(method).getAnnotation(UnitOfWork.class);
    }

    private static SessionFactory newFactory() {
        final HibernateBundle<?> bundle = mock(HibernateBundle.class);
        final Environment environment = mock(Environment.class);
        when(environment.lifecycle()).thenReturn(mock(LifecycleEnvironment.class));
        when(environment.metrics()).thenReturn(new MetricRegistry());
        final DataSourceFactory dataSourceFactory = new DataSourceFactory();
        dataSourceFactory.setUrl("jdbc:h2:mem:dual-" + UUID.randomUUID());
        dataSourceFactory.setUser("sa");
        dataSourceFactory.setDriverClass("org.h2.Driver");
        dataSourceFactory.setValidationQuery("SELECT 1");
        dataSourceFactory.setProperties(Collections.singletonMap("hibernate.dialect", "org.hibernate.dialect.H2Dialect"));
        dataSourceFactory.setInitialSize(1);
        dataSourceFactory.setMinSize(1);
        return new SessionFactoryFactory().build(bundle, environment, dataSourceFactory, Collections.emptyList());
    }

    private UnitOfWorkAspect aspect() {
        return new UnitOfWorkAspect(Map.of(HibernateBundle.DEFAULT_NAME, dual));
    }

    @BeforeEach
    void setUp() {
        primary = newFactory();
        reader = newFactory();
        dual = new DualSessionFactory(primary, reader);
    }

    @AfterEach
    void tearDown() {
        primary.close();
        reader.close();
    }

    @Test
    void unbindsTheSessionWhenTheUnitOfWorkFinishes() throws Exception {
        final UnitOfWorkAspect aspect = aspect();

        aspect.beforeStart(unitOfWork("readWrite"));
        aspect.afterEnd();
        aspect.onFinish();

        assertThat(ManagedSessionContext.hasBind(primary)).isFalse();
    }

    @Test
    void canStartAgainAfterAUnitOfWorkFinishes() throws Exception {
        final UnitOfWorkAspect first = aspect();
        first.beforeStart(unitOfWork("readWrite"));
        final Session firstSession = dual.getCurrentSession();
        first.afterEnd();
        first.onFinish();

        final UnitOfWorkAspect second = aspect();
        second.beforeStart(unitOfWork("readWrite"));
        final Session secondSession = dual.getCurrentSession();

        assertThat(secondSession).isNotSameAs(firstSession);
        assertThat(secondSession.isOpen()).isTrue();

        second.afterEnd();
        second.onFinish();
    }

    @Test
    void nestedUnitOfWorkJoinsTheOuterSession() throws Exception {
        final UnitOfWorkAspect outer = aspect();
        outer.beforeStart(unitOfWork("readWrite"));
        final Session outerSession = dual.getCurrentSession();

        final UnitOfWorkAspect inner = aspect();
        inner.beforeStart(unitOfWork("readWrite"));
        assertThat(dual.getCurrentSession()).isSameAs(outerSession);
        inner.afterEnd();
        inner.onFinish();

        assertThat(dual.getCurrentSession()).isSameAs(outerSession);
        assertThat(outerSession.isOpen()).isTrue();

        outer.afterEnd();
        outer.onFinish();
        assertThat(outerSession.isOpen()).isFalse();
        assertThat(ManagedSessionContext.hasBind(primary)).isFalse();
    }

    @Test
    void restoresTheActiveFactoryAfterANestedReadOnlyUnitOfWork() throws Exception {
        final UnitOfWorkAspect outer = aspect();
        outer.beforeStart(unitOfWork("readWrite"));
        final Session outerSession = dual.getCurrentSession();

        final UnitOfWorkAspect inner = aspect();
        inner.beforeStart(unitOfWork("readOnly"));
        assertThat(dual.current()).isSameAs(reader);
        inner.afterEnd();
        inner.onFinish();

        assertThat(dual.current()).isSameAs(primary);
        assertThat(dual.getCurrentSession()).isSameAs(outerSession);
        assertThat(ManagedSessionContext.hasBind(reader)).isFalse();

        outer.afterEnd();
        outer.onFinish();
    }

    @Test
    void concurrentUnitsOfWorkKeepTheirOwnSessions() throws Exception {
        final ExecutorService executor = Executors.newFixedThreadPool(8);
        try {
            final List<Future<Void>> results = new ArrayList<>();
            for (int thread = 0; thread < 8; thread++) {
                final Callable<Void> task = () -> {
                    for (int i = 0; i < 25; i++) {
                        final UnitOfWorkAspect outer = aspect();
                        outer.beforeStart(unitOfWork("readWrite"));
                        final Session outerSession = dual.getCurrentSession();

                        final UnitOfWorkAspect inner = aspect();
                        inner.beforeStart(unitOfWork("readOnly"));
                        assertThat(dual.getCurrentSession()).isNotSameAs(outerSession);
                        inner.afterEnd();
                        inner.onFinish();

                        assertThat(dual.getCurrentSession()).isSameAs(outerSession);
                        outer.afterEnd();
                        outer.onFinish();
                        assertThat(ManagedSessionContext.hasBind(primary)).isFalse();
                        assertThat(ManagedSessionContext.hasBind(reader)).isFalse();
                    }
                    return null;
                };
                results.add(executor.submit(task));
            }
            for (Future<Void> result : results) {
                result.get(120, TimeUnit.SECONDS);
            }
        } finally {
            executor.shutdownNow();
        }
    }
}
