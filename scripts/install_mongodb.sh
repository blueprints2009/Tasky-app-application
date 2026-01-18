#!/bin/bash
set -e

echo "Starting MongoDB installation..."

# Update system packages
apt-get update
apt-get install -y gnupg curl wget awscli

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

# Restart MongoDB to apply changes
systemctl restart mongod

# Verify MongoDB is listening
echo "MongoDB listening status:"
ss -lntp | grep 27017 || true

echo "MongoDB status:"
systemctl status mongod --no-pager

echo "MongoDB installation completed successfully!"
echo "MongoDB version:"
mongod --version 


#  Configure User Authentication (Admin User)
echo "Configuring MongoDB Admin User..."
# Change these values or use environment variables!
ADMIN_USER="dbAdmin"
ADMIN_PASS="password123"

# In MongoDB 5.0, we use the 'mongo' shell (or 'mongosh' if installed)
# Creating the initial admin user before enabling authorization
mongosh --eval "
db = db.getSiblingDB('admin');
db.createUser({
  user: '$ADMIN_USER',
  pwd: '$ADMIN_PASS',
  roles: [{ role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase']
});"

# Update mongod.conf for Network and Security
echo "Securing MongoDB configuration..."
cp /etc/mongod.conf /etc/mongod.conf.bak

# Set Bind IP to allow connections and Enable Auth
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



# Note: To reach the exact environment string you provided, we install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip

# Install specific kubectl Client Version: v1.32.9
echo "Installing kubectl v1.32.9..."
curl -LO "https://dl.k8s.io/release/v1.32.9/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl