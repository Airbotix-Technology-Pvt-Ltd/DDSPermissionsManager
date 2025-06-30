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
DEFAULT_KEYCLOAK_PORT=8180

# Display default ports
echo "- Default Ports:"
echo "  DDS_PORT:        $DEFAULT_DDS_PORT"
echo "  KEYCLOAK_PORT:   $DEFAULT_KEYCLOAK_PORT"

# Ask user to accept or override default ports
read -p "- Use all default ports above? [Y/n]: " use_defaults

if [[ "$use_defaults" =~ ^[Nn] ]]; then
  # Prompt for custom port inputs (defaults provided on Enter)
  read -p "  DDS_PORT:        " input
  DDS_PORT=${input:-$DEFAULT_DDS_PORT}

  read -p "  KEYCLOAK_PORT:   " input
  KEYCLOAK_PORT=${input:-$DEFAULT_KEYCLOAK_PORT}
else
  DDS_PORT=$DEFAULT_DDS_PORT
  KEYCLOAK_PORT=$DEFAULT_KEYCLOAK_PORT
fi

# ================================
# 🌐 Auto-detect Host IP Address
# ================================
HOST=$(hostname -I | awk '{print $1}')
if [ -z "$HOST" ]; then
  # Manual fallback if auto-detection fails
  echo "⚠️ Could not automatically determine host IP address."
  read -p "👉 Please enter your machine's IP address manually (e.g., 192.168.1.128): " HOST
else
  echo "- Detected host IP: $HOST"
fi

# ================================
# 🔐 RSA256 Key Generation & Keystores (if any file is missing)
# ================================
mkdir -p keys
cd keys
FILES=(private.key request.csr certificate.crt keystore.p12 keystore.jks publickey.crt pkcs8.key)
ALIAS="airbotix"
PASSWORD="changeit"
IP_ADDRESS=$HOST
CONFIG="openssl-san.cnf"

# Create OpenSSL config with SAN entries for IP and DNS
cat > "$CONFIG" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $ALIAS

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $IP_ADDRESS
DNS.1 = $ALIAS.local
EOF

# Check if any key or cert file is missing
for f in "${FILES[@]}"; do
  [ ! -f "$f" ] && regenerate=true && break
done

if [ "$regenerate" = true ]; then
  echo "- One or more key files missing. Regenerating all keys and keystores..."

  # Cleanup old files if exist
  rm -f "${FILES[@]}"

  # Generate RSA private key and related files
  openssl genrsa -out private.key 2048 > /dev/null 2>&1
  openssl pkcs8 -topk8 -inform PEM -in private.key -out pkcs8.key -nocrypt > /dev/null 2>&1
  openssl req -new -key private.key -out request.csr -config "$CONFIG" > /dev/null 2>&1
  openssl x509 -req -in request.csr -signkey private.key -out certificate.crt -days 365 -extensions v3_req -extfile "$CONFIG" > /dev/null 2>&1
  openssl x509 -pubkey -noout -in certificate.crt > publickey.crt

  # Create PKCS12 keystore and convert to JKS
  openssl pkcs12 -export -in certificate.crt -inkey private.key -out keystore.p12 \
    -name "$ALIAS" -passout pass:$PASSWORD > /dev/null 2>&1

  keytool -importkeystore -srckeystore keystore.p12 -srcstoretype PKCS12 \
    -destkeystore keystore.jks -deststoretype JKS \
    -alias "$ALIAS" -srcstorepass "$PASSWORD" -deststorepass "$PASSWORD" \
    -noprompt > /dev/null 2>&1

  echo "- Keystore regeneration complete."
else
  echo "- All certificate/keystore files already exist. Skipping regeneration."
fi

cd ..

# ================================
# 🗃️ PostgreSQL Setup
# ================================
# Check if PGPASSWORD exists in current shell or ~/.bashrc
if [ -z "$PGPASSWORD" ]; then
  if ! grep -q '^export PGPASSWORD=' ~/.bashrc; then
    # Prompt user if not found anywhere
    read -s -p "- Enter PGPASSWORD: " pass; echo
    export PGPASSWORD="$pass"
    echo "export PGPASSWORD=\"$pass\"" >> ~/.bashrc
  else
    source ~/.bashrc
  fi
fi
DB_NAME=dds_db
KC_DB_NAME=keycloak_db
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

# Micronaut Profile
export MICRONAUT_ENVIRONMENTS=airbotix

# Core DDS PostgreSQL Settings
export DPM_JDBC_URL="jdbc:postgresql://$DB_USER/$DB_NAME"
export DPM_JDBC_DRIVER="org.postgresql.Driver"
export DPM_JDBC_USER="$DB_USER"
export DPM_JDBC_PASSWORD="$DB_PASSWORD"
export DPM_AUTO_SCHEMA_GEN="update"
export DPM_DATABASE_DEPENDENCY="org.postgresql:postgresql:42.7.3"

# Keycloak DB Configuration
export KC_DB=postgres
export KC_DB_URL="jdbc:postgresql://$DB_USER/$KC_DB_NAME"
export KC_DB_USERNAME=postgres
export KC_DB_PASSWORD="$DB_PASSWORD"
export KC_HOSTNAME="$HOST"
export KC_HOSTNAME_STRICT=false
export KC_HOSTNAME_STRICT_HTTPS=false

# JWT Keys & Secrets
export MICRONAUT_SECURITY_TOKEN_JWT_SIGNATURES_SECRET_GENERATOR_SECRET="$ACCESS_SECRET"
export MICRONAUT_SECURITY_TOKEN_JWT_GENERATOR_REFRESH_TOKEN_SECRET="$REFRESH_SECRET"
export JWT_PRIVATE_KEY="$SCRIPT_DIR/keys/pkcs8.key"
export JWT_PUBLIC_KEY="$SCRIPT_DIR/keys/certificate.crt"
export JWT_SALT_VALUE="$SALT"

# OAuth Redirects
export MICRONAUT_SECURITY_REDIRECT_LOGIN_SUCCESS="https://$HOST:$DDS_PORT"
export MICRONAUT_SECURITY_REDIRECT_LOGIN_FAILURE="https://$HOST:$DDS_PORT/failed-auth"
export MICRONAUT_SECURITY_REDIRECT_LOGOUT="https://$HOST:$KEYCLOAK_PORT/realms/dds-realm/protocol/openid-connect/logout"

# WebSocket Configuration
export DPM_WEBSOCKETS_BROADCAST_CHANGES="false"

# Application-specific Values
export PERMISSIONS_MANAGER_APPLICATION_CLIENT_CERTIFICATES_TIME_EXPIRY="365"
export PERMISSIONS_MANAGER_APPLICATION_PERMISSIONS_FILE_DOMAIN="0"
export PERMISSIONS_MANAGER_APPLICATION_PASSPHRASE_LENGTH="32"

# OAuth (Google or other OIDC provider)
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_CLIENT_ID="$CLIENT_ID"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_CLIENT_SECRET="$CLIENT_SECRET"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_KEYCLOAK_OPENID_ISSUER="https://$HOST:$KEYCLOAK_PORT/realms/dds-realm"

# Export selected Ports
export DDS_PORT
export KEYCLOAK_PORT

# Save all exported vars to .env file for Docker or app consumption
export -p | grep -E 'MICRONAUT_|DPM_|PERMISSIONS_MANAGER_|JWT_|KC_|DDS_PORT|KEYCLOAK_PORT' | sed 's/^declare -x //' >> "$SECRETS_FILE"

echo "- Environment variables exported and saved to $SECRETS_FILE"

echo ""
echo "👉"
echo "- Next: run the app with: docker compose up"
