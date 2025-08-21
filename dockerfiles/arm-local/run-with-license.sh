#!/bin/sh

# This script helps you set up a multiline POSITRON_DEV_LICENSE environment variable

# Check if license.txt exists
if [ ! -f license.txt ]; then
  echo "Error: license.txt not found!"
  echo "Please create a license.txt file with your POSITRON_DEV_LICENSE content"
  exit 1
fi

# Export the license as an environment variable, preserving newlines
export POSITRON_DEV_LICENSE=$(cat license.txt)

# Load other environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

# Check for command line arguments
if [ "$1" = "-d" ] || [ "$1" = "--detach" ]; then
  # Run docker-compose detached
  echo "Starting docker-compose with license loaded in detached mode..."
  docker-compose up -d
  
  # Copy scripts to container
  if [ -f "./setup-test-env.sh" ]; then
    echo "Copying test environment setup script to container..."
    docker cp ./setup-test-env.sh test:/tmp/setup-test-env.sh
    docker exec test chmod +x /tmp/setup-test-env.sh
  fi
  
  echo ""
  echo "Containers started in background."
  echo "To connect to the test container shell, run:"
  echo "./connect.sh"
  echo ""
  echo "To set up the test environment, connect to the container and run:"
  echo "/tmp/setup-test-env.sh <branch_name>"
  echo "After running the setup script, be sure to source your shell configuration:"
  echo "source ~/.bashrc"
  echo ""
  echo "To view logs, run:"
  echo "docker-compose logs -f"
  echo ""
  echo "To stop and remove containers, run:"
  echo "./stop-container.sh"
else
  # Run docker-compose with the exported variables
  echo "Starting docker-compose with license loaded..."
  echo "Press Ctrl+C to stop the containers"
  echo "The 'test' container will keep running in the background"
  echo "To connect to it after stopping this view, run: ./connect.sh"
  echo ""
  docker-compose up
  COMPOSE_STATUS=$?
  
  # If docker-compose finished without error, copy scripts to container
  if [ $COMPOSE_STATUS -eq 0 ] && docker ps | grep -q "test"; then
    if [ -f "./setup-test-env.sh" ]; then
      echo "Copying test environment setup script to container..."
      docker cp ./setup-test-env.sh test:/tmp/setup-test-env.sh
      docker exec test chmod +x /tmp/setup-test-env.sh
    fi
    
    echo "To set up the test environment, connect to the container and run:"
    echo "/tmp/setup-test-env.sh <branch_name>"
    echo "After running the setup script, be sure to source your shell configuration:"
    echo "source ~/.bashrc"
    echo ""
    echo "To stop and remove containers, run:"
    echo "./stop-container.sh"
  fi
fi
