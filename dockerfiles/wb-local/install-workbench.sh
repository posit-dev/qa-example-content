#!/bin/bash

# Initialize error tracking
ERRORS=()

# Function to log errors
log_error() {
    ERRORS+=("$1")
    echo "❌ ERROR: $1"
}

# Parse command line arguments
CI_MODE=false
while [ $# -gt 0 ]; do
  case $1 in
    --ci)
      CI_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Interactive installation prompt (skip in CI mode)
if [ "$CI_MODE" = true ]; then
    echo ""
    echo "CI Mode: Installing latest versions..."
    echo "======================================"
elif [ -z "${WB_URL}" ] && [ -z "${POSITRON_TAG}" ]; then
    echo ""
    echo "Workbench + Positron Installation"
    echo "---------------------------------"
    echo "1) Latest versions     [recommended]"
    echo "2) Specific versions"
    echo "3) Skip to shell"
    echo ""
    read -p "Enter your choice [1-3, default = 1]: " choice
    
    case ${choice:-1} in
        1)
            echo "Installing latest versions..."
            ;;
        2)
            echo ""
            echo "Enter specific versions (or press Enter for defaults):"
            read -p "Workbench URL [press Enter for latest]: " user_wb_url
            read -p "Positron tag (e.g., 2025.10.0-88) [press Enter for latest]: " user_positron_tag
            
            if [ -n "$user_wb_url" ]; then
                export WB_URL="$user_wb_url"
            fi
            if [ -n "$user_positron_tag" ]; then
                export POSITRON_TAG="$user_positron_tag"
            fi
            ;;
        3)
            echo "Skipping installation. Going to shell..."
            exec /bin/bash
            ;;
        *)
            echo "Invalid choice. Using latest versions..."
            ;;
    esac
    echo ""
fi

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

