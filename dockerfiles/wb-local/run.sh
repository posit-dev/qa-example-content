#!/bin/sh

# Default to ubuntu24 if no OS argument is provided
OS_TYPE="ubuntu24"

# Check for OS type argument
if [ "$1" = "ubuntu24" ] || [ "$1" = "rocky8" ]; then
  OS_TYPE="$1"
fi

# Set docker-compose file based on OS type
COMPOSE_FILE="docker-compose.${OS_TYPE}.yml"

# Load other environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

docker compose -f ${COMPOSE_FILE} up

