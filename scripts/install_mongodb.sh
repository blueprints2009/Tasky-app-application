#!/bin/bash
set -e

echo "Starting Enhanced MongoDB & Tooling installation..."

# Update system packages
apt-get update
apt-get install -y gnupg curl wget unzip

# 1. Install specific AWS CLI Version (2.22.0 or latest v2 compatible with your string)
# Note: AWS CLI v2 is distributed as a bundled installer
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip

# 2. Install specific kubectl Version (v1.32.1)
echo "Installing kubectl v1.32.1..."
curl -LO "https://dl.k8s.io/release/v1.32.1/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 3. Import MongoDB public GPG key & Add Repository
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | \
tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update
apt-get install -y mongodb-org

# Enable & start MongoDB
systemctl enable mongod
systemctl start mongod

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to initialize..."
sleep 10

# 4. Configure Admin User and Enable Authentication
echo "Configuring MongoDB Admin User..."
# Change these values or use environment variables!
ADMIN_USER="admin"
ADMIN_PASS="password!"

mongosh --eval "
db = db.getSiblingDB('admin');
db.createUser({
  user: '$ADMIN_USER',
  pwd: '$ADMIN_PASS',
  roles: [{ role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase']
});"

# 5. Update mongod.conf for Network and Security
echo "Securing MongoDB configuration..."
cp /etc/mongod.conf /etc/mongod.conf.bak

# Set Bind IP and Enable Auth
cat <<EOF > /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
EOF

# Restart MongoDB to apply changes
systemctl restart mongod

echo "--------------------------------------------------"
echo "Installation completed successfully!"
echo "AWS CLI Version: $(aws --version)"
echo "Kubectl Version: $(kubectl version --client)"
echo "MongoDB Version: $(mongod --version)"
echo "--------------------------------------------------"
echo "Admin user '$ADMIN_USER' created."
echo "Login via: mongosh -u $ADMIN_USER -p --authenticationDatabase admin"