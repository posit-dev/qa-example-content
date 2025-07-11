#!/bin/bash
set -e

# Create directory for SQL files
mkdir -p /docker-entrypoint-initdb.d

# Download the periodic table SQL file
curl -o /docker-entrypoint-initdb.d/periodic_table.sql https://raw.githubusercontent.com/neondatabase-labs/postgres-sample-dbs/main/periodic_table.sql

# Make sure the script is executable
chmod 755 /docker-entrypoint-initdb.d/periodic_table.sql

echo "Downloaded periodic_table.sql to /docker-entrypoint-initdb.d/"
