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

# User configuration
# Note: TLJH prepends "jupyter-" to usernames, so "user" becomes "jupyter-user"
Q_USER=${Q_USER:-"user"}

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
if ! sudo apt-get install -y acl jq curl wget python3-pip python3-venv; then
    log_error "Failed to install required packages (acl, jq, curl, wget, python3-pip, python3-venv)"
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

# Create TLJH-prefixed users in advance so we can set ACLs
# TLJH prepends "jupyter-" to usernames, so we create these system users now
echo "Creating TLJH system users..."
if ! id -u jupyter-admin > /dev/null 2>&1; then
    sudo useradd --create-home --shell /bin/bash jupyter-admin
fi

# Create the Q_USER as a regular user (if different from admin)
if [ "${Q_USER}" != "admin" ]; then
    echo "Adding ${Q_USER} as JupyterHub admin..."
    if ! sudo tljh-config add-item users.admin ${Q_USER}; then
        log_error "Failed to add ${Q_USER} to JupyterHub admins"
    fi

    # Create the jupyter-prefixed system user
    if ! id -u jupyter-${Q_USER} > /dev/null 2>&1; then
        sudo useradd --create-home --shell /bin/bash jupyter-${Q_USER}
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

# Install jupyter-positron-server into TLJH's user environment
echo "Installing jupyter-positron-server into TLJH user environment..."
TLJH_USER_ENV="/opt/tljh/user"
if [ -d "${TLJH_USER_ENV}" ]; then
    # Install directly from git (no need to clone source)
    if ! sudo "${TLJH_USER_ENV}/bin/python3" -m pip install --upgrade pip; then
        log_error "Failed to upgrade pip in TLJH user environment"
    fi
    if ! sudo "${TLJH_USER_ENV}/bin/python3" -m pip install git+https://github.com/posit-dev/jupyter-positron-server.git; then
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
    if ! sudo python3 -m pip install --break-system-packages git+https://github.com/posit-dev/jupyter-positron-server.git; then
        log_error "Failed to install jupyter-positron-server"
    fi
fi

# No JupyterHub configuration needed - Positron uses default paths
# (/opt/positron-server with license at /opt/license.lic)

# Copy license file if it exists
if [ -f "${LICENSE_FILE}" ]; then
    echo "Copying license file..."
    sudo cp "${LICENSE_FILE}" /opt/license.lic
else
    echo "⚠️  WARNING: License file not found at ${LICENSE_FILE}"
    echo "   Positron will run in unlicensed mode with limitations."
fi

# Set access permissions for TLJH users
echo "Setting access permissions..."
# TLJH uses system users with "jupyter-" prefix - we created them above
# Admin user needs access to /root, pre-installed Python environments, and Positron
sudo setfacl -m u:jupyter-admin:x /root
if [ -d /root/.venv ]; then
    sudo setfacl -R -m u:jupyter-admin:rx /root/.venv
    sudo setfacl -R -m d:u:jupyter-admin:rx /root/.venv
fi
if [ -d /root/.pyenv ]; then
    sudo setfacl -R -m u:jupyter-admin:rx /root/.pyenv
    sudo setfacl -R -m d:u:jupyter-admin:rx /root/.pyenv
fi
sudo setfacl -R -m u:jupyter-admin:rx /opt/positron-server
sudo setfacl -R -m d:u:jupyter-admin:rx /opt/positron-server

# If Q_USER is different from admin, grant them access too
if [ "${Q_USER}" != "admin" ]; then
    sudo setfacl -m u:jupyter-${Q_USER}:x /root
    if [ -d /root/.venv ]; then
        sudo setfacl -R -m u:jupyter-${Q_USER}:rx /root/.venv
        sudo setfacl -R -m d:u:jupyter-${Q_USER}:rx /root/.venv
    fi
    if [ -d /root/.pyenv ]; then
        sudo setfacl -R -m u:jupyter-${Q_USER}:rx /root/.pyenv
        sudo setfacl -R -m d:u:jupyter-${Q_USER}:rx /root/.pyenv
    fi
    sudo setfacl -R -m u:jupyter-${Q_USER}:rx /opt/positron-server
    sudo setfacl -R -m d:u:jupyter-${Q_USER}:rx /opt/positron-server
fi

