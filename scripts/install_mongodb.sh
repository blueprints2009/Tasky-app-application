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

# Configure net section safely
if grep -q "^net:" /etc/mongod.conf; then
  # Ensure port exists
  grep -q "^[[:space:]]*port:" /etc/mongod.conf || \
    sed -i '/^net:/a\  port: 27017' /etc/mongod.conf

  # Replace or add bindIp
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

# Restart MongoDB to apply network changes first
systemctl restart mongod
sleep 3

# Create admin user (BEFORE enabling authentication)
echo "Creating MongoDB admin user..."
MONGO_ADMIN_USER="${MONGO_ADMIN_USER:-admin}"
MONGO_ADMIN_PASSWORD="${MONGO_ADMIN_PASSWORD:-$(openssl rand -base64 32)}"

mongosh --eval "
db = db.getSiblingDB('admin');
db.createUser({
  user: '${MONGO_ADMIN_USER}',
  pwd: '${MONGO_ADMIN_PASSWORD}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
});
" || echo "Admin user may already exist or error occurred"

# Save credentials to file
cat > /root/mongodb_credentials.txt <<EOF
MongoDB Admin Credentials
========================
Username: ${MONGO_ADMIN_USER}
Password: ${MONGO_ADMIN_PASSWORD}

Connection String:
mongodb://${MONGO_ADMIN_USER}:${MONGO_ADMIN_PASSWORD}@localhost:27017/admin

Connection Command:
mongosh "mongodb://${MONGO_ADMIN_USER}:${MONGO_ADMIN_PASSWORD}@localhost:27017/admin"

IMPORTANT: Load your data NOW before authentication is enabled!
After this script completes, authentication will be required.
EOF

chmod 600 /root/mongodb_credentials.txt

echo "MongoDB credentials saved to /root/mongodb_credentials.txt"
echo ""
echo "============================================"
echo "IMPORTANT: LOAD YOUR DATA NOW!"
echo "============================================"
echo "Authentication will be enabled in 60 seconds."
echo "Use this time to load your database."
echo ""
echo "Example commands:"
echo "  mongorestore --db mydb /path/to/dump/mydb"
echo "  mongoimport --db mydb --collection mycoll --file data.json"
echo ""
echo "Press Ctrl+C to cancel and load data manually."
echo "============================================"
cat /root/mongodb_credentials.txt
echo ""

# Give 60 seconds to load data
for i in {60..1}; do
  echo -ne "Enabling authentication in $i seconds...\r"
  sleep 1
done
echo ""

# Enable authentication
echo "Enabling MongoDB authentication..."

# Check if security section exists, if not add it
if ! grep -q "^security:" /etc/mongod.conf; then
  cat <<EOF >> /etc/mongod.conf

security:
  authorization: enabled
EOF
else
  # Add authorization if not present
  if ! grep -q "authorization:" /etc/mongod.conf; then
    sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
  else
    sed -i 's/^[[:space:]]*authorization:.*/  authorization: enabled/' /etc/mongod.conf
  fi
fi

# Restart MongoDB with authentication enabled
systemctl restart mongod
sleep 3

# Verify MongoDB is listening
echo "MongoDB listening status:"
ss -lntp | grep 27017 || true

echo "MongoDB status:"
systemctl status mongod --no-pager

echo "MongoDB installation and authentication completed successfully!"
echo "MongoDB version:"
mongod --version

# Install AWS CLI v2.33.0
echo ""
echo "Installing AWS CLI v2.33.0..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.33.0.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update

# Verify AWS CLI installation
echo "AWS CLI version:"
aws --version

# Install kubectl v1.32.9
echo ""
echo "Installing kubectl v1.32.9..."
curl -LO "https://dl.k8s.io/release/v1.32.9/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Verify kubectl installation
echo "kubectl version:"
kubectl version --client

# Cleanup
rm -rf /tmp/awscliv2.zip /tmp/aws

echo ""
echo "============================================"
echo "Installation Summary:"
echo "============================================"
echo "✓ MongoDB 7.0 with authentication enabled"
echo "✓ AWS CLI v2.33.0"
echo "✓ kubectl v1.32.9 (with Kustomize v5.5.0)"
echo ""
echo "MongoDB credentials are stored in: /root/mongodb_credentials.txt"
echo "============================================" 