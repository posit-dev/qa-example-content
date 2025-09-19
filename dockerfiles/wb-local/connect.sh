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

# Copy setup script to container

if [ -f "./install-workbench.sh" ]; then
  echo "Copying workbench setup script to container..."
  docker cp ./install-workbench.sh test:/tmp/install-workbench.sh
  docker exec test chmod +x /tmp/install-workbench.sh
fi

if [ -f "./positronDownload.sh" ]; then
  echo "Copying download script to container..."
  docker cp ./positronDownload.sh test:/tmp/positronDownload.sh
  docker exec test chmod +x /tmp/positronDownload.sh
fi

# Connect to the container and auto-run the install script
if [ "$CI_MODE" = true ]; then
  echo "Running in CI mode - using latest versions without prompts..."
  docker exec -it -e GITHUB_TOKEN="$GITHUB_TOKEN" test /bin/bash -c "/tmp/install-workbench.sh --ci; exec /bin/bash"
else
  docker exec -it -e GITHUB_TOKEN="$GITHUB_TOKEN" test /bin/bash -c "/tmp/install-workbench.sh; exec /bin/bash"
fi
