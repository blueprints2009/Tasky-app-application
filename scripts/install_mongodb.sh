#!/bin/bash
set -e

echo "Starting MongoDB installation..."

# Update system packages
apt-get update
apt-get install -y gnupg curl wget unzip

# Import MongoDB public GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | \
tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package list
apt-get update

# Install MongoDB
apt-get install -y mongodb-org

# Enable & start MongoDB
systemctl enable mongod
systemctl start mongod

sleep 5

echo "Configuring MongoDB network settings..."

# Backup config
cp /etc/mongod.conf /etc/mongod.conf.bak

# Configure net section to allow outside connections
if grep -q "^net:" /etc/mongod.conf; then
  if grep -q "^[[:space:]]*bindIp:" /etc/mongod.conf; then
    sed -i 's/^[[:space:]]*bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
  else
    sed -i '/^net:/a\  bindIp: 0.0.0.0' /etc/mongod.conf
  fi
else
  cat <<EOF >> /etc/mongod.conf
net:
  port: 27017
  bindIp: 0.0.0.0
EOF
fi

# --- NEW: CREATE ADMIN USER ---
echo "Creating MongoDB admin user..."
# Set variables (defaults if not provided)
ADMIN_USER="${MONGO_ADMIN_USER:-admin}"
ADMIN_PASS="${MONGO_ADMIN_PASSWORD:-$(openssl rand -base64 24)}"

# Use mongosh to create the user
mongosh admin --eval "
db.createUser({
  user: '$ADMIN_USER',
  pwd: '$ADMIN_PASS',
  roles: [ { role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase' ]
})"

# Save credentials to a file for your reference
echo "User: $ADMIN_USER | Pass: $ADMIN_PASS" > /root/mongodb_credentials.txt
chmod 600 /root/mongodb_credentials.txt

# --- NEW: ENABLE AUTHENTICATION ---
echo "Enabling RBAC Authorization..."
if grep -q "^security:" /etc/mongod.conf; then
    sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
else
    cat <<EOF >> /etc/mongod.conf
security:
  authorization: enabled
EOF
fi

# Restart MongoDB to apply security settings
systemctl restart mongod

echo "--------------------------------------------------"
echo "MongoDB Security Enabled!"
echo "Credentials saved to /root/mongodb_credentials.txt"
echo "--------------------------------------------------"