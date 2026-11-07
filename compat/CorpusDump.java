import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.BeanDescription;
import com.fasterxml.jackson.databind.JsonSerializer;
import com.fasterxml.jackson.databind.SerializationConfig;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.BeanSerializerModifier;
import com.fasterxml.jackson.databind.type.CollectionType;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.MapperFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.dropwizard.client.HttpClientConfiguration;
import io.dropwizard.client.JerseyClientConfiguration;
import io.dropwizard.client.ssl.TlsConfiguration;
import io.dropwizard.configuration.FileConfigurationSourceProvider;
import io.dropwizard.configuration.YamlConfigurationFactory;
import io.dropwizard.core.Configuration;
import io.dropwizard.db.DataSourceFactory;
import io.dropwizard.jackson.DiscoverableSubtypeResolver;
import io.dropwizard.jackson.Jackson;
import io.dropwizard.jetty.GzipHandlerFactory;
import io.dropwizard.validation.BaseValidator;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;

import java.nio.file.Files;
import java.nio.file.Path;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

/**
 * Writes the effective configuration of every given YAML file, and the defaults of every configuration type, as JSON.
 * A later run on another tree can then show whether a key disappeared, changed type or changed default.
 */
public class CorpusDump {
    public static class CorpusConfiguration extends Configuration {
        @JsonProperty
        public DataSourceFactory database;

        @JsonProperty
        public JerseyClientConfiguration httpClient;

        @JsonProperty
        public JerseyClientConfiguration jerseyClient;
    }

    private final Path output;
    private final ObjectMapper reader = Jackson.newObjectMapper()
        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    private final ObjectMapper sortedWriter = Jackson.newObjectMapper()
        .configure(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY, true)
        .configure(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS, true)
        .configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false)
        .enable(SerializationFeature.INDENT_OUTPUT)
        .registerModule(sortedSets());
    private final Validator validator = BaseValidator.newValidator();

    /**
     * Writes sets in a stable order. The iteration order of sets such as those made by {@code Set.of} changes from one JVM
     * run to the next.
     */
    private static SimpleModule sortedSets() {
        final JsonSerializer<Set<?>> sorted = new JsonSerializer<>() {
            @Override
            public void serialize(Set<?> set, JsonGenerator generator, SerializerProvider provider) throws IOException {
                final List<Object> elements = new ArrayList<>(set);
                elements.sort(Comparator.comparing(String::valueOf));
                provider.defaultSerializeValue(elements, generator);
            }
        };
        final SimpleModule module = new SimpleModule("sorted-sets");
        module.setSerializerModifier(new BeanSerializerModifier() {
            @Override
            public JsonSerializer<?> modifyCollectionSerializer(SerializationConfig config, CollectionType type,
                                                               BeanDescription description, JsonSerializer<?> serializer) {
                return Set.class.isAssignableFrom(type.getRawClass()) ? sorted : serializer;
            }
        });
        return module;
    }

    private CorpusDump(Path output) {
        this.output = output;
    }

    public static void main(String[] args) throws Exception {
        final CorpusDump dump = new CorpusDump(Path.of(args[0]));
        for (int i = 1; i < args.length; i++) {
            dump.dumpFile(args[i]);
        }
        dump.dumpDefaults();
    }

    private void dumpFile(String file) throws Exception {
        final String name = "file-" + file.replace('/', '_');
        try {
            final CorpusConfiguration configuration =
                new YamlConfigurationFactory<>(CorpusConfiguration.class, null, reader, "dw")
                    .build(new FileConfigurationSourceProvider(), file);
            write(name, configuration, violations(configuration));
        } catch (Exception e) {
            writeError(name, e);
        }
    }

    private void dumpDefaults() throws Exception {
        final List<Class<?>> types = new ArrayList<>(new DiscoverableSubtypeResolver().getDiscoveredSubtypes());
        types.add(CorpusConfiguration.class);
        types.add(DataSourceFactory.class);
        types.add(GzipHandlerFactory.class);
        types.add(HttpClientConfiguration.class);
        types.add(JerseyClientConfiguration.class);
        types.add(TlsConfiguration.class);
        for (Class<?> type : types) {
            final String name = "default-" + type.getName();
            try {
                final Object instance = type.getConstructor().newInstance();
                write(name, instance, new TreeSet<>());
            } catch (Exception e) {
                writeError(name, e);
            }
        }
    }

    private Set<String> violations(Object configuration) {
        final Set<String> violations = new TreeSet<>();
        for (ConstraintViolation<Object> violation : validator.validate(configuration)) {
            violations.add(violation.getPropertyPath() + " " + violation.getMessage());
        }
        return violations;
    }

    private void write(String name, Object value, Set<String> violations) throws Exception {
        final ObjectNode node = sortedWriter.createObjectNode();
        node.set("value", sortedWriter.valueToTree(value));
        node.set("violations", sortedWriter.valueToTree(violations));
        Files.writeString(output.resolve(name + ".json"), sortedWriter.writeValueAsString(node) + "\n");
    }

    private void writeError(String name, Exception e) throws Exception {
        // The whole message, since what a configuration error tells the operator is part of the behaviour.
        final String[] lines = String.valueOf(e.getMessage()).split("\n");
        final String message = String.join("\n", java.util.Arrays.copyOf(lines, Math.min(lines.length, 40)));
        Files.writeString(output.resolve(name + ".error.txt"), e.getClass().getName() + ": " + message + "\n");
    }
}
