# Everything the harness needs, so that it doesn't depend on what is installed on the host.
FROM eclipse-temurin:17-jdk
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl git jq procps python3 wrk \
    && rm -rf /var/lib/apt/lists/*