# Configure .Renviron for TLJH users
echo "Configuring .Renviron for R library paths..."
# Configure for jupyter-admin
sudo mkdir -p /home/jupyter-admin
sudo tee "/home/jupyter-admin/.Renviron" >/dev/null <<EOF
R_LIBS_SITE=/usr/local/lib/R/site-library
R_LIBS_USER=/usr/local/lib/R/site-library
EOF
sudo chown jupyter-admin:jupyter-admin "/home/jupyter-admin/.Renviron"

# Configure for jupyter-${Q_USER} if different from admin
if [ "${Q_USER}" != "admin" ]; then
    sudo mkdir -p /home/jupyter-${Q_USER}
    sudo tee "/home/jupyter-${Q_USER}/.Renviron" >/dev/null <<EOF
R_LIBS_SITE=/usr/local/lib/R/site-library
R_LIBS_USER=/usr/local/lib/R/site-library
EOF
    sudo chown jupyter-${Q_USER}:jupyter-${Q_USER} "/home/jupyter-${Q_USER}/.Renviron"
fi

# Setup environment modules to make R available in PATH
echo "Setting up environment modules..."
if ! sudo apt install -y environment-modules; then
    log_error "Failed to install environment-modules"
fi

# Create module files for R (pointing to /opt/R/current/bin if R is installed)
if [ -d /opt/R ]; then
    if ! sudo mkdir -p /opt/modules/modulefiles/R; then
        log_error "Failed to create /opt/modules/modulefiles/R directory"
    fi
    # Point to /opt/R/current if it exists, otherwise skip R module
    if [ -d /opt/R/current ]; then
        printf '#%%Module1.0\nset root /opt/R/current\nprepend-path PATH $root/bin\nprepend-path MANPATH $root/share/man\nsetenv R_HOME $root/lib/R\n' | sudo tee /opt/modules/modulefiles/R/current > /dev/null
    fi
fi

# Configure shell profiles for TLJH users
echo "Configuring shell profiles for environment modules..."
# For jupyter-admin
if [ -d /home/jupyter-admin ]; then
    echo 'source /etc/profile.d/modules.sh' >> /home/jupyter-admin/.profile
    echo 'module use /opt/modules/modulefiles' >> /home/jupyter-admin/.profile
    if [ -f /opt/modules/modulefiles/R/current ]; then
        echo 'module load R/current' >> /home/jupyter-admin/.profile
    fi
    sudo chown jupyter-admin:jupyter-admin /home/jupyter-admin/.profile

    # Also configure .bashrc for interactive shells
    echo 'source /etc/profile.d/modules.sh' >> /home/jupyter-admin/.bashrc
    echo 'module use /opt/modules/modulefiles' >> /home/jupyter-admin/.bashrc
    if [ -f /opt/modules/modulefiles/R/current ]; then
        echo 'module load R/current' >> /home/jupyter-admin/.bashrc
    fi
    sudo chown jupyter-admin:jupyter-admin /home/jupyter-admin/.bashrc
fi

# For jupyter-${Q_USER} if different from admin
if [ "${Q_USER}" != "admin" ] && [ -d /home/jupyter-${Q_USER} ]; then
    echo 'source /etc/profile.d/modules.sh' >> /home/jupyter-${Q_USER}/.profile
    echo 'module use /opt/modules/modulefiles' >> /home/jupyter-${Q_USER}/.profile
    if [ -f /opt/modules/modulefiles/R/current ]; then
        echo 'module load R/current' >> /home/jupyter-${Q_USER}/.profile
    fi
    sudo chown jupyter-${Q_USER}:jupyter-${Q_USER} /home/jupyter-${Q_USER}/.profile

    # Also configure .bashrc for interactive shells
    echo 'source /etc/profile.d/modules.sh' >> /home/jupyter-${Q_USER}/.bashrc
    echo 'module use /opt/modules/modulefiles' >> /home/jupyter-${Q_USER}/.bashrc
    if [ -f /opt/modules/modulefiles/R/current ]; then
        echo 'module load R/current' >> /home/jupyter-${Q_USER}/.bashrc
    fi
    sudo chown jupyter-${Q_USER}:jupyter-${Q_USER} /home/jupyter-${Q_USER}/.bashrc
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
echo "Login credentials:"
echo "  Username:          admin"
echo "  Password:          Set on first login"
echo ""
echo "Additional user:"
echo "  Username:          ${Q_USER}"
echo "  Password:          Set on first login"
echo ""
echo "Note: TLJH uses FirstUseAuthenticator - set your password on first login"
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
