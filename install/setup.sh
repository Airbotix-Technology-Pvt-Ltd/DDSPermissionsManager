#!/bin/bash

# ================================
# ♻️ Source Terminal for Latest Changes
# ================================
echo "- Sourcing ~/.bashrc to load latest environment changes..."
source ~/.bashrc

# ================================
# 📁 Set working directory to install/
# ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# ================================
# 🔐 RSA256 Key Generation (if missing)
# ================================
mkdir -p keys
cd keys

if [ ! -f "keypair.pem" ]; then
  echo "- Generating RSA256 key pair..."
  openssl genrsa -out keypair.pem 2048
fi

if [ ! -f "pkcs8.key" ]; then
  echo "- Converting private key to PKCS#8..."
  openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in keypair.pem -out pkcs8.key
fi

if [ ! -f "publickey.crt" ]; then
  echo "- Extracting public key..."
  openssl rsa -in keypair.pem -pubout -out publickey.crt
fi

cd ..

# ================================
# 🗃️ PostgreSQL Check and DB Setup
# ================================
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dds_db
DB_USER=postgres
DB_PASSWORD="$PGPASSWORD"

echo "- Checking PostgreSQL server at $DB_HOST:$DB_PORT..."
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
  echo "- Error: PostgreSQL server not reachable at $DB_HOST:$DB_PORT"
  return 1
fi

echo "- PostgreSQL is up."

echo "- Checking if database '$DB_NAME' exists..."
if ! psql -h "$DB_HOST" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
  echo "- Database '$DB_NAME' not found. Creating..."
  createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
  echo "- Database '$DB_NAME' created."
else
  echo "- Database '$DB_NAME' already exists."
fi

# ================================
# 🧪 Generate Random JWT Secrets
# ================================
echo "- Generating JWT secrets..."
ACCESS_SECRET=$(openssl rand -base64 32)
REFRESH_SECRET=$(openssl rand -base64 32)
SALT=$(openssl rand -base64 32)

# ================================
# 📦 Load Google OAuth2 Secrets
# ================================
GOOGLE_SECRET_FILE=$(ls "$SCRIPT_DIR"/client_secret_*.json 2>/dev/null | head -n 1)

if [ -n "$GOOGLE_SECRET_FILE" ] && [ -f "$GOOGLE_SECRET_FILE" ]; then
  echo "- Loading Google OAuth client credentials..."
  CLIENT_ID=$(jq -r '.web.client_id' "$GOOGLE_SECRET_FILE")
  CLIENT_SECRET=$(jq -r '.web.client_secret' "$GOOGLE_SECRET_FILE")
else
  echo "- Google client_secret_*.json file not found. Skipping Google OAuth config."
  CLIENT_ID=""
  CLIENT_SECRET=""
fi

# ================================
# ✅ Export and Log All Environment Variables
# ================================
SECRETS_FILE="$SCRIPT_DIR/.env"
echo "- Logging exported environment variables"
> "$SECRETS_FILE"

# Micronaut environments
export MICRONAUT_ENVIRONMENTS=airbotix

# Core Database config
export DPM_JDBC_URL="jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME"
export DPM_JDBC_DRIVER="org.postgresql.Driver"
export DPM_JDBC_USER="$DB_USER"
export DPM_JDBC_PASSWORD="$DB_PASSWORD"
export DPM_AUTO_SCHEMA_GEN="update"
export DPM_DATABASE_DEPENDENCY="org.postgresql:postgresql:42.7.3"

# JWT Tokens & RSA Keys
export MICRONAUT_SECURITY_TOKEN_JWT_SIGNATURES_SECRET_GENERATOR_SECRET="$ACCESS_SECRET"
export MICRONAUT_SECURITY_TOKEN_JWT_GENERATOR_REFRESH_TOKEN_SECRET="$REFRESH_SECRET"
export JWT_PRIVATE_KEY="$SCRIPT_DIR/keys/pkcs8.key"
export JWT_PUBLIC_KEY="$SCRIPT_DIR/keys/publickey.crt"
export JWT_SALT_VALUE="$SALT"

# OAuth redirect URLs
export MICRONAUT_SECURITY_REDIRECT_LOGIN_SUCCESS="http://localhost:8080"
export MICRONAUT_SECURITY_REDIRECT_LOGIN_FAILURE="http://localhost:8080/failed-auth"
export MICRONAUT_SECURITY_REDIRECT_LOGOUT="http://localhost:8080"

# WebSocket Config
export DPM_WEBSOCKETS_BROADCAST_CHANGES="false"

# Permissions Manager Settings
export PERMISSIONS_MANAGER_APPLICATION_CLIENT_CERTIFICATES_TIME_EXPIRY="365"
export PERMISSIONS_MANAGER_APPLICATION_PERMISSIONS_FILE_DOMAIN="0"
export PERMISSIONS_MANAGER_APPLICATION_PASSPHRASE_LENGTH="32"

# Google OAuth (may be empty if file not found)
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_GOOGLE_CLIENT_ID="$CLIENT_ID"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_GOOGLE_CLIENT_SECRET="$CLIENT_SECRET"
export MICRONAUT_SECURITY_OAUTH2_CLIENTS_GOOGLE_OPENID_ISSUER="https://accounts.google.com"

# Log all exports to .env.generated
export -p | grep -E 'MICRONAUT_|DPM_|PERMISSIONS_MANAGER_|JWT_' | sed 's/^declare -x //' >> "$SECRETS_FILE"

echo "- Environment variables exported and logged to $SECRETS_FILE"

cd .. || exit 1
echo ""
echo "👉"
echo "- Next steps:"
echo "- Start the app with: ./gradlew app:run -t"
