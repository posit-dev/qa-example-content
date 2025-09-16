#!/bin/sh

# Default to ubuntu24 if no OS argument is provided
OS_TYPE="ubuntu24"

# Check for OS type argument
if [ "$1" = "ubuntu24" ] || [ "$1" = "rocky8" ]; then
  OS_TYPE="$1"
  shift # Remove the OS argument from parameters
elif [ "$1" != "-d" ] && [ "$1" != "--detach" ]; then
  echo "Usage: $0 [ubuntu24|rocky8] [-d|--detach]"
  echo "       Default is ubuntu24 if not specified"
  echo ""
fi

# Set docker-compose file based on OS type
COMPOSE_FILE="docker-compose.${OS_TYPE}.yml"

# Load other environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

docker compose -f ${COMPOSE_FILE} up
COMPOSE_STATUS=$?

# If docker compose finished without error, copy scripts to container
if [ $COMPOSE_STATUS -eq 0 ] && docker ps | grep -q "test"; then
  if [ -f "./install-workbench.sh" ]; then
      docker cp ./install-workbench.sh test:/tmp/install-workbench.sh
      docker exec test chmod +x /tmp/install-workbench.sh
  fi

  if [ -f "./positronDownload.sh" ]; then
      docker cp ./positronDownload.sh test:/tmp/positronDownload.sh
      docker exec test chmod +x /tmp/positronDownload.sh
  fi
fi

