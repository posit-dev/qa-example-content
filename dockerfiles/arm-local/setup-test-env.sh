#!/bin/bash

# setup-test-env.sh - Script to set up testing environment in the container
# This script gets copied into the container and can be run to set up the test environment

# Initialize error tracking
ERRORS=()

# Function to log errors
log_error() {
    ERRORS+=("$1")
    echo "ERROR: $1"
}

# Function to check if branch exists (local or remote)
branch_exists() {
    local branch="$1"
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || \
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null
}

# Function to prompt for valid branch
prompt_for_branch() {
    local branch="$1"
    while true; do
        if branch_exists "$branch"; then
            echo "$branch"
            return 0
        fi
        echo ""
        echo "Branch '$branch' not found."
        echo "Available branches (showing first 20):"
        git branch -r | head -20 | sed 's/origin\//  /'
        echo ""
        read -p "Enter a valid branch name (or 'q' to quit): " branch
        if [ "$branch" = "q" ] || [ "$branch" = "quit" ]; then
            echo "Aborting setup."
            exit 1
        fi
    done
}

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

# Clone or update repository
if [ -d "$REPO_DIR/.git" ]; then
    echo "Repository already exists. Updating..."
    cd "$REPO_DIR" || { log_error "Failed to enter repository directory"; exit 1; }

    # Fetch all branches
    echo "Fetching latest changes..."
    if ! git fetch --all; then
        log_error "Failed to fetch from remote"
    fi

    # Validate and checkout branch
    BRANCH=$(prompt_for_branch "$BRANCH") || exit 1
    echo "Checking out branch: $BRANCH"
    if ! git checkout "$BRANCH"; then
        log_error "Failed to checkout branch: $BRANCH"
    fi

    # Pull latest changes
    echo "Pulling latest changes..."
    if ! git pull; then
        log_error "Failed to pull latest changes"
    fi
else
    echo "Cloning Positron repository..."
    if ! git clone https://github.com/posit-dev/positron.git; then
        log_error "Failed to clone Positron repository"
        exit 1
    fi
    cd "$REPO_DIR" || { log_error "Failed to enter repository directory"; exit 1; }

    # Fetch to ensure we have all remote branch info
    git fetch --all

    # Validate and checkout branch
    BRANCH=$(prompt_for_branch "$BRANCH") || exit 1
    echo "Checking out branch: $BRANCH"
    if ! git checkout "$BRANCH"; then
        log_error "Failed to checkout branch: $BRANCH"
    fi
fi

# Install dependencies
echo "Installing dependencies..."
if ! npm ci --fetch-timeout 120000; then
    log_error "Failed to install npm dependencies"
fi

echo "Installing E2E test dependencies..."
if ! (cd "$REPO_DIR" && npm --prefix test/e2e ci); then
    log_error "Failed to install E2E test dependencies"
fi

# Compile and setup electron
echo "Compiling and setting up Electron..."
if ! (cd "$REPO_DIR" && npm exec -- npm-run-all --max_old_space_size=4095 -lp compile "electron arm64"); then
    log_error "Failed to compile Positron"
fi
if ! (cd "$REPO_DIR" && npm exec -- playwright install); then
    log_error "Failed to install Playwright"
fi

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
export POSITRON_R_VER_SEL="4.5.2"
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
export POSITRON_R_VER_SEL="4.5.2"
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

# Report any errors that occurred
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: ${#ERRORS[@]} error(s) occurred during setup:"
    for error in "${ERRORS[@]}"; do
        echo "   - $error"
    done
    echo ""
    echo "Setup may not be fully functional. Check logs above for details."
fi

echo ""
echo "Ready to run tests. Example commands:"
echo "  npx playwright test --project e2e-electron --workers 2 --grep @:connections"
echo "  npx playwright test --project e2e-browser --workers 2 --grep @:data-explorer"
echo ""
echo "Other useful commands:"
echo "  /tmp/start-vnc.sh                        - Start VNC server (connect to localhost:5900)"
echo "  npx playwright show-report --host 0.0.0.0 - View test report (localhost:9323)"
echo ""
echo "NOTE: If you open a new terminal/shell, run: source ~/.bashrc"
echo ""