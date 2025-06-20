#!/bin/bash
set -e

echo "- Updating system packages..."
sudo apt update -y > /dev/null 2>&1

# -------------------- JAVA --------------------
if ! command -v java &>/dev/null; then
  echo "- Installing Java (JDK 11)..."
  sudo apt install -y openjdk-11-jdk > /dev/null 2>&1
else
  echo "- Java is already installed: $(java -version 2>&1 | head -n 1)"
fi

# -------------------- curl --------------------
if ! command -v curl &>/dev/null; then
  echo "- Installing curl..."
  sudo apt install -y curl > /dev/null 2>&1
fi

# -------------------- NVM + Node.js --------------------
if ! command -v nvm &>/dev/null; then
  echo "- Installing Node Version Manager (nvm)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash > /dev/null 2>&1
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Load NVM into the shell session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
  echo "- Installing Node.js v18 via nvm..."
  nvm install 18 > /dev/null 2>&1
  nvm alias default 18 > /dev/null 2>&1
else
  echo "- Node.js is already installed: $(node -v)"
fi



# -------------------- PostgreSQL --------------------
if ! command -v psql &>/dev/null; then
  echo "- Installing PostgreSQL..."
  sudo apt install -y postgresql-14 postgresql-client-14 postgresql-contrib-14 > /dev/null 2>&1
else
  echo "- PostgreSQL is already installed: $(psql --version | head -n 1)"
fi

# -------------------- pg_hba.conf Update --------------------
echo "- Configuring PostgreSQL to use 'trust' authentication..."
PG_HBA=$(find /etc/postgresql -name "pg_hba.conf" | head -n 1)
sudo sed -i "s/^local\s\+all\s\+postgres\s\+peer/local all postgres trust/" "$PG_HBA"
sudo systemctl restart postgresql > /dev/null 2>&1

# -------------------- Set Postgres Password & Create DB --------------------
echo "🗄️ Creating database 'dds_pm_db'..."
sudo -u postgres psql > /dev/null 2>&1 <<EOF
\password postgres
EOF

# -------------------- Final Report --------------------
echo ""
echo "🎉"
echo "- Installation complete!"
echo "- Versions installed:"
echo "   Java: $(java -version 2>&1 | head -n 1)"
echo "   Node: $(node -v)"
echo "   npm: $(npm -v)"
echo "   psql: $(psql --version | head -n 1)"

echo ""
echo "👉"
echo "- Next steps:"
echo "- Place your OAuth JSON at: install/google-oauth.json"
echo "- Run: source install/setup.sh"
echo "- Start the app with: ./gradlew app:run -t"
