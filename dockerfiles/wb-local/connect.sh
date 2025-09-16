#!/bin/sh

# This script connects to the running test container

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: ./connect.sh"
  echo ""
  echo "Connects to the running test container with an interactive bash shell"
  exit 0
fi

# No command line arguments needed now

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
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

# Connect to the container
docker exec -it test /bin/bash
