#!/bin/bash

# Function to fetch the latest Workbench URL based on architecture
fetch_latest_wb_url() {
    local arch=$1
    local json_url="https://dailies.rstudio.com/rstudio/apple-blossom/index.json"
    
    # Map architecture to the correct key in the json
    local platform_key
    if [ "$arch" = "arm64" ]; then
        platform_key="noble-arm64"
    else
        platform_key="noble-amd64"
    fi
    
    # Fetch the json and extract the URL
    local url
    url=$(curl -s "$json_url" | jq -r ".workbench.platforms[\"$platform_key\"].link")
    
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "Failed to fetch the latest Workbench URL for $arch architecture" >&2
        return 1
    fi
    
    echo "$url"
}

# Initial parameter setup
ARCH_SUFFIX=${ARCH_SUFFIX:-"arm64"}
POSITRON_TAG=${POSITRON_TAG:-""}  # Empty default will get the latest release
GITHUB_TOKEN=${GITHUB_TOKEN:-"myToken"}

# User configuration with defaults that can be overridden by environment variables
Q_USER=${Q_USER:-"user1"}
Q_UID=${Q_UID:-1100}
Q_GID=${Q_GID:-1100}
Q_GROUP=${Q_GROUP:-"user1g"}
Q_PASSWORD=${Q_PASSWORD:-"testpassword"}

# Install required packages early so we have jq for URL fetching
echo "Installing required packages..."
sudo apt-get update
sudo add-apt-repository -y universe
sudo apt-get update
sudo apt-get install -y acl jq curl

# Now we can fetch the WB_URL if it wasn't provided
if [ -z "${WB_URL}" ]; then
    echo "No WB_URL provided, fetching latest Workbench URL for ${ARCH_SUFFIX} architecture..."
    WB_URL=$(fetch_latest_wb_url "${ARCH_SUFFIX}")
    if [ $? -ne 0 ]; then
        echo "Failed to fetch Workbench URL. Using fallback URL."
        WB_URL="https://s3.amazonaws.com/rstudio-ide-build/server/jammy/${ARCH_SUFFIX}/rstudio-workbench-2025.11.0-daily-131.pro5-${ARCH_SUFFIX}.deb"
    fi
    echo "Using Workbench URL: ${WB_URL}"
else
    echo "Using provided Workbench URL: ${WB_URL}"
fi

# Log the configuration being used (but don't show the password)
echo "Using configuration:"
echo "  WB_URL: ${WB_URL}"
if [ -n "${POSITRON_TAG}" ]; then
    echo "  POSITRON_TAG: ${POSITRON_TAG}"
else
    echo "  POSITRON_TAG: [LATEST]"
fi
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
if [ -n "${POSITRON_TAG}" ]; then
    echo "Running download script with TAG=${POSITRON_TAG}, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=${GITHUB_TOKEN}..."
else
    echo "Running download script with latest Positron release, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=${GITHUB_TOKEN}..."
fi
TAG=${POSITRON_TAG} ARCH_SUFFIX=${ARCH_SUFFIX} GITHUB_TOKEN=${GITHUB_TOKEN} /tmp/positronDownload.sh

# Start RStudio server
echo "Starting RStudio server..."
sudo rstudio-server start

echo "Installation complete."
