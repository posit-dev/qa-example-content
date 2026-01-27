#!/bin/sh

# This script helps you set up a multiline POSITRON_DEV_LICENSE environment variable
# and run docker-compose with Ubuntu 24, Rocky 8, or OpenSUSE 15.6 configuration

# Default to ubuntu24 if no OS argument is provided
OS_TYPE="ubuntu24"

# Check for OS type argument
if [ "$1" = "ubuntu24" ] || [ "$1" = "rocky8" ] || [ "$1" = "opensuse156" ] || [ "$1" = "sles156" ]; then
  OS_TYPE="$1"
fi

# Set docker-compose file based on OS type
COMPOSE_FILE="docker-compose.${OS_TYPE}.yml"

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

docker compose -f ${COMPOSE_FILE} up