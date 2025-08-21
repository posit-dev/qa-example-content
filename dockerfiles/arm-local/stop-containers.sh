#!/bin/sh

# stop-containers.sh - Script to stop and remove Docker containers

echo "Stopping and removing containers..."
docker-compose down
echo "Containers removed."

# Optional: If you want to also remove volumes (uncomment the line below)
# docker-compose down -v
