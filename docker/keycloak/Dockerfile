FROM quay.io/keycloak/keycloak:latest AS builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak

RUN keytool -genkeypair \
    -storepass password \
    -storetype PKCS12 \
    -keyalg RSA \
    -keysize 2048 \
    -dname "CN=server" \
    -alias server \
    -ext "SAN:c=DNS:192.168.1.128,IP:192.168.1.128" \
    -keystore conf/server.keystore

# Build optimized server with DB config
RUN /opt/keycloak/bin/kc.sh build

# ---------------------------------------

FROM quay.io/keycloak/keycloak:latest

# Copy optimized Keycloak install
COPY --from=builder /opt/keycloak/ /opt/keycloak/
