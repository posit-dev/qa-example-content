#!/bin/bash
set -euo pipefail

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

# Initial parameter setup - auto-detect architecture if not set
if [ -z "${ARCH_SUFFIX:-}" ]; then
  case "$(uname -m)" in
    aarch64|arm64) ARCH_SUFFIX="arm64" ;;
    x86_64|amd64)  ARCH_SUFFIX="amd64" ;;
    *)             ARCH_SUFFIX="arm64" ;;
  esac
fi

POSITRON_TAG=${POSITRON_TAG:-""}  # Empty default will get the latest release
GITHUB_TOKEN=${GITHUB_TOKEN:-"myToken"}

# User configuration with defaults that can be overridden by environment variables
Q_USER=${Q_USER:-"jupyter-user"}
Q_UID=${Q_UID:-1100}
Q_GID=${Q_GID:-1100}
Q_GROUP=${Q_GROUP:-"jupyter-group"}
JUPYTER_PASSWORD=${JUPYTER_PASSWORD:-"testpassword"}

# License file location (can be from CI secret or local file)
LICENSE_FILE=${LICENSE_FILE:-"/opt/positron.lic"}

echo "Jupyter + Positron Installation"
echo "================================"
echo ""

# Log the configuration being used
echo "Using configuration:"
if [ -n "${POSITRON_TAG}" ]; then
    echo "  POSITRON_TAG: ${POSITRON_TAG}"
else
    echo "  POSITRON_TAG: [LATEST]"
fi
echo "  ARCH_SUFFIX: ${ARCH_SUFFIX}"
echo "  Q_USER: ${Q_USER}"
echo "  LICENSE_FILE: ${LICENSE_FILE}"
echo ""

# Install required packages
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
if ! sudo apt-get install -y jq curl wget python3-pip python3-venv; then
    log_error "Failed to install required packages (jq, curl, wget, python3-pip, python3-venv)"
fi

# Install TLJH (The Littlest JupyterHub)
echo "Installing The Littlest JupyterHub..."
if ! curl -L https://tljh.jupyter.org/bootstrap.py | sudo -E python3 - --admin admin; then
    log_error "Failed to install TLJH"
fi

# TLJH uses PAM authenticator by default, no need to configure it explicitly

# Set password for admin user (system level)
echo "Setting password for admin user..."
if ! id -u admin > /dev/null 2>&1; then
    # Create admin user if it doesn't exist
    sudo useradd --create-home --shell /bin/bash admin
fi
echo "admin:admin" | sudo chpasswd

# Create the Q_USER as a regular user (if different from admin)
if [ "${Q_USER}" != "admin" ]; then
    echo "Creating user ${Q_USER}..."
    if ! id -u ${Q_USER} > /dev/null 2>&1; then
        sudo useradd --create-home --shell /bin/bash ${Q_USER}
    fi
    echo "${Q_USER}:${JUPYTER_PASSWORD}" | sudo chpasswd

    # Add Q_USER as admin too
    if ! sudo tljh-config add-item users.admin ${Q_USER}; then
        log_error "Failed to add ${Q_USER} to JupyterHub admins"
    fi
fi

# Install positron-server
echo "Installing positron-server..."
sudo mkdir -p /opt/positron-server
cd /opt/positron-server

# Get directory where this script is located (for positronDownload.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run download script
if [ -n "${POSITRON_TAG}" ]; then
    echo "Running download script with TAG=${POSITRON_TAG}, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=***..."
else
    echo "Running download script with latest Positron release, ARCH_SUFFIX=${ARCH_SUFFIX}, GITHUB_TOKEN=***..."
fi

if ! TAG=${POSITRON_TAG} ARCH_SUFFIX=${ARCH_SUFFIX} GITHUB_TOKEN=${GITHUB_TOKEN} "${SCRIPT_DIR}/positronDownload.sh"; then
    log_error "Failed to download/install Positron server"
fi

# Install jupyter-positron-server
echo "Installing jupyter-positron-server..."
JUPYTER_POSITRON_REPO="https://github.com/posit-dev/jupyter-positron-server"
JUPYTER_POSITRON_DIR="/opt/jupyter-positron-server"

# Clone or update jupyter-positron-server
if [ -d "${JUPYTER_POSITRON_DIR}" ]; then
    echo "Updating existing jupyter-positron-server..."
    cd "${JUPYTER_POSITRON_DIR}"
    if ! sudo git pull; then
        log_error "Failed to update jupyter-positron-server"
    fi
