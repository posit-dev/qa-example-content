#!/bin/bash
set -e

# Set PostgreSQL environment variables if they're not already set
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_DB=${POSTGRES_DB:-periodic_table}

echo "Database initialization script started..."
echo "Using database: $POSTGRES_DB"

# Note: The SQL files in this directory will be automatically executed by 
# the PostgreSQL entrypoint script in alphabetical order
echo "The PostgreSQL entrypoint will execute the SQL files in this directory."
