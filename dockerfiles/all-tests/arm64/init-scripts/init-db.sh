#!/bin/bash
set -e

echo "Downloading periodic table SQL file..."
curl -o /tmp/periodic_table.sql https://raw.githubusercontent.com/neondatabase-labs/postgres-sample-dbs/main/periodic_table.sql

echo "Importing periodic table SQL file into database..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/periodic_table.sql

echo "Database initialization complete!"
