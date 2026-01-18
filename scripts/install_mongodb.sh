#!/bin/bash

# Exit immediately if a command exits with a non-zero status
# set -e

# Import the MongoDB GPG Key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 6A26B1AE64C3C388


# Add the MongoDB Repository
echo "deb [ arch=amd64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

# Update Package Lists
sudo apt-get update

# Install MongoDB
sudo apt-get install -y --allow-unauthenticated mongodb-org

# Start MongoDB
sudo systemctl start mongod

# Enable MongoDB to start on boot
sudo systemctl enable mongod

# Verify the Installation
mongod --version

sleep 5
#!/bin/bash

# Define the MongoDB config file path
MONGO_CONF="/etc/mongod.conf"

# Check if the 'authorization' line already exists
grep -q "#security:" $MONGO_CONF
if [ $? -eq 0 ]; then
    # If 'security:' exists, update or add 'authorization: enabled'
    sudo sed -i '/security:/a\  authorization: enabled' $MONGO_CONF
fi
sudo sed -i 's/^#security:/security:/' $MONGO_CONF
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' $MONGO_CONF

# Restart MongoDB to apply changes
sudo systemctl restart mongod

# Confirm MongoDB status
sudo systemctl status mongod --no-pager

sleep 10
# Step 2: Create Admin User
echo "Creating MongoDB admin user..."
mongo <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "admin",
  roles: [{ role: "root", db: "admin" }]
})
exit
EOF
sleep 5
# Step 3: Restart MongoDB Again to Ensure Authentication Takes Effect
echo "Restarting MongoDB..."
sudo systemctl restart mongod
echo "MongoDB setup complete."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo snap install kubectl --classic
sudo snap install helm --classic
sudo snap install docker

# Update package list
sudo apt update

# Install required dependencies
sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

# Download latest Python source (current stable is 3.12.2)
cd /tmp
wget https://www.python.org/ftp/python/3.12.2/Python-3.12.2.tgz

# Extract the archive
tar -xf Python-3.12.2.tgz

# Enter directory
cd Python-3.12.2

# Configure and optimize
./configure --enable-optimizations

# Build and install
sudo make -j $(nproc)
sudo make altinstall

# Verify installation
python3.12 --version
