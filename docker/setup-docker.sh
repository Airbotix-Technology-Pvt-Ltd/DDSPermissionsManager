#!/bin/bash

# ================================
# 📁 Set working directory to install/
# ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# ================================
# 🔧 Default Ports & User Override
# ================================
DEFAULT_DDS_PORT=8080
DEFAULT_DB_PORT=5432
DEFAULT_KEYCLOAK_PORT=8180

echo "- Default Ports:"
echo "  DDS_PORT:        $DEFAULT_DDS_PORT"
echo "  DB_PORT:         $DEFAULT_DB_PORT"
echo "  KEYCLOAK_PORT:   $DEFAULT_KEYCLOAK_PORT"

read -p "- Use all default ports above? [Y/n]: " use_defaults

if [[ "$use_defaults" =~ ^[Nn] ]]; then
  read -p "  DDS_PORT:        " input
  DDS_PORT=${input:-$DEFAULT_DDS_PORT}

  read -p "  DB_PORT:         " input
  DB_PORT=${input:-$DEFAULT_DB_PORT}

  read -p "  KEYCLOAK_PORT:   " input
  KEYCLOAK_PORT=${input:-$DEFAULT_KEYCLOAK_PORT}
else
  DDS_PORT=$DEFAULT_DDS_PORT
  DB_PORT=$DEFAULT_DB_PORT
  KEYCLOAK_PORT=$DEFAULT_KEYCLOAK_PORT
fi

# ================================
# 🔐 RSA256 Key Generation & Keystores (if any file is missing)
# ================================
mkdir -p keys
cd keys
FILES=(private.key request.csr certificate.crt keystore.p12 keystore.jks truststore.jks)
ALIAS="airbotix"
PASSWORD="changeit"

# Check if any required file is missing
for f in "${FILES[@]}"; do
  [ ! -f "$f" ] && regenerate=true && break
done

if [ "$regenerate" = true ]; then
  echo "- One or more key files missing. Regenerating all keys and keystores..."

  rm -f "${FILES[@]}"

  # Quiet generation steps
  openssl genrsa -out private.key 2048 > /dev/null 2>&1
  openssl req -new -key private.key -out request.csr -subj "/CN=$ALIAS" > /dev/null 2>&1
  openssl x509 -req -in request.csr -signkey private.key -out certificate.crt -days 365 > /dev/null 2>&1
  openssl pkcs12 -export -in certificate.crt -inkey private.key -out keystore.p12 \
    -name "$ALIAS" -passout pass:$PASSWORD > /dev/null 2>&1

  keytool -importkeystore -srckeystore keystore.p12 -srcstoretype PKCS12 \
    -destkeystore keystore.jks -deststoretype JKS \
    -alias "$ALIAS" -srcstorepass "$PASSWORD" -deststorepass "$PASSWORD" \
    -noprompt > /dev/null 2>&1

  keytool -import -alias "$ALIAS" -file certificate.crt \
    -keystore truststore.jks -storepass "$PASSWORD" -noprompt > /dev/null 2>&1

  echo "- Keystore regeneration complete."
else
  echo "- All certificate/keystore files already exist. Skipping regeneration."
fi

cd ..

# ================================
# 🌐 Auto-detect Host IP Address
# ================================
HOST=$(hostname -I | awk '{print $1}')
if [ -z "$HOST" ]; then
  echo "⚠️ Could not automatically determine host IP address."
  read -p "👉 Please enter your machine's IP address manually (e.g., 192.168.1.128): " HOST
else
  echo "- Detected host IP: $HOST"
fi

# ================================
# 🗃️ PostgreSQL Setup
# ================================
DB_NAME=dds_db
DB_USER=postgres
DB_PASSWORD="$PGPASSWORD"

# ================================
# 🧪 Generate JWT Secrets
# ================================
echo "- Generating JWT secrets..."
ACCESS_SECRET=$(openssl rand -base64 32)
REFRESH_SECRET=$(openssl rand -base64 32)
SALT=$(openssl rand -base64 32)

# ================================
# 📦 Load Google OAuth Client Info
# ================================
SECRET_FILE="$SCRIPT_DIR/auth_client.json"
if [ -f "$SECRET_FILE" ]; then
  echo "- Loading Google OAuth client credentials..."
  CLIENT_ID=$(jq -r '.clientId' "$SECRET_FILE")
  CLIENT_SECRET=$(jq -r '.secret' "$SECRET_FILE")
else
  echo "- Google auth_client.json not found. Skipping Google OAuth config."
  CLIENT_ID=""
  CLIENT_SECRET=""
fi

cd ..

# ================================
# ✅ Export Environment Variables
# ================================
SECRETS_FILE="$SCRIPT_DIR/.env"
echo "- Logging exported environment variables"
> "$SECRETS_FILE"

# Core Environment
export MICRONAUT_ENVIRONMENTS=airbotix

# Core DDS DB
export DPM_JDBC_URL="jdbc:postgresql://$HOST:$DB_PORT/$DB_NAME"
export DPM_JDBC_DRIVER="org.postgresql.Driver"
export DPM_JDBC_USER="$DB_USER"
export DPM_JDBC_PASSWORD="$DB_PASSWORD"
export DPM_AUTO_SCHEMA_GEN="update"
export DPM_DATABASE_DEPENDENCY="org.postgresql:postgresql:42.7.3"

# Keycloak DB
export KC_DB=postgres
export KC_DB_URL="jdbc:postgresql://$HOST:$DB_PORT/keycloak_db"
export KC_DB_USERNAME=postgres
export KC_DB_PASSWORD="$DB_PASSWORD"
export KC_HOSTNAME="$HOST"
export KC_HOSTNAME_STRICT=false
export KC_HOSTNAME_STRICT_HTTPS=false

# JWT & RSA
export MICRONAUT_SECURITY_TOKEN_JWT_SIGNATURES_SECRET_GENERATOR_SECRET="$ACCESS_SECRET"
export MICRONAUT_SECURITY_TOKEN_JWT_GENERATOR_REFRESH_TOKEN_SECRET="$REFRESH_SECRET"
export JWT_PRIVATE_KEY="$SCRIPT_DIR/keys/pkcs8.key"
export JWT_PUBLIC_KEY="$SCRIPT_DIR/keys/certificate.crt"
export JWT_SALT_VALUE="$SALT"

# OAuth URLs (DDS on custom port, Keycloak on custom port)
export MICRONAUT_SECURITY_REDIRECT_LOGIN_SUCCESS="https://$HOST:$DDS_PORT"
export MICRONAUT_SECURITY_REDIRECT_LOGIN_FAILURE="https://$HOST:$DDS_PORT/failed-auth"
export MICRONAUT_SECURITY_REDIRECT_LOGOUT="https://$HOST:$KEYCLOAK_PORT/realms/dds-realm/protocol/openid-connect/logout"

# WebSocket
export DPM_WEBSOCKETS_BROADCAST_CHANGES="false"

# App-specific
export PERMISSIONS_MANAGER_APPLICATION_CLIENT_CERTIFICATES_TIME_EXPIRY="365"
export PERMISSIONS_MANAGER_APPLICATION_PERMISSIONS_FILE_DOMAIN="0"
export PERMISSIONS_MANAGER_APPLICATION_PASSPHRASE_LENGTH="32"

# Keycloak OIDC
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_CLIENT_ID="$CLIENT_ID"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_CLIENT_SECRET="$CLIENT_SECRET"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_OPENID_ISSUER="https://$HOST:$KEYCLOAK_PORT/realms/dds-realm"

# Export Port Values
export DDS_PORT
export DB_PORT
export KEYCLOAK_PORT

# Save all relevant exports to .env
export -p | grep -E 'MICRONAUT_|DPM_|PERMISSIONS_MANAGER_|JWT_|KC_|DDS_PORT|DB_PORT|KEYCLOAK_PORT' | sed 's/^declare -x //' >> "$SECRETS_FILE"

echo "- Environment variables exported and saved to $SECRETS_FILE"

echo ""
echo "👉"
echo "- Next: run the app with: docker compose up"
