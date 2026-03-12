#!/bin/sh

# This script connects to the running test container

# Parse command line arguments
CI_MODE=false
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
      echo "Usage: ./connect.sh [OPTIONS]"
      echo ""
      echo "Connects to the running test container with an interactive bash shell"
      echo ""
      echo "OPTIONS:"
      echo "  --ci        CI mode: skip all prompts and use defaults (requires GITHUB_TOKEN env var)"
      echo "  -h, --help  Show this help message"
      exit 0
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

# GITHUB_TOKEN is always required
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: set GITHUB_TOKEN before running: GITHUB_TOKEN=your_token ./connect.sh"
  exit 1
fi

# Check if the container is running
if ! docker ps | grep -q "test"; then
  echo "Error: test container is not running!"
  echo "Please start it first with: ./run.sh [ubuntu24|rocky8]"
  exit 1
fi

# Copy scripts to container (quietly)
for script in install-workbench.sh positronDownload.sh get-latest-wb-noble-url.sh; do
  if [ -f "./$script" ]; then
    docker cp "./$script" "test:/tmp/$script" >/dev/null 2>&1
    docker exec test chmod +x "/tmp/$script" 2>/dev/null
  fi
done

# Show current status
echo ""
echo "=== Status ==="
WB_VERSION=$(docker exec test bash -c 'rstudio-server version 2>/dev/null | head -1 | awk "{print \$1}"' 2>/dev/null)
if [ -n "$WB_VERSION" ] && [ "$WB_VERSION" != "" ]; then
    echo "Workbench: $WB_VERSION"
    POSITRON_VERSION=$(docker exec test bash -c '
        for dir in /usr/lib/rstudio-server/bin/positron-server/new /usr/lib/rstudio-server/bin/positron-server; do
            if [ -f "$dir/product.json" ]; then
                VER=$(grep "positronVersion" "$dir/product.json" 2>/dev/null | sed "s/.*\"positronVersion\": *\"\([^\"]*\)\".*/\1/")
                BUILD=$(grep "positronBuildNumber" "$dir/product.json" 2>/dev/null | sed "s/.*\"positronBuildNumber\": *\"\([^\"]*\)\".*/\1/")
                echo "${VER}-${BUILD}"
                exit 0
            fi
        done
    ' 2>/dev/null)
    if [ -n "$POSITRON_VERSION" ] && [ "$POSITRON_VERSION" != "-" ]; then
        echo "Positron:  $POSITRON_VERSION"
    fi
    ALREADY_INSTALLED=true
else
    echo "Workbench: Not installed"
    ALREADY_INSTALLED=false
fi
echo ""

# Connect to the container and run install script
if [ "$CI_MODE" = true ]; then
  echo "Running in CI mode - using latest versions without prompts..."
  docker exec -it -e GITHUB_TOKEN="$GITHUB_TOKEN" test /bin/bash -c "/tmp/install-workbench.sh --ci; exec /bin/bash"
else
  docker exec -it -e GITHUB_TOKEN="$GITHUB_TOKEN" -e ALREADY_INSTALLED="$ALREADY_INSTALLED" test /bin/bash -c '
    /tmp/install-workbench.sh

    # Show quick reference before dropping to shell
    echo ""
    echo "=== Quick Reference ==="
    if rstudio-server status >/dev/null 2>&1; then
        echo "Access Workbench: http://localhost:8787"
        echo "  Username: user1"
        echo "  Password: (your WB_PASSWORD from .env)"
        echo ""
        echo "Access Connect:   http://localhost:3939"
    else
        echo "To install, run:"
        echo "  /tmp/install-workbench.sh"
    fi
    echo ""
    exec /bin/bash
  '
fi
