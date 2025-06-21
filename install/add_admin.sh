#!/bin/bash

# ================================
# ♻️ Source Terminal for Latest Changes
# ================================
echo "- Sourcing ~/.bashrc to load latest environment changes..."
source ~/.bashrc

# =======================
# ⚠️ Admin User Insertion
# =======================

echo "- This script will insert a new admin user into the PostgreSQL database."
echo "- It may create a database if it doesn't exist."

# === PostgreSQL configuration ===
DB_NAME="dds_db"
DB_USER="postgres"
DB_HOST="localhost"  # Default to localhost, adjust if needed

# === Ask for admin email ===
read -p "- Enter admin email: " ADMIN_EMAIL

if [[ -z "$ADMIN_EMAIL" ]]; then
  echo ""
  echo "❌ Admin email is required. Exiting."
  exit 1
fi

# === Check if database exists ===
echo "- Checking if database '$DB_NAME' exists..."
if ! psql -h "$DB_HOST" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
  echo "- Database '$DB_NAME' not found. Creating..."
  createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" > /dev/null 2>&1
  echo "- Database '$DB_NAME' created."
else
  echo "- Database '$DB_NAME' already exists."
fi

# === Insert admin user ===
echo "- Inserting admin user with email '$ADMIN_EMAIL' into 'permissions_user' table..."
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c \
"INSERT INTO permissions_user (admin, email) VALUES (true, '$ADMIN_EMAIL');" > /dev/null 2>&1

echo ""
if [[ $? -eq 0 ]]; then
    echo "✅ Admin user '$ADMIN_EMAIL' added successfully!"
else
    echo "❌ Failed to insert admin user. Ensure the table exists and credentials are correct."
fi
