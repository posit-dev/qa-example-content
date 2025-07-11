#!/bin/bash
# Script to reset and restart the Docker Compose environment

echo "Stopping containers and removing volumes..."
docker-compose down -v

echo "Removing any existing images for a clean start..."
docker image rm positron-critical-arm:latest 2>/dev/null || true

echo "Starting containers in detached mode..."
docker-compose up -d

echo "Waiting for database initialization (10 seconds)..."
sleep 10

echo "Checking database logs..."
docker-compose logs db | grep -i "periodic_table\|error\|fail"

echo "Verifying database connection and tables..."
docker exec -it db bash -c "PGPASSWORD=testpassword psql -U testuser -d testdb -c '\dt' -c 'SELECT COUNT(*) FROM elements;'"

echo "Environment reset complete. You can now run:"
echo "docker-compose logs -f test    # To monitor the test container"
echo "docker-compose exec test bash  # To access the test container shell"
