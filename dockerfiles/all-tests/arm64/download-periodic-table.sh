#!/bin/bash
set -e

# Create directory for the downloaded file
mkdir -p ~/Downloads

# Download the periodic table SQL file
echo "Downloading periodic_table.sql to ~/Downloads..."
curl -o ~/Downloads/periodic_table.sql https://raw.githubusercontent.com/neondatabase-labs/postgres-sample-dbs/main/periodic_table.sql

echo "Download complete!"
echo "You can now import it manually with:"
echo "psql -h localhost -U testuser -d testdb -f ~/Downloads/periodic_table.sql"
echo "When prompted, enter password: testpassword"
