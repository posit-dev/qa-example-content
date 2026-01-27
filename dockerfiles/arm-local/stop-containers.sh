#!/bin/sh

# stop-containers.sh - Script to stop and remove Docker containers

# Default to ubuntu24 if no OS argument is provided
OS_TYPE="ubuntu24"

# Check for OS type argument
if [ "$1" = "ubuntu24" ] || [ "$1" = "rocky8" ] || [ "$1" = "opensuse156" ] || [ "$1" = "sles156" ]; then
  OS_TYPE="$1"
else
  echo "Usage: $0 [ubuntu24|rocky8|opensuse156|sles156]"
  echo "       Default is ubuntu24 if not specified"
  echo ""
fi

# Set docker-compose file based on OS type
COMPOSE_FILE="docker-compose.${OS_TYPE}.yml"

echo "Stopping and removing containers (${OS_TYPE})..."
docker compose -f ${COMPOSE_FILE} down
echo "Containers removed."

# Optional: If you want to also remove volumes (uncomment the line below)
# docker compose -f ${COMPOSE_FILE} down -v
