package io.dropwizard.util;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class DataSizeOverflowTest {
    @Test
    void convertsWhenTheResultFitsButTheBitCountDoesNot() {
        assertThat(DataSize.pebibytes(1024).toBytes()).isEqualTo(1L << 60);
        assertThat(DataSize.bytes(Long.MAX_VALUE).toBytes()).isEqualTo(Long.MAX_VALUE);
        assertThat(DataSizeUnit.KIBIBYTES.convert(1L << 60, DataSizeUnit.BYTES)).isEqualTo(1L << 50);
    }

    @Test
    void saturatesWhenTheResultDoesNotFit() {
        assertThat(DataSize.pebibytes(Long.MAX_VALUE).toBytes()).isEqualTo(Long.MAX_VALUE);
        assertThat(DataSizeUnit.BYTES.convert(Long.MIN_VALUE, DataSizeUnit.PEBIBYTES)).isEqualTo(Long.MIN_VALUE);
        assertThat(DataSize.gibibytes(2147483648L).toBytes()).isEqualTo(1L << 61);
    }

    @Test
    void comparesLargeSizesCorrectly() {
        assertThat(DataSize.bytes(1L << 60)).isGreaterThan(DataSize.kilobytes(1));
    }
}
