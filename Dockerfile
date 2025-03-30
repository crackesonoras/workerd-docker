# Build stage: Download the workerd binary and its dependencies
# This Dockerfile is designed to build a minimal image for running Cloudflare's workerd.
# It uses a multi-stage build to first download the workerd binary and its dependencies, and then create a clean image with only the necessary files.
# The final image is based on Ubuntu 24.04 and includes only the required libraries for HTTPS access.
FROM ubuntu:24.04 AS builder
ARG TARGETARCH
ARG WORKERD_VERSION
WORKDIR /build

# If WORKERD_VERSION is not specified, retrieve the latest version from GitHub.
# If you want a specific version, you can fork this repository and set the WORKERD_VERSION build argument.
RUN if [ -z "$WORKERD_VERSION" ]; then \
    echo "Retrieving the latest version of workerd..."; \
    WORKERD_VERSION=$(curl -sL -I -o /dev/null -w '%{url_effective}' https://github.com/cloudflare/workerd/releases/latest | sed 's#.*/tag/##'); \
    echo "Latest version detected: $WORKERD_VERSION"; \
    else \
    echo "Specified version: $WORKERD_VERSION"; \
    fi && \
    echo "$WORKERD_VERSION" > /version.txt && \
    curl -LO "https://github.com/cloudflare/workerd/releases/download/$(cat /version.txt)/workerd-linux-$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "64").gz" \
    && gunzip workerd*.gz \
    && mv workerd* workerd \
    && chmod +x workerd

# Collect the libraries required by workerd
RUN mkdir lib && \
    ldd workerd | awk '{print $3}' | grep -v '^(' | xargs -I{} cp -v {} lib/

# Final stage: Clean and minimal image
FROM ubuntu:24.04

# Install only the packages indispensable for HTTPS access
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /worker

# Copy the binary and libraries from the build stage
COPY --from=builder /build/workerd /usr/bin/workerd
COPY --from=builder /build/lib /usr/lib/

ENTRYPOINT ["workerd"]
