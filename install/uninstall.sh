#!/bin/bash
set -e

echo "⚠️  DANGER ZONE ⚠️"
echo "This script will uninstall Java, PostgreSQL, Node.js, npm, and NVM from your system."
echo "It may cause unexpected side effects or data loss. Use with caution."
echo ""
read -p "❗ Are you sure you want to proceed? Type 'yes' to continue: " CONFIRM
echo ""

if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ Uninstall aborted by user."
  exit 1
fi

echo "- Removing Java..."
sudo apt remove --purge -y openjdk-* default-jdk default-jre > /dev/null 2>&1
sudo rm -rf /usr/lib/jvm > /dev/null 2>&1
sudo apt autoremove --purge -y > /dev/null 2>&1

echo "- Removing PostgreSQL..."
sudo systemctl stop postgresql > /dev/null 2>&1 || true
sudo apt remove -y postgresql* postgresql-client* postgresql-14* > /dev/null 2>&1
sudo rm -rf /etc/postgresql /var/lib/postgresql /var/log/postgresql > /dev/null 2>&1
sudo deluser postgres > /dev/null 2>&1 || true
sudo delgroup postgres > /dev/null 2>&1 || true

echo "- Removing Node.js & npm..."
sudo apt remove --purge -y nodejs npm libnode-dev > /dev/null 2>&1
sudo rm -rf /usr/lib/node_modules ~/.npm ~/.node-gyp > /dev/null 2>&1

echo "- Removing NVM..."
rm -rf ~/.nvm > /dev/null 2>&1
sed -i '/nvm/d' ~/.bashrc
sed -i '/NVM_DIR/d' ~/.bashrc
sed -i '/.nvm/d' ~/.bashrc

echo ""
echo "✅ Uninstallation complete."
echo "- Please restart your terminal or run: exec bash"