else
    echo "Cloning jupyter-positron-server..."
    if ! sudo git clone "${JUPYTER_POSITRON_REPO}" "${JUPYTER_POSITRON_DIR}"; then
        log_error "Failed to clone jupyter-positron-server"
    fi
    cd "${JUPYTER_POSITRON_DIR}"
fi

# Install jupyter-positron-server dependencies into TLJH's user environment
echo "Installing jupyter-positron-server dependencies into TLJH user environment..."
TLJH_USER_ENV="/opt/tljh/user"
if [ -d "${TLJH_USER_ENV}" ]; then
    # Install into TLJH's user environment (where user notebooks run)
    if ! sudo "${TLJH_USER_ENV}/bin/python3" -m pip install --upgrade pip; then
        log_error "Failed to upgrade pip in TLJH user environment"
    fi
    if ! sudo "${TLJH_USER_ENV}/bin/python3" -m pip install -e "${JUPYTER_POSITRON_DIR}"; then
        log_error "Failed to install jupyter-positron-server in TLJH user environment"
    fi

    # Also install some common packages users might need
    echo "Installing common Python packages..."
    sudo "${TLJH_USER_ENV}/bin/python3" -m pip install numpy pandas matplotlib scipy scikit-learn || true
else
    # Fallback: install system-wide with break-system-packages flag
    echo "⚠️  WARNING: TLJH user environment not found, installing system-wide..."
    if ! sudo python3 -m pip install --break-system-packages --upgrade pip; then
        log_error "Failed to upgrade pip"
    fi
    if ! sudo python3 -m pip install --break-system-packages -e "${JUPYTER_POSITRON_DIR}"; then
        log_error "Failed to install jupyter-positron-server"
    fi
fi

# Enable jupyter-positron-server extension in user environment
echo "Enabling jupyter-positron-server extension..."
sudo "${TLJH_USER_ENV}/bin/jupyter" server extension enable jupyter_positron_server

# Configure JupyterHub to use positron
echo "Configuring JupyterHub..."
sudo tee /opt/tljh/config/jupyterhub_config.d/positron.py >/dev/null <<'EOF'
# Positron configuration
import os

# Set environment variables for Positron
c.Spawner.environment = {
    'POSITRON_SERVER_PATH': '/opt/positron-server',
    'POSITRON_LICENSE_FILE': '/opt/positron-server/positron.lic',
}

# Don't set default_url - let users choose their interface
# c.Spawner.default_url = '/positron'
EOF

# Copy license file if it exists
if [ -f "${LICENSE_FILE}" ]; then
    echo "Copying license file..."
    sudo cp "${LICENSE_FILE}" /opt/positron-server/positron.lic
else
    echo "⚠️  WARNING: License file not found at ${LICENSE_FILE}"
    echo "   Positron will run in unlicensed mode with limitations."
fi

# Restart JupyterHub to apply changes
echo "Restarting JupyterHub..."
if ! sudo tljh-config reload; then
    log_error "Failed to restart JupyterHub"
fi

# Log completion and versions
echo ""
echo "Installation complete 🎉"
echo ""

# Extract Positron version and build number
POSITRON_VERSION=$(cd /opt/positron-server && grep '"positronVersion"' product.json 2>/dev/null | sed 's/.*"positronVersion": *"\([^"]*\)".*/\1/' || echo "Unknown")
POSITRON_BUILD=$(cd /opt/positron-server && grep '"positronBuildNumber"' product.json 2>/dev/null | sed 's/.*"positronBuildNumber": *"\([^"]*\)".*/\1/' || echo "")
POSITRON_FULL_VERSION="${POSITRON_VERSION}-${POSITRON_BUILD}"

echo "Positron version:    ${POSITRON_FULL_VERSION}"
echo "JupyterHub URL:      http://localhost:8888"
echo ""
echo "Default credentials:"
echo "  Username:          admin"
echo "  Password:          admin"
echo ""
echo "Additional user:"
echo "  Username:          ${Q_USER}"
echo "  Password:          [HIDDEN]"
echo ""

# Report any errors that occurred
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  WARNING: ${#ERRORS[@]} error(s) occurred during installation:"
    for error in "${ERRORS[@]}"; do
        echo "   • $error"
    done
    echo ""
    echo "Installation may not be fully functional. Check logs above for details."
    exit 1
fi

exit 0
