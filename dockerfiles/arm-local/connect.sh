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
  echo "Please start it first with: ./run-with-license.sh"
  exit 1
fi

# Copy setup script to container

if [ -f "./setup-test-env.sh" ]; then
  echo "Copying test environment setup script to container..."
  docker cp ./setup-test-env.sh test:/tmp/setup-test-env.sh
  docker exec test chmod +x /tmp/setup-test-env.sh
fi

# Display helpful message
echo "Connecting to test container..."
echo "/tmp/setup-test-env.sh <branch_name>    - Set up Positron test environment"
echo ""

# Connect to the container
docker exec -it test /bin/bash
