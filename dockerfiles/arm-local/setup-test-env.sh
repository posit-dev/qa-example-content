#!/bin/bash

# setup-test-env.sh - Script to set up testing environment in the container
# This script gets copied into the container and can be run to set up the test environment

# Display usage instructions if no branch is provided
if [ "$1" = "" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 <branch_name>"
    echo ""
    echo "Sets up a Positron testing environment by cloning the repository"
    echo "and configuring it for test execution."
    echo ""
    echo "Parameters:"
    echo "  <branch_name>    The branch to checkout (required)"
    echo ""
    echo "Example:"
    echo "  $0 main"
    exit 1
fi

BRANCH="$1"
WORK_DIR="/__w/positron"
REPO_DIR="$WORK_DIR/positron"

echo "===== Setting up Positron Test Environment ====="
echo "Branch: $BRANCH"
echo ""

# Create work directory
echo "Creating work directory..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Clone repository
echo "Cloning Positron repository..."
git clone https://github.com/posit-dev/positron.git
cd "$REPO_DIR" || { echo "Failed to enter repository directory"; exit 1; }

# Checkout specified branch
echo "Checking out branch: $BRANCH"
git checkout "$BRANCH"

# Install dependencies
echo "Installing dependencies..."
npm ci --fetch-timeout 120000

echo "Installing E2E test dependencies..."
cd "$REPO_DIR" && npm --prefix test/e2e ci

# Compile and setup electron
echo "Compiling and setting up Electron..."
cd "$REPO_DIR" && npm exec -- npm-run-all --max_old_space_size=4095 -lp compile "electron arm64"
cd "$REPO_DIR" && npm exec -- playwright install

# Set correct permissions for chrome-sandbox
echo "Setting up chrome-sandbox permissions..."
cd "$REPO_DIR"
ELECTRON_ROOT=.build/electron
sudo chown root $ELECTRON_ROOT/chrome-sandbox
sudo chmod 4755 $ELECTRON_ROOT/chrome-sandbox
stat $ELECTRON_ROOT/chrome-sandbox

# Pre-launch setup
echo "Running prelaunch..."
cd "$REPO_DIR" && npm run prelaunch

echo "Running gulp node..."
cd "$REPO_DIR" && npm run gulp node

# Set up display server
echo "Setting up display server..."
/usr/bin/Xvfb :10 -ac -screen 0 2560x1440x24 > /tmp/Xvfb.out 2>&1 &

export DISPLAY=:10
for i in {1..10}; do
    if xdpyinfo > /dev/null 2>&1; then
    echo "Xvfb is ready"
    break
    fi
    echo "Waiting for Xvfb to start..."
    sleep 1
done

# Move license files
echo "Setting up license..."
if [ -d "/positron-license" ]; then
    mv /positron-license "$WORK_DIR"
    
    # Set up license key from environment variable if provided
    if [ -n "$POSITRON_DEV_LICENSE" ]; then
        echo "Setting up license key from environment variable..."
        printf "%s" "$POSITRON_DEV_LICENSE" > "$WORK_DIR/positron-license/pdol/target/debug/pdol_rsa"
    else
        echo "Warning: POSITRON_DEV_LICENSE environment variable not set."
        echo "License key will not be automatically configured."
    fi
else
    echo "Warning: /positron-license directory not found."
    echo "License files were not moved."
fi

# Set environment variables
echo "Setting environment variables..."
export POSITRON_PY_VER_SEL="3.10.12"
export POSITRON_R_VER_SEL="4.4.0"
export POSITRON_PY_ALT_VER_SEL="3.13.0"
export POSITRON_R_ALT_VER_SEL="4.4.2"
export POSITRON_HIDDEN_PY="3.12.10 (Conda)"
export POSITRON_HIDDEN_R="4.4.1"
export PWTEST_BLOB_DO_NOT_REMOVE="1"

# Add these variables to .bashrc so they persist in new shells
cat <<EOF >> ~/.bashrc
# Positron test environment variables
export DISPLAY=:10
export POSITRON_PY_VER_SEL="3.10.12"
export POSITRON_R_VER_SEL="4.4.0"
export POSITRON_PY_ALT_VER_SEL="3.13.0"
export POSITRON_R_ALT_VER_SEL="4.4.2"
export POSITRON_HIDDEN_PY="3.12.10 (Conda)"
export POSITRON_HIDDEN_R="4.4.1"
export PWTEST_BLOB_DO_NOT_REMOVE="1"

# Automatically cd to positron directory on login
cd $REPO_DIR
EOF

# Add a helper script to run tests
cat > /usr/local/bin/run-tests <<EOF
#!/bin/bash
cd $REPO_DIR && npx playwright test "\$@"
EOF
chmod +x /usr/local/bin/run-tests

echo ""
echo "===== Test Environment Setup Complete ====="
echo ""
echo "Environment is ready for running tests."
echo "Current directory: $REPO_DIR"
echo ""
echo "You can run tests with:"
echo "  npx playwright test [test-options]"
echo "  or simply: run-tests [test-options]"
echo ""
echo "To view the UI, connect to VNC at localhost:5900"

# Make sure we end up in the repo directory
cd "$REPO_DIR"
