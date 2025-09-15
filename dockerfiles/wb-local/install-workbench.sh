#!/bin/bash

# Script parameters with defaults that can be overridden by environment variables
WB_URL=${WB_URL:-"https://s3.amazonaws.com/rstudio-ide-build/server/jammy/arm64/rstudio-server-2025.11.0-daily-135-arm64.deb"}
POSITRON_TAG=${POSITRON_TAG:-"2025.10.0-88"}
GITHUB_TOKEN=${GITHUB_TOKEN:-"myToken"}
ARCH_SUFFIX=${ARCH_SUFFIX:-"arm64"}

# User configuration with defaults that can be overridden by environment variables
Q_USER=${Q_USER:-"user1"}
Q_UID=${Q_UID:-1100}
Q_GID=${Q_GID:-1100}
Q_GROUP=${Q_GROUP:-"user1g"}
Q_PASSWORD=${Q_PASSWORD:-"testpassword"}

# Log the configuration being used (but don't show the password)
echo "Using configuration:"
echo "  WB_URL: ${WB_URL}"
echo "  POSITRON_TAG: ${POSITRON_TAG}"
echo "  ARCH_SUFFIX: ${ARCH_SUFFIX}"
echo "  Q_USER: ${Q_USER}"
echo "  Q_UID: ${Q_UID}"
echo "  Q_GID: ${Q_GID}"
echo "  Q_GROUP: ${Q_GROUP}"
echo "  Q_PASSWORD: [HIDDEN]"

# Create the user
echo "Creating user ${Q_USER}..."
sudo groupadd -g ${Q_GID} ${Q_GROUP}
sudo useradd --create-home --shell /bin/bash --home-dir /home/${Q_USER} -u ${Q_UID} -g ${Q_GROUP} ${Q_USER}
echo "${Q_USER}":"${Q_PASSWORD}" | sudo chpasswd

# Install required packages
echo "Installing required packages..."
sudo apt-get update
sudo add-apt-repository -y universe
sudo apt-get update
sudo apt-get install -y acl jq

# Configure RStudio
echo "Configuring RStudio..."
sudo mkdir -p /etc/rstudio
echo "unprivileged=1" | sudo tee /etc/rstudio/launcher.local.conf > /dev/null

# Download Workbench
echo "Downloading Workbench..."
curl ${WB_URL} --output workbench.deb

# Install Workbench
echo "Installing Workbench..."
sudo apt install -y ./workbench.deb

# Set access permissions
echo "Setting access permissions..."
sudo setfacl -m u:${Q_USER}:x /root
sudo setfacl -R -m u:${Q_USER}:rx /root/.venv /root/.pyenv
sudo setfacl -R -m d:u:${Q_USER}:rx /root/.venv /root/.pyenv

# Update positron-server
echo "Updating positron-server..."
sudo rstudio-server stop
cd /usr/lib/rstudio-server/bin/
sudo mv positron-server positron-server-old
sudo mkdir -p positron-server
cd positron-server

# Run download script
echo "Running download script with TAG=${POSITRON_TAG}, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=${GITHUB_TOKEN}..."
TAG=${POSITRON_TAG} ARCH_SUFFIX=${ARCH_SUFFIX} GITHUB_TOKEN=${GITHUB_TOKEN} /tmp/download.sh

# Start RStudio server
echo "Starting RStudio server..."
sudo rstudio-server start

echo "Installation complete."