ensure_connect_token() {
  local token_dir="/tokens"
  local token_file="${token_dir}/connect_bootstrap_token"
  local tmp_file="${token_dir}/.tmp_token"
  local connect_url="${CONNECT_URL:-http://connect:3939}"

  # Reuse if already present
  if [ -s "$token_file" ]; then
    echo "Bootstrap token already present at $token_file"
    export CONNECT_TOKEN="$(cat "$token_file")"
    return 0
  fi

  echo "Waiting for Posit Connect at ${connect_url}..."
  local ok=0
  for i in {1..60}; do
    if curl -fsS "${connect_url}/__ping__" >/dev/null 2>&1 || curl -fsS "${connect_url}" >/dev/null 2>&1; then
      ok=1; break
    fi
    sleep 1
  done
  if [ "$ok" -ne 1 ]; then
    log_error "Connect not reachable at ${connect_url} after 60s"
    return 1
  fi

  echo "Bootstrapping token with rsconnect..."
  umask 077
  mkdir -p "$token_dir"

  # Correct command (no --secret)
  if ! rsconnect bootstrap --server "${connect_url}" --raw > "$tmp_file"; then
    log_error "rsconnect bootstrap failed"
    # optional: print tool version for debugging
    rsconnect --version || true
    return 1
  fi

  # sanity-check non-empty
  if ! [ -s "$tmp_file" ]; then
    log_error "rsconnect returned empty token"
    return 1
  fi

  mv "$tmp_file" "$token_file"
  echo "Wrote bootstrap token to $token_file"
  export CONNECT_TOKEN="$(cat "$token_file")"
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
WB_PASSWORD=${WB_PASSWORD:-"testpassword"}

# Install required packages early so we have jq for URL fetching
echo "Installing required packages..."
if ! sudo apt-get update; then
    log_error "Failed to update package lists"
fi
if ! sudo add-apt-repository -y universe; then
    log_error "Failed to add universe repository"
fi
if ! sudo apt-get update; then
    log_error "Failed to update package lists after adding universe"
fi
if ! sudo apt-get install -y acl jq curl; then
    log_error "Failed to install required packages (acl, jq, curl)"
fi

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
echo "  WB_PASSWORD: [HIDDEN]"

# Create the user
echo "Creating user ${Q_USER}..."
sudo groupadd -g ${Q_GID} ${Q_GROUP}
sudo useradd --create-home --shell /bin/bash --home-dir /home/${Q_USER} -u ${Q_UID} -g ${Q_GROUP} ${Q_USER}
echo "${Q_USER}":"${WB_PASSWORD}" | sudo chpasswd

echo "Configuring ~/.Renviron for ${Q_USER}..."
sudo mkdir -p "/home/${Q_USER}"
sudo tee "/home/${Q_USER}/.Renviron" >/dev/null <<EOF
R_LIBS_SITE=/usr/local/lib/R/site-library
R_LIBS_USER=/usr/local/lib/R/site-library
EOF
sudo chown "${Q_USER}:${Q_GROUP}" "/home/${Q_USER}/.Renviron"

# Configure RStudio
echo "Configuring RStudio..."
sudo mkdir -p /etc/rstudio
echo "unprivileged=1" | sudo tee /etc/rstudio/launcher.local.conf > /dev/null

# Download Workbench
echo "Downloading Workbench..."
if ! curl ${WB_URL} --output workbench.deb; then
    log_error "Failed to download Workbench from ${WB_URL}"
fi

# Install Workbench
echo "Installing Workbench..."
if ! sudo apt install -y ./workbench.deb; then
    log_error "Failed to install Workbench package"
fi

# Set access permissions
echo "Setting access permissions..."
sudo setfacl -m u:${Q_USER}:x /root
sudo setfacl -R -m u:${Q_USER}:rx /root/.venv /root/.pyenv
sudo setfacl -R -m d:u:${Q_USER}:rx /root/.venv /root/.pyenv

# Update positron-server
echo "Updating positron-server..."
if ! sudo rstudio-server stop; then
    log_error "Failed to stop RStudio server"
fi

cd /usr/lib/rstudio-server/bin/

# Clean up any existing backup and move current version
if [ -d "positron-server-old" ]; then
    echo "Removing existing positron-server-old backup..."
    sudo rm -rf positron-server-old
fi

if ! sudo mv positron-server positron-server-old; then
    log_error "Failed to backup existing positron-server"
fi

if ! sudo mkdir -p positron-server; then
    log_error "Failed to create new positron-server directory"
fi

cd positron-server

# Run download script
if [ -n "${POSITRON_TAG}" ]; then
    echo "Running download script with TAG=${POSITRON_TAG}, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=***..."
else
    echo "Running download script with latest Positron release, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=***..."
fi
if ! TAG=${POSITRON_TAG} ARCH_SUFFIX=${ARCH_SUFFIX} GITHUB_TOKEN=${GITHUB_TOKEN} /tmp/positronDownload.sh; then
    log_error "Failed to download/install Positron"
fi

# Start RStudio server
echo "Starting RStudio server..."
if ! sudo rstudio-server start; then
    log_error "Failed to start RStudio server"
fi

# Ensure (fetch once) + export CONNECT_TOKEN for subsequent steps/tests
ensure_connect_token || true

# Log completion and versions
echo ""
echo "Installation complete 🎉"

# Extract Workbench version - just get the first word from "2025.11.0-daily+151.pro2 Workbench..."
WB_VERSION=$(sudo rstudio-server version 2>/dev/null | head -1 | awk '{print $1}')

# Extract Positron version and build number, combine them
POSITRON_VERSION=$(cd /usr/lib/rstudio-server/bin/positron-server && grep '"positronVersion"' product.json 2>/dev/null | sed 's/.*"positronVersion": *"\([^"]*\)".*/\1/' || echo "Unknown")
POSITRON_BUILD=$(cd /usr/lib/rstudio-server/bin/positron-server && grep '"positronBuildNumber"' product.json 2>/dev/null | sed 's/.*"positronBuildNumber": *"\([^"]*\)".*/\1/' || echo "")
POSITRON_FULL_VERSION="${POSITRON_VERSION}-${POSITRON_BUILD}"

echo "Positron version:    ${POSITRON_FULL_VERSION}"
echo "Workbench version:   ${WB_VERSION}"
echo "Workbench URL:       http://localhost:8787"

# Report any errors that occurred
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  WARNING: ${#ERRORS[@]} error(s) occurred during installation:"
    for error in "${ERRORS[@]}"; do
        echo "   • $error"
    done
    echo ""
    echo "Installation may not be fully functional. Check logs above for details."
fi
echo ""
